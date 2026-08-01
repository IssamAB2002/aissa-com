import 'package:cloud_firestore/cloud_firestore.dart';

class Wilaya {
  const Wilaya({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameFr,
    this.zrTerritoryId,
    this.shippingPriceHome = 700,
    this.shippingPriceDesk = 450,
    this.isActive = true,
  });

  final String id;
  final int code;
  final String nameAr;
  final String nameFr;
  final String? zrTerritoryId;
  final double shippingPriceHome;
  final double shippingPriceDesk;
  final bool isActive;

  Map<String, dynamic> toMap() => {
        'code': code,
        'nameAr': nameAr,
        'nameFr': nameFr,
        'zrTerritoryId': zrTerritoryId,
        'shippingPriceHome': shippingPriceHome,
        'shippingPriceDesk': shippingPriceDesk,
        'isActive': isActive,
      };

  factory Wilaya.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Wilaya(
      id: doc.id,
      code: (m['code'] as num).toInt(),
      nameAr: m['nameAr'] as String? ?? '',
      nameFr: m['nameFr'] as String? ?? '',
      zrTerritoryId: m['zrTerritoryId'] as String?,
      shippingPriceHome:
          (m['shippingPriceHome'] as num? ?? 700).toDouble(),
      shippingPriceDesk:
          (m['shippingPriceDesk'] as num? ?? 450).toDouble(),
      isActive: m['isActive'] as bool? ?? true,
    );
  }
}
