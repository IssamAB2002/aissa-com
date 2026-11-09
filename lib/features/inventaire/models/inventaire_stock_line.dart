import 'package:cloud_firestore/cloud_firestore.dart';

/// One product's physical-count result within an Inventaire session —
/// written for every active product when the count step completes.
class InventaireStockLine {
  const InventaireStockLine({
    required this.productId,
    required this.productName,
    required this.systemQtyBefore,
    required this.countedQty,
    required this.costPrice,
  });

  final String productId;
  final String productName;
  final int systemQtyBefore;
  final int countedQty;
  final double costPrice;

  int get delta => countedQty - systemQtyBefore;
  double get valuation => countedQty * costPrice;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'systemQtyBefore': systemQtyBefore,
        'countedQty': countedQty,
        'costPrice': costPrice,
      };

  factory InventaireStockLine.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return InventaireStockLine(
      productId: m['productId'] as String,
      productName: m['productName'] as String,
      systemQtyBefore: m['systemQtyBefore'] as int,
      countedQty: m['countedQty'] as int,
      costPrice: (m['costPrice'] as num).toDouble(),
    );
  }
}
