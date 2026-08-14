import 'package:flutter_test/flutter_test.dart';
import 'package:udhar_khata/models/models.dart';
import 'package:udhar_khata/services/firestore_service.dart';
import 'package:udhar_khata/services/udhar_repository.dart';

class MockFirestoreService implements FirestoreService {
  final List<Customer> _mockCustomers = [];
  final List<GoodItem> _mockGoods = [];
  final List<PaymentRecord> _mockPayments = [];

  MockFirestoreService({
    List<Customer>? initialCustomers,
    List<GoodItem>? initialGoods,
    List<PaymentRecord>? initialPayments,
  }) {
    if (initialCustomers != null) _mockCustomers.addAll(initialCustomers);
    if (initialGoods != null) _mockGoods.addAll(initialGoods);
    if (initialPayments != null) _mockPayments.addAll(initialPayments);
  }

  @override
  Future<List<Customer>> fetchCustomers({String? userId}) async {
    if (userId != null && userId.isNotEmpty) {
      return List.unmodifiable(_mockCustomers.where((c) => c.addedByUserId == userId || c.addedByUserId.isEmpty));
    }
    return List.unmodifiable(_mockCustomers);
  }

  @override
  Future<List<GoodItem>> fetchGoods({String? userId}) async => List.unmodifiable(_mockGoods);

  @override
  Future<List<PaymentRecord>> fetchPayments({String? userId}) async => List.unmodifiable(_mockPayments);

  @override
  Stream<List<Customer>> streamCustomers({String? userId}) {
    if (userId != null && userId.isNotEmpty) {
      return Stream.value(_mockCustomers.where((c) => c.addedByUserId == userId || c.addedByUserId.isEmpty).toList());
    }
    return Stream.value(_mockCustomers);
  }

  @override
  Stream<List<GoodItem>> streamGoods({String? userId}) => Stream.value(_mockGoods);

  @override
  Stream<List<PaymentRecord>> streamPayments({String? userId}) => Stream.value(_mockPayments);

  @override
  Future<void> saveCustomer(Customer customer, {String? userId}) async {
    _mockCustomers.removeWhere((c) => c.id == customer.id);
    _mockCustomers.insert(0, customer);
  }

  @override
  Future<void> deleteCustomer(String customerId, {String? userId}) async {
    _mockCustomers.removeWhere((c) => c.id == customerId);
  }

  @override
  Future<void> saveGoodItem(GoodItem item, {String? userId}) async {
    _mockGoods.removeWhere((g) => g.id == item.id);
    _mockGoods.insert(0, item);
  }

  @override
  Future<void> saveGoodItemsBatch(List<GoodItem> items, {String? userId}) async {
    for (final item in items) {
      await saveGoodItem(item, userId: userId);
    }
  }

  @override
  Future<void> deleteGoodItem(String goodId, {String? userId}) async {
    _mockGoods.removeWhere((g) => g.id == goodId);
  }

  @override
  Future<void> savePaymentRecord(PaymentRecord record, {String? userId}) async {
    _mockPayments.removeWhere((p) => p.id == record.id);
    _mockPayments.insert(0, record);
  }

  @override
  Future<void> deletePaymentRecord(String paymentId, {String? userId}) async {
    _mockPayments.removeWhere((p) => p.id == paymentId);
  }

  @override
  Future<AppUser?> getUserProfile(String uid) async => null;

  @override
  Future<AppUser?> getUserByEmail(String email) async => null;

  @override
  Future<void> syncUserProfile(AppUser user) async {}
}

void main() {
  group('UdharRepository syncFromFirestore Tests', () {
    test('syncFromFirestore populates customers, goods, and payments from Firestore', () async {
      final now = DateTime.now();
      final mockCustomer = Customer(
        id: 'c_remote_100',
        name: 'Remote Customer',
        phoneNumber: '9998887770',
        createdAt: now,
      );
      final mockGood = GoodItem(
        id: 'g_remote_100',
        customerId: 'c_remote_100',
        name: 'Sugar 5kg',
        category: 'Groceries',
        quantity: 1,
        unitPrice: 200,
        date: now,
      );
      final mockPayment = PaymentRecord(
        id: 'p_remote_100',
        customerId: 'c_remote_100',
        amountPaid: 100,
        date: now,
        settlements: [],
      );

      final mockService = MockFirestoreService(
        initialCustomers: [mockCustomer],
        initialGoods: [mockGood],
        initialPayments: [mockPayment],
      );

      final repository = UdharRepository(null, mockService);
      await repository.syncFromFirestore();

      expect(repository.customers.length, 1);
      expect(repository.customers.first.name, 'Remote Customer');
      expect(repository.goods.length, 1);
      expect(repository.goods.first.name, 'Sugar 5kg');
      expect(repository.payments.length, 1);
      expect(repository.payments.first.amountPaid, 100.0);
    });
  });
}
