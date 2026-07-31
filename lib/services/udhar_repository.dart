import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'storage_service.dart';

class UdharRepository extends ChangeNotifier {
  final StorageService? _storageService;

  final List<Customer> _customers = [];
  final List<GoodItem> _goods = [];
  final List<PaymentRecord> _payments = [];

  UdharRepository([this._storageService]) {
    _loadFromStorage();
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

  Future<void> _persistAll() async {
    if (_storageService != null) {
      await _storageService.saveCustomers(_customers);
      await _storageService.saveGoods(_goods);
      await _storageService.savePayments(_payments);
    }
  }

  // --- Customer Operations ---

  Future<Customer> addCustomer({
    required String name,
    required String phoneNumber,
  }) async {
    final customer = Customer(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}_${_customers.length}',
      name: name.trim(),
      phoneNumber: phoneNumber.trim(),
      createdAt: DateTime.now(),
    );
    _customers.insert(0, customer);
    await _persistAll();
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
    notifyListeners();
    return good;
  }

  List<GoodItem> getGoodsForCustomer(String customerId) {
    final list = _goods.where((g) => g.customerId == customerId).toList();
    list.sort((a, b) => b.date.compareTo(a.date)); // newest first for display
    return list;
  }

  double getCustomerTotalBorrowed(String customerId) {
    return _goods
        .where((g) => g.customerId == customerId)
        .fold(0.0, (sum, g) => sum + g.totalPrice);
  }

  double getCustomerTotalPaid(String customerId) {
    return _goods
        .where((g) => g.customerId == customerId)
        .fold(0.0, (sum, g) => sum + g.amountPaid);
  }

  double getCustomerPendingBalance(String customerId) {
    return _goods
        .where((g) => g.customerId == customerId)
        .fold(0.0, (sum, g) => sum + g.remainingAmount);
  }

  // Global Financial Metrics
  double get grandTotalPending {
    return _goods.fold(0.0, (sum, g) => sum + g.remainingAmount);
  }

  double get grandTotalSettled {
    return _goods.fold(0.0, (sum, g) => sum + g.amountPaid);
  }

  int get activeBorrowersCount {
    final customerIdsWithBalance = _goods
        .where((g) => g.remainingAmount > 0.001)
        .map((g) => g.customerId)
        .toSet();
    return customerIdsWithBalance.length;
  }

  // --- FIFO Settlement Engine ---

  /// Calculates a preview of FIFO settlement without mutating state.
  List<ItemSettlementBreakdown> previewFifoSettlement(String customerId, double paymentAmount) {
    if (paymentAmount <= 0) return [];

    // Get all pending/partially paid goods for customer, sorted oldest first (FIFO)
    final pendingGoods = _goods
        .where((g) => g.customerId == customerId && g.remainingAmount > 0.001)
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

  /// Processes payment using FIFO algorithm and updates item balances & records receipt.
  Future<PaymentRecord?> recordPayment({
    required String customerId,
    required double paymentAmount,
    String note = '',
  }) async {
    if (paymentAmount <= 0) return null;

    final breakdown = previewFifoSettlement(customerId, paymentAmount);
    if (breakdown.isEmpty) return null;

    // Apply settlements to actual goods
    for (final itemBreakdown in breakdown) {
      final index = _goods.indexWhere((g) => g.id == itemBreakdown.itemId);
      if (index != -1) {
        _goods[index] = _goods[index].copyWith(
          amountPaid: itemBreakdown.newAmountPaid,
        );
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
    notifyListeners();
    return paymentRecord;
  }

  /// Direct manual payment for a single item (e.g. shopkeeper marks an individual good paid directly)
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
        notifyListeners();
      }
    }
  }

  List<PaymentRecord> getPaymentsForCustomer(String customerId) {
    return _payments.where((p) => p.customerId == customerId).toList();
  }
}
