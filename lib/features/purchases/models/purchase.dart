import 'package:cloud_firestore/cloud_firestore.dart';

enum PurchaseStatus { pending, received, cancelled }

extension PurchaseStatusX on PurchaseStatus {
  String get label => switch (this) {
        PurchaseStatus.pending => 'Pending',
        PurchaseStatus.received => 'Received',
        PurchaseStatus.cancelled => 'Cancelled',
      };
}

class PurchaseItem {
  const PurchaseItem({
    required this.productId,
    required this.productName,
    required this.unitCost,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final double unitCost;
  final int quantity;

  double get subtotal => unitCost * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'unitCost': unitCost,
        'quantity': quantity,
      };

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
        productId: m['productId'] as String,
        productName: m['productName'] as String,
        unitCost: (m['unitCost'] as num).toDouble(),
        quantity: m['quantity'] as int,
      );
}

class Purchase {
  const Purchase({
    required this.id,
    this.supplierId,
    this.supplierName,
    required this.items,
    required this.total,
    this.fees = 0.0,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.paymentConfirmed = false,
    this.stockApplied = false,
    this.sourceOrderId,
    this.plGenerated = false,
    this.plId,
  });

  final String id;
  final String? supplierId;
  final String? supplierName;
  final List<PurchaseItem> items;
  final double total;
  final double fees;
  final PurchaseStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool paymentConfirmed;
  final bool stockApplied;
  /// The order this purchase was generated from via "Create Purchase from
  /// Order", if any. Null for purchases created manually.
  final String? sourceOrderId;
  /// Whether this purchase's items were already pulled into a Purchase
  /// List — prevents the same items being requested twice.
  final bool plGenerated;
  final String? plId;

  double get itemsSubtotal => items.fold(0.0, (s, i) => s + i.subtotal);

  Map<String, dynamic> toMap() => {
        'supplierId': supplierId,
        'supplierName': supplierName,
        'items': items.map((e) => e.toMap()).toList(),
        'total': total,
        'fees': fees,
        'status': status.name,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt':
            updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'paymentConfirmed': paymentConfirmed,
        'stockApplied': stockApplied,
        'sourceOrderId': sourceOrderId,
        'plGenerated': plGenerated,
        'plId': plId,
      };

  factory Purchase.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Purchase(
      id: doc.id,
      supplierId: m['supplierId'] as String?,
      supplierName: m['supplierName'] as String?,
      items: (m['items'] as List)
          .map((e) => PurchaseItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      total: (m['total'] as num).toDouble(),
      fees: (m['fees'] as num? ?? 0.0).toDouble(),
      status: PurchaseStatus.values.byName(m['status'] as String),
      notes: m['notes'] as String?,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      paymentConfirmed: m['paymentConfirmed'] as bool? ?? false,
      // Legacy docs lack this field: stock was only ever applied by
      // confirmPayment, so treat confirmed docs as already applied.
      stockApplied: m['stockApplied'] as bool? ??
          (m['paymentConfirmed'] as bool? ?? false),
      sourceOrderId: m['sourceOrderId'] as String?,
      plGenerated: m['plGenerated'] as bool? ?? false,
      plId: m['plId'] as String?,
    );
  }

  Purchase copyWith({
    PurchaseStatus? status,
    String? notes,
    DateTime? updatedAt,
    double? fees,
    double? total,
  }) =>
      Purchase(
        id: id,
        supplierId: supplierId,
        supplierName: supplierName,
        items: items,
        total: total ?? this.total,
        fees: fees ?? this.fees,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        paymentConfirmed: paymentConfirmed,
        stockApplied: stockApplied,
        sourceOrderId: sourceOrderId,
        plGenerated: plGenerated,
        plId: plId,
      );
}
