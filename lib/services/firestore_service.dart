import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance {
    // Enable offline persistence for web / mobile
    try {
      _db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings warning: ${e.toString()}');
    }
  }

  // Collections
  CollectionReference<Map<String, dynamic>> get _usersCol => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _customersCol => _db.collection('customers');
  CollectionReference<Map<String, dynamic>> get _goodsCol => _db.collection('goods');
  CollectionReference<Map<String, dynamic>> get _paymentsCol => _db.collection('payments');

  // --- USER PROFILES ---
  Future<void> syncUserProfile(AppUser user) async {
    try {
      final docRef = _usersCol.doc(user.uid);
      await docRef.set(user.toMap(), SetOptions(merge: true));
      debugPrint('Successfully synced user profile to Firestore: ${user.email} (${user.uid})');
    } catch (e) {
      debugPrint('Error syncing user profile to Firestore: $e');
    }
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _usersCol.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AppUser.fromMap(doc.data()!);
    }
    return null;
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final query = await _usersCol.where('email', isEqualTo: email.trim()).limit(1).get();
    if (query.docs.isNotEmpty) {
      return AppUser.fromMap(query.docs.first.data());
    }
    return null;
  }

  // --- CUSTOMERS ---
  Stream<List<Customer>> streamCustomers() {
    return _customersCol.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
    });
  }

  Future<List<Customer>> fetchCustomers() async {
    final snapshot = await _customersCol.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
  }

  Future<void> saveCustomer(Customer customer) async {
    await _customersCol.doc(customer.id).set(customer.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteCustomer(String customerId) async {
    await _customersCol.doc(customerId).delete();
  }

  // --- GOODS ---
  Stream<List<GoodItem>> streamGoods() {
    return _goodsCol.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => GoodItem.fromMap(doc.data())).toList();
    });
  }

  Future<List<GoodItem>> fetchGoods() async {
    final snapshot = await _goodsCol.orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => GoodItem.fromMap(doc.data())).toList();
  }

  Future<void> saveGoodItem(GoodItem item) async {
    await _goodsCol.doc(item.id).set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> saveGoodItemsBatch(List<GoodItem> items) async {
    final batch = _db.batch();
    for (final item in items) {
      final docRef = _goodsCol.doc(item.id);
      batch.set(docRef, item.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  // --- PAYMENTS ---
  Stream<List<PaymentRecord>> streamPayments() {
    return _paymentsCol.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PaymentRecord.fromMap(doc.data())).toList();
    });
  }

  Future<List<PaymentRecord>> fetchPayments() async {
    final snapshot = await _paymentsCol.orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => PaymentRecord.fromMap(doc.data())).toList();
  }

  Future<void> savePaymentRecord(PaymentRecord record) async {
    await _paymentsCol.doc(record.id).set(record.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteGoodItem(String goodId) async {
    await _goodsCol.doc(goodId).delete();
  }

  Future<void> deletePaymentRecord(String paymentId) async {
    await _paymentsCol.doc(paymentId).delete();
  }
}
