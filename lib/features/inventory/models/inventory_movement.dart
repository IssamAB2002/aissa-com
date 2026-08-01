import 'package:cloud_firestore/cloud_firestore.dart';

enum MovementType { stockIn, stockOut, adjustment }

extension MovementTypeX on MovementType {
  String get label => switch (this) {
        MovementType.stockIn => 'Stock In',
        MovementType.stockOut => 'Stock Out',
        MovementType.adjustment => 'Adjustment',
      };
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    this.reason,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String productName;
  final MovementType type;
  final int quantity;
  final String? reason;
  final String? note;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'quantity': quantity,
        'reason': reason,
        'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory InventoryMovement.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return InventoryMovement(
      id: doc.id,
      productId: m['productId'] as String,
      productName: m['productName'] as String,
      type: MovementType.values.byName(m['type'] as String),
      quantity: m['quantity'] as int,
      reason: m['reason'] as String?,
      note: m['note'] as String?,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
    );
  }
}
