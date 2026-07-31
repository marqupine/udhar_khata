import 'package:flutter_test/flutter_test.dart';
import 'package:udhar_khata/services/udhar_repository.dart';

void main() {
  group('FIFO Auto-Settlement Engine Tests', () {
    late UdharRepository repo;

    setUp(() {
      repo = UdharRepository(null); // In-memory without SharedPreferences
    });

    test('Scenario: 100 rupees payment for 150 total debt across 3 items', () async {
      final customer = await repo.addCustomer(name: 'Rahul Kumar', phoneNumber: '9876543210');

      // Add 3 items on different dates
      final now = DateTime.now();
      await repo.addGoodItem(
        customerId: customer.id,
        name: 'Rice 1kg',
        category: 'Grocery',
        quantity: 1,
        unitPrice: 40.0,
        date: now.subtract(const Duration(days: 3)), // Oldest
      );

      await repo.addGoodItem(
        customerId: customer.id,
        name: 'Cooking Oil 1L',
        category: 'Grocery',
        quantity: 1,
        unitPrice: 60.0,
        date: now.subtract(const Duration(days: 2)), // 2nd oldest
      );

      await repo.addGoodItem(
        customerId: customer.id,
        name: 'Milk 1L',
        category: 'Dairy',
        quantity: 1,
        unitPrice: 50.0,
        date: now.subtract(const Duration(days: 1)), // Newest
      );

      expect(repo.getCustomerTotalBorrowed(customer.id), equals(150.0));
      expect(repo.getCustomerPendingBalance(customer.id), equals(150.0));

      // Preview payment of ₹100
      final preview = repo.previewFifoSettlement(customer.id, 100.0);
      expect(preview.length, equals(2));
      expect(preview[0].itemName, equals('Rice 1kg'));
      expect(preview[0].amountApplied, equals(40.0));
      expect(preview[0].isFullyPaidNow, isTrue);

      expect(preview[1].itemName, equals('Cooking Oil 1L'));
      expect(preview[1].amountApplied, equals(60.0));
      expect(preview[1].isFullyPaidNow, isTrue);

      // Perform payment of ₹100
      final payment = await repo.recordPayment(customerId: customer.id, paymentAmount: 100.0);
      expect(payment, isNotNull);
      expect(payment!.amountPaid, equals(100.0));

      expect(repo.getCustomerTotalPaid(customer.id), equals(100.0));
      expect(repo.getCustomerPendingBalance(customer.id), equals(50.0));

      final items = repo.getGoodsForCustomer(customer.id);
      final rice = items.firstWhere((i) => i.name == 'Rice 1kg');
      final oil = items.firstWhere((i) => i.name == 'Cooking Oil 1L');
      final milk = items.firstWhere((i) => i.name == 'Milk 1L');

      expect(rice.isPaid, isTrue);
      expect(oil.isPaid, isTrue);
      expect(milk.isPaid, isFalse);
      expect(milk.remainingAmount, equals(50.0));
    });

    test('Scenario: Partial Settlement of an individual item', () async {
      final customer = await repo.addCustomer(name: 'Anita Verma', phoneNumber: '9123456789');
      final now = DateTime.now();

      await repo.addGoodItem(
        customerId: customer.id,
        name: 'Atta 5kg',
        category: 'Grocery',
        quantity: 1,
        unitPrice: 200.0,
        date: now.subtract(const Duration(days: 2)),
      );

      await repo.addGoodItem(
        customerId: customer.id,
        name: 'Sugar 1kg',
        category: 'Grocery',
        quantity: 1,
        unitPrice: 50.0,
        date: now.subtract(const Duration(days: 1)),
      );

      // Customer owes 250 total. Customer pays 120.
      final payment = await repo.recordPayment(customerId: customer.id, paymentAmount: 120.0);
      expect(payment, isNotNull);
      expect(payment!.settlements.length, equals(1));
      expect(payment.settlements[0].itemName, equals('Atta 5kg'));
      expect(payment.settlements[0].amountApplied, equals(120.0));
      expect(payment.settlements[0].isFullyPaidNow, isFalse);

      final items = repo.getGoodsForCustomer(customer.id);
      final atta = items.firstWhere((i) => i.name == 'Atta 5kg');

      expect(atta.isPartiallyPaid, isTrue);
      expect(atta.amountPaid, equals(120.0));
      expect(atta.remainingAmount, equals(80.0));
      expect(atta.statusLabel, equals('PARTIAL'));
    });
  });
}
