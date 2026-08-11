import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class UdharRepository extends ChangeNotifier {
  final StorageService? _storageService;
  final FirestoreService? _firestoreService;

  final List<Customer> _customers = [];
  final List<GoodItem> _goods = [];
  final List<PaymentRecord> _payments = [];

  UdharRepository([this._storageService, this._firestoreService]) {
    _loadFromStorage();
    _initFirestoreSync();
    autoPurgePaidRecordsOlderThan(daysThreshold: 7);
    autoPurgeRecycleBin(hoursThreshold: 72);
  }

  List<Customer> get customers => List.unmodifiable(_customers);
  List<GoodItem> get goods => List.unmodifiable(_goods);
  List<PaymentRecord> get payments => List.unmodifiable(_payments);

  void _loadFromStorage() {
    if (_storageService != null) {
      _customers.clear();
      _customers.addAll(_storageService.loadCustomers());

      _goods.clear();
      _goods.addAll(_storageService.loadGoods());

      _payments.clear();
      _payments.addAll(_storageService.loadPayments());
    }
  }

  void _initFirestoreSync() {
    if (_firestoreService == null) return;

    _firestoreService.streamCustomers().listen((remoteCustomers) {
      if (remoteCustomers.isNotEmpty) {
        _customers.clear();
        _customers.addAll(remoteCustomers);
        _persistAll();
        notifyListeners();
      }
    }, onError: (e) => debugPrint('Customer stream error: $e'));

    _firestoreService.streamGoods().listen((remoteGoods) {
      if (remoteGoods.isNotEmpty) {
        _goods.clear();
        _goods.addAll(remoteGoods);
        _persistAll();
        notifyListeners();
      }
    }, onError: (e) => debugPrint('Goods stream error: $e'));

    _firestoreService.streamPayments().listen((remotePayments) {
      if (remotePayments.isNotEmpty) {
        _payments.clear();
        _payments.addAll(remotePayments);
        _persistAll();
        notifyListeners();
      }
    }, onError: (e) => debugPrint('Payments stream error: $e'));
  }

  Future<void> _persistAll() async {
    if (_storageService != null) {
      await _storageService.saveCustomers(_customers);
      await _storageService.saveGoods(_goods);
      await _storageService.savePayments(_payments);
    }
  }

  // --- Customer Operations ---

  /// Checks whether customer name is unique (case-insensitive)
  bool isCustomerNameUnique(String name) {
    final cleanName = name.trim().toLowerCase();
    if (cleanName.isEmpty) return false;
    return !_customers.any((c) => c.name.trim().toLowerCase() == cleanName);
  }

  Future<Customer> addCustomer({
    required String name,
    String phoneNumber = '',
    String address = '',
    String addedByUserId = '',
    String addedByUserName = '',
  }) async {
    final trimmedName = name.trim();
    if (!isCustomerNameUnique(trimmedName)) {
      throw ArgumentError('A customer with the name "$trimmedName" already exists. Customer names must be unique.');
    }

    final customer = Customer(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}_${_customers.length}',
      name: trimmedName,
      phoneNumber: phoneNumber.trim(),
      address: address.trim(),
      addedByUserId: addedByUserId,
      addedByUserName: addedByUserName,
      createdAt: DateTime.now(),
    );
    _customers.insert(0, customer);
    await _persistAll();

    if (_firestoreService != null) {
      await _firestoreService.saveCustomer(customer);
    }

    notifyListeners();
    return customer;
  }

  Customer? getCustomerById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    _customers.removeWhere((c) => c.id == customerId);
    _goods.removeWhere((g) => g.customerId == customerId);
    _payments.removeWhere((p) => p.customerId == customerId);
    await _persistAll();

    if (_firestoreService != null) {
      await _firestoreService.deleteCustomer(customerId);
    }

    notifyListeners();
  }

  /// Clears all borrowed goods and payment receipts for a customer without deleting the customer
  Future<void> clearCustomerRecords(String customerId) async {
    final goodsToDelete = _goods.where((g) => g.customerId == customerId).toList();
    final paymentsToDelete = _payments.where((p) => p.customerId == customerId).toList();

    _goods.removeWhere((g) => g.customerId == customerId);
    _payments.removeWhere((p) => p.customerId == customerId);
    await _persistAll();

    if (_firestoreService != null) {
      for (final g in goodsToDelete) {
        await _firestoreService.deleteGoodItem(g.id);
      }
      for (final p in paymentsToDelete) {
        await _firestoreService.deletePaymentRecord(p.id);
      }
    }

    notifyListeners();
  }

  // --- Goods Operations ---

  Future<GoodItem> addGoodItem({
    required String customerId,
    required String name,
    required String category,
    required double quantity,
    required double unitPrice,
    DateTime? date,
  }) async {
    final good = GoodItem(
      id: 'g_${DateTime.now().microsecondsSinceEpoch}_${_goods.length}',
      customerId: customerId,
      name: name.trim(),
      category: category.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      date: date ?? DateTime.now(),
    );
    _goods.add(good);
    await _persistAll();

    if (_firestoreService != null) {
      await _firestoreService.saveGoodItem(good);
    }

    notifyListeners();
    return good;
  }

  Future<GoodItem> updateGoodItem({
    required String id,
    required String name,
    required String category,
    required double quantity,
    required double unitPrice,
    DateTime? date,
  }) async {
    final index = _goods.indexWhere((g) => g.id == id);
    if (index == -1) {
      throw ArgumentError('GoodItem with id "$id" not found.');
    }

    final existing = _goods[index];
    if (!existing.canBeEdited) {
      throw StateError('This item cannot be edited because it is older than 1 hour or has payments applied.');
    }

    final updated = existing.copyWith(
      name: name.trim(),
      category: category.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: quantity * unitPrice,
      date: date ?? existing.date,
    );

    _goods[index] = updated;
    await _persistAll();

    if (_firestoreService != null) {
      await _firestoreService.saveGoodItem(updated);
    }

    notifyListeners();
    return updated;
  }

  List<GoodItem> getGoodsForCustomer(String customerId) {
    final list = _goods.where((g) => g.customerId == customerId && g.isDeleted != true).toList();
    list.sort((a, b) => b.date.compareTo(a.date)); // newest first for display
    return list;
  }

  double getCustomerTotalBorrowed(String customerId) {
    return _goods
        .where((g) => g.customerId == customerId && g.isDeleted != true)
        .fold(0.0, (sum, g) => sum + g.totalPrice);
  }

  double getCustomerTotalPaid(String customerId) {
    return _goods
        .where((g) => g.customerId == customerId && g.isDeleted != true)
        .fold(0.0, (sum, g) => sum + g.amountPaid);
  }

  double getCustomerPendingBalance(String customerId) {
    return _goods
        .where((g) => g.customerId == customerId && g.isDeleted != true)
        .fold(0.0, (sum, g) => sum + g.remainingAmount);
  }

  // Global Financial Metrics
  double get grandTotalPending {
    return _goods.where((g) => g.isDeleted != true).fold(0.0, (sum, g) => sum + g.remainingAmount);
  }

  double get grandTotalSettled {
    return _goods.where((g) => g.isDeleted != true).fold(0.0, (sum, g) => sum + g.amountPaid);
  }

  int get activeBorrowersCount {
    final customerIdsWithBalance = _goods
        .where((g) => g.isDeleted != true && g.remainingAmount > 0.001)
        .map((g) => g.customerId)
        .toSet();
    return customerIdsWithBalance.length;
  }

  // --- Recycle Bin Operations ---

  /// Moves a GoodItem to the Recycle Bin (soft delete).
  Future<GoodItem?> moveToBin(String goodId) async {
    final index = _goods.indexWhere((g) => g.id == goodId);
    if (index == -1) return null;

    final updated = _goods[index].copyWith(
      isDeleted: true,
      deletedAt: DateTime.now(),
    );
    _goods[index] = updated;
    await _persistAll();

    if (_firestoreService != null) {
      await _firestoreService.saveGoodItem(updated);
    }

    notifyListeners();
    return updated;
  }

  /// Restores a GoodItem from the Recycle Bin.
  Future<GoodItem?> restoreFromBin(String goodId) async {
    final index = _goods.indexWhere((g) => g.id == goodId);
    if (index == -1) return null;

    final updated = GoodItem(
      id: _goods[index].id,
      customerId: _goods[index].customerId,
      name: _goods[index].name,
      category: _goods[index].category,
      quantity: _goods[index].quantity,
      unitPrice: _goods[index].unitPrice,
      totalPrice: _goods[index].totalPrice,
      amountPaid: _goods[index].amountPaid,
      date: _goods[index].date,
      isDeleted: false,
      deletedAt: null,
    );
    _goods[index] = updated;
    await _persistAll();

    if (_firestoreService != null) {
      await _firestoreService.saveGoodItem(updated);
    }

    notifyListeners();
    return updated;
  }

  /// Permanently deletes a GoodItem.
  Future<void> permanentlyDeleteGood(String goodId) async {
    _goods.removeWhere((g) => g.id == goodId);
    await _persistAll();

    if (_firestoreService != null) {
      await _firestoreService.deleteGoodItem(goodId);
    }

    notifyListeners();
  }

  /// Returns deleted goods in the Recycle Bin for a customer.
  List<GoodItem> getRecycleBinGoods(String customerId) {
    final list = _goods.where((g) => g.customerId == customerId && g.isDeleted == true).toList();
    list.sort((a, b) => (b.deletedAt ?? b.date).compareTo(a.deletedAt ?? a.date));
    return list;
  }

  /// Automatically purges items from Recycle Bin older than [hoursThreshold] (default: 72 hours).
  Future<int> autoPurgeRecycleBin({int hoursThreshold = 72}) async {
    final now = DateTime.now();
    final expired = _goods.where((g) {
      if (g.isDeleted != true || g.deletedAt == null) return false;
      return now.difference(g.deletedAt!).inHours >= hoursThreshold;
    }).toList();

    if (expired.isEmpty) return 0;

    _goods.removeWhere((g) => expired.contains(g));
    await _persistAll();

    if (_firestoreService != null) {
      for (final g in expired) {
        await _firestoreService.deleteGoodItem(g.id);
      }
    }

    notifyListeners();
    return expired.length;
  }

  // --- FIFO Settlement Engine ---

  List<ItemSettlementBreakdown> previewFifoSettlement(String customerId, double paymentAmount) {
    if (paymentAmount <= 0) return [];

    final pendingGoods = _goods
        .where((g) => g.customerId == customerId && g.isDeleted != true && g.remainingAmount > 0.001)
        .toList();
    pendingGoods.sort((a, b) => a.date.compareTo(b.date));

    double remainingPayment = paymentAmount;
    final List<ItemSettlementBreakdown> breakdown = [];

    for (final item in pendingGoods) {
      if (remainingPayment <= 0.001) break;

      final itemNeeded = item.remainingAmount;
      final applyAmount = remainingPayment >= itemNeeded ? itemNeeded : remainingPayment;

      final newPaid = item.amountPaid + applyAmount;
      final fullyPaid = (item.totalPrice - newPaid) <= 0.001;

      breakdown.add(
        ItemSettlementBreakdown(
          itemId: item.id,
          itemName: item.name,
          amountApplied: applyAmount,
          previousAmountPaid: item.amountPaid,
          newAmountPaid: newPaid,
          totalPrice: item.totalPrice,
          isFullyPaidNow: fullyPaid,
        ),
      );

      remainingPayment -= applyAmount;
    }

    return breakdown;
  }

  Future<PaymentRecord?> recordPayment({
    required String customerId,
    required double paymentAmount,
    String note = '',
  }) async {
    if (paymentAmount <= 0) return null;

    final breakdown = previewFifoSettlement(customerId, paymentAmount);
    if (breakdown.isEmpty) return null;

    final List<GoodItem> updatedGoods = [];
    for (final itemBreakdown in breakdown) {
      final index = _goods.indexWhere((g) => g.id == itemBreakdown.itemId);
      if (index != -1) {
        _goods[index] = _goods[index].copyWith(
          amountPaid: itemBreakdown.newAmountPaid,
        );
        updatedGoods.add(_goods[index]);
      }
    }

    final paymentRecord = PaymentRecord(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      customerId: customerId,
      amountPaid: paymentAmount,
      date: DateTime.now(),
      note: note.trim(),
      settlements: breakdown,
    );

    _payments.insert(0, paymentRecord);
    await _persistAll();

    if (_firestoreService != null) {
      await _firestoreService.savePaymentRecord(paymentRecord);
      await _firestoreService.saveGoodItemsBatch(updatedGoods);
    }

    notifyListeners();
    return paymentRecord;
  }

  Future<void> markGoodAsPaid(String goodId) async {
    final index = _goods.indexWhere((g) => g.id == goodId);
    if (index != -1) {
      final good = _goods[index];
      final unpaidAmount = good.remainingAmount;
      if (unpaidAmount > 0.001) {
        _goods[index] = good.copyWith(amountPaid: good.totalPrice);
        final breakdown = [
          ItemSettlementBreakdown(
            itemId: good.id,
            itemName: good.name,
            amountApplied: unpaidAmount,
            previousAmountPaid: good.amountPaid,
            newAmountPaid: good.totalPrice,
            totalPrice: good.totalPrice,
            isFullyPaidNow: true,
          )
        ];

        final paymentRecord = PaymentRecord(
          id: 'p_${DateTime.now().millisecondsSinceEpoch}',
          customerId: good.customerId,
          amountPaid: unpaidAmount,
          date: DateTime.now(),
          note: 'Direct item mark as paid: ${good.name}',
          settlements: breakdown,
        );

        _payments.insert(0, paymentRecord);
        await _persistAll();

        if (_firestoreService != null) {
          await _firestoreService.saveGoodItem(_goods[index]);
          await _firestoreService.savePaymentRecord(paymentRecord);
        }

        notifyListeners();
      }
    }
  }

  List<PaymentRecord> getPaymentsForCustomer(String customerId) {
    return _payments.where((p) => p.customerId == customerId).toList();
  }

  /// Automatically purges paid goods and payment records older than [daysThreshold] (default: 7 days)
  Future<int> autoPurgePaidRecordsOlderThan({int daysThreshold = 7}) async {
    final now = DateTime.now();

    final expiredGoods = _goods.where((g) {
      if (!g.isPaid) return false;
      return now.difference(g.date).inDays >= daysThreshold;
    }).toList();

    final expiredPayments = _payments.where((p) {
      return now.difference(p.date).inDays >= daysThreshold;
    }).toList();

    if (expiredGoods.isEmpty && expiredPayments.isEmpty) return 0;

    _goods.removeWhere((g) => expiredGoods.contains(g));
    _payments.removeWhere((p) => expiredPayments.contains(p));

    await _persistAll();

    if (_firestoreService != null) {
      for (final g in expiredGoods) {
        await _firestoreService.deleteGoodItem(g.id);
      }
      for (final p in expiredPayments) {
        await _firestoreService.deletePaymentRecord(p.id);
      }
    }

    notifyListeners();
    return expiredGoods.length + expiredPayments.length;
  }
}
