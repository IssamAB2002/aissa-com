import 'package:cloud_firestore/cloud_firestore.dart';

class Baladia {
  const Baladia({
    required this.id,
    required this.wilayaId,
    required this.nameAr,
    required this.nameFr,
    this.zrTerritoryId,
    this.isActive = true,
  });

  final String id;
  final String wilayaId;
  final String nameAr;
  final String nameFr;
  final String? zrTerritoryId;
  final bool isActive;

  Map<String, dynamic> toMap() => {
        'wilayaId': wilayaId,
        'nameAr': nameAr,
        'nameFr': nameFr,
        'zrTerritoryId': zrTerritoryId,
        'isActive': isActive,
      };

  factory Baladia.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Baladia(
      id: doc.id,
      wilayaId: m['wilayaId'] as String,
      nameAr: m['nameAr'] as String? ?? '',
      nameFr: m['nameFr'] as String? ?? '',
      zrTerritoryId: m['zrTerritoryId'] as String?,
      isActive: m['isActive'] as bool? ?? true,
    );
  }
}
