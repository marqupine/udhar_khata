import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const String _keyCustomers = 'udhar_customers_v1';
  static const String _keyGoods = 'udhar_goods_v1';
  static const String _keyPayments = 'udhar_payments_v1';

  final SharedPreferences prefs;

  StorageService(this.prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Customers
  List<Customer> loadCustomers() {
    final rawJson = prefs.getString(_keyCustomers);
    if (rawJson == null || rawJson.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(rawJson);
      return list.map((item) => Customer.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveCustomers(List<Customer> customers) async {
    final listMap = customers.map((c) => c.toMap()).toList();
    return prefs.setString(_keyCustomers, json.encode(listMap));
  }

  // Goods
  List<GoodItem> loadGoods() {
    final rawJson = prefs.getString(_keyGoods);
    if (rawJson == null || rawJson.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(rawJson);
      return list.map((item) => GoodItem.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveGoods(List<GoodItem> goods) async {
    final listMap = goods.map((g) => g.toMap()).toList();
    return prefs.setString(_keyGoods, json.encode(listMap));
  }

  // Payment Records
  List<PaymentRecord> loadPayments() {
    final rawJson = prefs.getString(_keyPayments);
    if (rawJson == null || rawJson.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(rawJson);
      return list.map((item) => PaymentRecord.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> savePayments(List<PaymentRecord> payments) async {
    final listMap = payments.map((p) => p.toMap()).toList();
    return prefs.setString(_keyPayments, json.encode(listMap));
  }
}
