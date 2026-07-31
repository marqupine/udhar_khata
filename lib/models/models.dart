import 'dart:convert';

class Customer {
  final String id;
  final String name;
  final String phoneNumber;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  String toJson() => json.encode(toMap());
  factory Customer.fromJson(String source) => Customer.fromMap(json.decode(source));
}

class GoodItem {
  final String id;
  final String customerId;
  final String name;
  final String category;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  double amountPaid;
  final DateTime date;

  GoodItem({
    required this.id,
    required this.customerId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    double? totalPrice,
    this.amountPaid = 0.0,
    required this.date,
  }) : totalPrice = totalPrice ?? (quantity * unitPrice);

  double get remainingAmount => (totalPrice - amountPaid).clamp(0.0, totalPrice);

  bool get isPaid => remainingAmount <= 0.001;

  bool get isPartiallyPaid => amountPaid > 0.001 && !isPaid;

  String get statusLabel {
    if (isPaid) return 'PAID';
    if (isPartiallyPaid) return 'PARTIAL';
    return 'PENDING';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'amountPaid': amountPaid,
      'date': date.toIso8601String(),
    };
  }

  factory GoodItem.fromMap(Map<String, dynamic> map) {
    return GoodItem(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble(),
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
    );
  }

  String toJson() => json.encode(toMap());
  factory GoodItem.fromJson(String source) => GoodItem.fromMap(json.decode(source));

  GoodItem copyWith({
    String? id,
    String? customerId,
    String? name,
    String? category,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    double? amountPaid,
    DateTime? date,
  }) {
    return GoodItem(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      amountPaid: amountPaid ?? this.amountPaid,
      date: date ?? this.date,
    );
  }
}

class ItemSettlementBreakdown {
  final String itemId;
  final String itemName;
  final double amountApplied;
  final double previousAmountPaid;
  final double newAmountPaid;
  final double totalPrice;
  final bool isFullyPaidNow;

  ItemSettlementBreakdown({
    required this.itemId,
    required this.itemName,
    required this.amountApplied,
    required this.previousAmountPaid,
    required this.newAmountPaid,
    required this.totalPrice,
    required this.isFullyPaidNow,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'amountApplied': amountApplied,
      'previousAmountPaid': previousAmountPaid,
      'newAmountPaid': newAmountPaid,
      'totalPrice': totalPrice,
      'isFullyPaidNow': isFullyPaidNow,
    };
  }

  factory ItemSettlementBreakdown.fromMap(Map<String, dynamic> map) {
    return ItemSettlementBreakdown(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      amountApplied: (map['amountApplied'] as num?)?.toDouble() ?? 0.0,
      previousAmountPaid: (map['previousAmountPaid'] as num?)?.toDouble() ?? 0.0,
      newAmountPaid: (map['newAmountPaid'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      isFullyPaidNow: map['isFullyPaidNow'] ?? false,
    );
  }
}

class PaymentRecord {
  final String id;
  final String customerId;
  final double amountPaid;
  final DateTime date;
  final String note;
  final List<ItemSettlementBreakdown> settlements;

  PaymentRecord({
    required this.id,
    required this.customerId,
    required this.amountPaid,
    required this.date,
    this.note = '',
    required this.settlements,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'amountPaid': amountPaid,
      'date': date.toIso8601String(),
      'note': note,
      'settlements': settlements.map((s) => s.toMap()).toList(),
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      note: map['note'] ?? '',
      settlements: (map['settlements'] as List<dynamic>?)
              ?.map((s) => ItemSettlementBreakdown.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String toJson() => json.encode(toMap());
  factory PaymentRecord.fromJson(String source) => PaymentRecord.fromMap(json.decode(source));
}
