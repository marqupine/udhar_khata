import 'package:flutter_test/flutter_test.dart';
import 'package:udhar_khata/models/models.dart';

class MockFirestoreTimestamp {
  final DateTime _dateTime;
  MockFirestoreTimestamp(this._dateTime);

  DateTime toDate() => _dateTime;
}

void main() {
  group('Firestore Model Deserialization Tests', () {
    test('Customer.fromMap handles String, int, MockTimestamp, and missing id', () {
      final now = DateTime.now();

      // 1. ISO String
      final c1 = Customer.fromMap({
        'id': 'c1',
        'name': 'Ramesh Kumar',
        'createdAt': now.toIso8601String(),
      });
      expect(c1.id, 'c1');
      expect(c1.name, 'Ramesh Kumar');

      // 2. Mock Firestore Timestamp
      final c2 = Customer.fromMap({
        'name': 'Suresh Sharma',
        'createdAt': MockFirestoreTimestamp(now),
      }, docId: 'doc_c2');
      expect(c2.id, 'doc_c2');
      expect(c2.name, 'Suresh Sharma');

      // 3. Milliseconds since epoch integer
      final c3 = Customer.fromMap({
        'id': 'c3',
        'name': 'Anita Roy',
        'createdAt': now.millisecondsSinceEpoch,
      });
      expect(c3.id, 'c3');
      expect(c3.createdAt.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });

    test('GoodItem.fromMap handles Timestamp, String, int, and docId fallback', () {
      final now = DateTime.now();

      final g1 = GoodItem.fromMap({
        'customerId': 'c1',
        'name': 'Rice 10kg',
        'category': 'Groceries',
        'quantity': 2.0,
        'unitPrice': 500.0,
        'date': MockFirestoreTimestamp(now),
        'deletedAt': MockFirestoreTimestamp(now),
      }, docId: 'g_doc_1');

      expect(g1.id, 'g_doc_1');
      expect(g1.name, 'Rice 10kg');
      expect(g1.totalPrice, 1000.0);
      expect(g1.date.year, now.year);
    });

    test('PaymentRecord.fromMap handles Timestamp and docId fallback', () {
      final now = DateTime.now();

      final p1 = PaymentRecord.fromMap({
        'customerId': 'c1',
        'amountPaid': 250.0,
        'date': MockFirestoreTimestamp(now),
        'note': 'Partial cash payment',
      }, docId: 'p_doc_1');

      expect(p1.id, 'p_doc_1');
      expect(p1.amountPaid, 250.0);
      expect(p1.note, 'Partial cash payment');
    });

    test('AppUser.fromMap handles Timestamp and fallback uid', () {
      final now = DateTime.now();

      final u1 = AppUser.fromMap({
        'name': 'Shop Owner',
        'email': 'owner@shop.com',
        'createdAt': MockFirestoreTimestamp(now),
      }, docId: 'user_uid_123');

      expect(u1.uid, 'user_uid_123');
      expect(u1.name, 'Shop Owner');
      expect(u1.email, 'owner@shop.com');
    });
  });
}
