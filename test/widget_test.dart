import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udhar_khata/constants/app_constants.dart';
import 'package:udhar_khata/main.dart';
import 'package:udhar_khata/services/auth_service.dart';
import 'package:udhar_khata/services/security_service.dart';
import 'package:udhar_khata/services/udhar_repository.dart';

class MockAuthService implements AuthService {
  final _controller = StreamController<User?>.broadcast();

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  void emitUser(User? user) {
    _controller.add(user);
  }

  @override
  User? get currentUser => null;

  @override
  String get currentUserId => 'mock_user_id';

  @override
  String get currentUserName => 'Test User';

  @override
  String get currentUserEmail => 'test@example.com';

  @override
  Future<void> ensureUserSynced() async {}

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

void main() {
  testWidgets('UdharKhataApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = UdharRepository(null);
    final authService = MockAuthService();
    final securityService = SecurityService(prefs);

    await tester.pumpWidget(
      UdharKhataApp(
        repository: repository,
        authService: authService,
        securityService: securityService,
      ),
    );

    authService.emitUser(null);
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsWidgets);
  });

  test(
    'UdharRepository enforces unique customer names (case-insensitive)',
    () async {
      final repository = UdharRepository(null);

      await repository.addCustomer(
        name: 'Rahul Sharma',
        phoneNumber: '9876543210',
        address: 'Sector 15, Noida',
        addedByUserId: 'u1',
        addedByUserName: 'Sagar',
      );

      expect(repository.isCustomerNameUnique('Rahul Sharma'), false);
      expect(repository.isCustomerNameUnique('rahul sharma'), false);
      expect(repository.isCustomerNameUnique('RAHUL SHARMA'), false);
      expect(repository.isCustomerNameUnique('Amit Kumar'), true);

      expect(
        () => repository.addCustomer(name: 'rahul sharma', phoneNumber: ''),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'UdharRepository auto-purges paid goods and payment records older than 7 days',
    () async {
      final repository = UdharRepository(null);

      final customer = await repository.addCustomer(
        name: 'Test Cust',
        phoneNumber: '',
      );

      // Add an old paid good (8 days ago)
      final oldGood = await repository.addGoodItem(
        customerId: customer.id,
        name: 'Old Paid Item',
        category: 'Grocery',
        quantity: 1,
        unitPrice: 100,
        date: DateTime.now().subtract(const Duration(days: 8)),
      );
      await repository.markGoodAsPaid(oldGood.id);

      // Add a recent paid good (2 days ago)
      final recentGood = await repository.addGoodItem(
        customerId: customer.id,
        name: 'Recent Paid Item',
        category: 'Grocery',
        quantity: 1,
        unitPrice: 50,
        date: DateTime.now().subtract(const Duration(days: 2)),
      );
      await repository.markGoodAsPaid(recentGood.id);

      // Add an old unpaid good (8 days ago) -> should NOT be purged because it's unpaid
      await repository.addGoodItem(
        customerId: customer.id,
        name: 'Old Unpaid Item',
        category: 'Grocery',
        quantity: 1,
        unitPrice: 200,
        date: DateTime.now().subtract(const Duration(days: 8)),
      );

      expect(repository.goods.length, 3);

      // Trigger auto-purge for records older than 7 days
      final purgedCount = await repository.autoPurgePaidRecordsOlderThan(
        daysThreshold: 7,
      );

      expect(purgedCount, greaterThanOrEqualTo(1));
      expect(repository.goods.any((g) => g.name == 'Old Paid Item'), false);
      expect(repository.goods.any((g) => g.name == 'Recent Paid Item'), true);
      expect(repository.goods.any((g) => g.name == 'Old Unpaid Item'), true);
    },
  );

  test('GoodItem edit window rule (< 1 hour) and updateGoodItem', () async {
    final repository = UdharRepository(null);
    final customer = await repository.addCustomer(name: 'Edit Test Customer');

    // Recent item (created 10 minutes ago)
    final recentItem = await repository.addGoodItem(
      customerId: customer.id,
      name: 'Recent Chips',
      category: 'Snacks',
      quantity: 2,
      unitPrice: 20,
      date: DateTime.now().subtract(const Duration(minutes: 10)),
    );

    // Old item (created 90 minutes ago)
    final oldItem = await repository.addGoodItem(
      customerId: customer.id,
      name: 'Old Oil',
      category: 'Grocery',
      quantity: 1,
      unitPrice: 150,
      date: DateTime.now().subtract(const Duration(minutes: 90)),
    );

    expect(recentItem.canBeEdited, true);
    expect(oldItem.canBeEdited, false);

    // Update recent item
    final updatedItem = await repository.updateGoodItem(
      id: recentItem.id,
      name: 'Recent Chips Large',
      category: 'Snacks',
      quantity: 3,
      unitPrice: 25,
    );

    expect(updatedItem.name, 'Recent Chips Large');
    expect(updatedItem.totalPrice, 75.0);

    // Attempting to update old item should throw StateError
    expect(
      () => repository.updateGoodItem(
        id: oldItem.id,
        name: 'Old Oil Mod',
        category: 'Grocery',
        quantity: 2,
        unitPrice: 150,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('Recycle Bin soft-delete, restore, and 72-hour auto-purge', () async {
    final repository = UdharRepository();
    final customer = await repository.addCustomer(name: 'Recycle Test User');

    final item1 = await repository.addGoodItem(
      customerId: customer.id,
      name: 'Item 1',
      category: 'General',
      quantity: 1,
      unitPrice: 100,
    );

    expect(repository.getGoodsForCustomer(customer.id).length, 1);
    expect(repository.getCustomerPendingBalance(customer.id), 100.0);

    // 1. Move to Bin (soft delete)
    final moved = await repository.moveToBin(item1.id);
    expect(moved?.isDeleted, true);
    expect(repository.getGoodsForCustomer(customer.id).length, 0);
    expect(repository.getCustomerPendingBalance(customer.id), 0.0);
    expect(repository.getRecycleBinGoods(customer.id).length, 1);

    // 2. Restore from Bin
    await repository.restoreFromBin(item1.id);
    expect(repository.getGoodsForCustomer(customer.id).length, 1);
    expect(repository.getCustomerPendingBalance(customer.id), 100.0);
    expect(repository.getRecycleBinGoods(customer.id).length, 0);

    // 3. Move to Bin and test auto-purge threshold
    await repository.moveToBin(item1.id);
    final purgedCount = await repository.autoPurgeRecycleBin(hoursThreshold: 0);
    expect(purgedCount, 1);
    expect(repository.getRecycleBinGoods(customer.id).length, 0);
  });
}
