import 'package:cloud_firestore/cloud_firestore.dart';

class Wilaya {
  const Wilaya({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameFr,
    this.zrTerritoryId,
    this.isActive = true,
    this.shippingPriceHome = 0.0,
    this.shippingPriceDesk = 0.0,
  });

  final String id;
  final int code;
  final String nameAr;
  final String nameFr;
  final String? zrTerritoryId;
  final bool isActive;
  final double shippingPriceHome;
  final double shippingPriceDesk;

  Map<String, dynamic> toMap() => {
        'code': code,
        'nameAr': nameAr,
        'nameFr': nameFr,
        'zrTerritoryId': zrTerritoryId,
        'isActive': isActive,
        'shippingPriceHome': shippingPriceHome,
        'shippingPriceDesk': shippingPriceDesk,
      };

  factory Wilaya.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Wilaya(
      id: doc.id,
      code: (m['code'] as num).toInt(),
      nameAr: m['nameAr'] as String? ?? '',
      nameFr: m['nameFr'] as String? ?? '',
      zrTerritoryId: m['zrTerritoryId'] as String?,
      isActive: m['isActive'] as bool? ?? true,
      shippingPriceHome:
          (m['shippingPriceHome'] as num? ?? 0.0).toDouble(),
      shippingPriceDesk:
          (m['shippingPriceDesk'] as num? ?? 0.0).toDouble(),
    );
  }
}
