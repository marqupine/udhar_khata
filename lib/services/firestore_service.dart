import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance {
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

  CollectionReference<Map<String, dynamic>> _userCustomersCol(String userId) =>
      _usersCol.doc(userId).collection('customers');

  CollectionReference<Map<String, dynamic>> _userGoodsCol(String userId) =>
      _usersCol.doc(userId).collection('goods');

  CollectionReference<Map<String, dynamic>> _userPaymentsCol(String userId) =>
      _usersCol.doc(userId).collection('payments');

  String _getEffectiveUserId(String? userId) {
    if (userId != null && userId.trim().isNotEmpty) return userId.trim();
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }

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
      return AppUser.fromMap(doc.data()!, docId: doc.id);
    }
    return null;
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final query = await _usersCol.where('email', isEqualTo: email.trim()).limit(1).get();
    if (query.docs.isNotEmpty) {
      return AppUser.fromMap(query.docs.first.data(), docId: query.docs.first.id);
    }
    return null;
  }

  // --- CUSTOMERS ---
  Stream<List<Customer>> streamCustomers({String? userId}) {
    final uid = _getEffectiveUserId(userId);
    return _userCustomersCol(uid).snapshots().map((snapshot) {
      final customers = snapshot.docs
          .map((doc) => Customer.fromMap(doc.data(), docId: doc.id))
          .toList();
      customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return customers;
    });
  }

  Future<List<Customer>> fetchCustomers({String? userId}) async {
    final uid = _getEffectiveUserId(userId);
    final snapshot = await _userCustomersCol(uid).get();
    final customers = snapshot.docs
        .map((doc) => Customer.fromMap(doc.data(), docId: doc.id))
        .toList();
    customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return customers;
  }

  Future<void> saveCustomer(Customer customer, {String? userId}) async {
    try {
      final uid = _getEffectiveUserId(userId);
      await _userCustomersCol(uid).doc(customer.id).set(customer.toMap(), SetOptions(merge: true));
      debugPrint('Firestore: Saved customer ${customer.name} (${customer.id}) for user $uid');
    } catch (e) {
      debugPrint('Firestore Error saving customer ${customer.id}: $e');
    }
  }

  Future<void> deleteCustomer(String customerId, {String? userId}) async {
    try {
      final uid = _getEffectiveUserId(userId);
      await _userCustomersCol(uid).doc(customerId).delete();
      debugPrint('Firestore: Deleted customer $customerId for user $uid');
    } catch (e) {
      debugPrint('Firestore Error deleting customer $customerId: $e');
    }
  }

  // --- GOODS ---
  Stream<List<GoodItem>> streamGoods({String? userId}) {
    final uid = _getEffectiveUserId(userId);
    return _userGoodsCol(uid).snapshots().map((snapshot) {
      final goods = snapshot.docs
          .map((doc) => GoodItem.fromMap(doc.data(), docId: doc.id))
          .toList();
      goods.sort((a, b) => b.date.compareTo(a.date));
      return goods;
    });
  }

  Future<List<GoodItem>> fetchGoods({String? userId}) async {
    final uid = _getEffectiveUserId(userId);
    final snapshot = await _userGoodsCol(uid).get();
    final goods = snapshot.docs
        .map((doc) => GoodItem.fromMap(doc.data(), docId: doc.id))
        .toList();
    goods.sort((a, b) => b.date.compareTo(a.date));
    return goods;
  }

  Future<void> saveGoodItem(GoodItem item, {String? userId}) async {
    try {
      final uid = _getEffectiveUserId(userId);
      await _userGoodsCol(uid).doc(item.id).set(item.toMap(), SetOptions(merge: true));
      debugPrint('Firestore: Saved good item ${item.name} (${item.id}) for user $uid');
    } catch (e) {
      debugPrint('Firestore Error saving good item ${item.id}: $e');
    }
  }

  Future<void> saveGoodItemsBatch(List<GoodItem> items, {String? userId}) async {
    try {
      final uid = _getEffectiveUserId(userId);
      final batch = _db.batch();
      for (final item in items) {
        final docRef = _userGoodsCol(uid).doc(item.id);
        batch.set(docRef, item.toMap(), SetOptions(merge: true));
      }
      await batch.commit();
      debugPrint('Firestore: Saved batch of ${items.length} goods for user $uid');
    } catch (e) {
      debugPrint('Firestore Error saving goods batch: $e');
    }
  }

  Future<void> deleteGoodItem(String goodId, {String? userId}) async {
    try {
      final uid = _getEffectiveUserId(userId);
      await _userGoodsCol(uid).doc(goodId).delete();
      debugPrint('Firestore: Deleted good item $goodId for user $uid');
    } catch (e) {
      debugPrint('Firestore Error deleting good item $goodId: $e');
    }
  }

  // --- PAYMENTS ---
  Stream<List<PaymentRecord>> streamPayments({String? userId}) {
    final uid = _getEffectiveUserId(userId);
    return _userPaymentsCol(uid).snapshots().map((snapshot) {
      final payments = snapshot.docs
          .map((doc) => PaymentRecord.fromMap(doc.data(), docId: doc.id))
          .toList();
      payments.sort((a, b) => b.date.compareTo(a.date));
      return payments;
    });
  }

  Future<List<PaymentRecord>> fetchPayments({String? userId}) async {
    final uid = _getEffectiveUserId(userId);
    final snapshot = await _userPaymentsCol(uid).get();
    final payments = snapshot.docs
        .map((doc) => PaymentRecord.fromMap(doc.data(), docId: doc.id))
        .toList();
    payments.sort((a, b) => b.date.compareTo(a.date));
    return payments;
  }

  Future<void> savePaymentRecord(PaymentRecord record, {String? userId}) async {
    try {
      final uid = _getEffectiveUserId(userId);
      await _userPaymentsCol(uid).doc(record.id).set(record.toMap(), SetOptions(merge: true));
      debugPrint('Firestore: Saved payment record (${record.id}) for user $uid');
    } catch (e) {
      debugPrint('Firestore Error saving payment record ${record.id}: $e');
    }
  }

  Future<void> deletePaymentRecord(String paymentId, {String? userId}) async {
    try {
      final uid = _getEffectiveUserId(userId);
      await _userPaymentsCol(uid).doc(paymentId).delete();
      debugPrint('Firestore: Deleted payment record $paymentId for user $uid');
    } catch (e) {
      debugPrint('Firestore Error deleting payment record $paymentId: $e');
    }
  }
}
