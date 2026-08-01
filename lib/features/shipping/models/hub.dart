import 'package:cloud_firestore/cloud_firestore.dart';

class Hub {
  const Hub({
    required this.id,
    required this.zrHubId,
    required this.name,
    required this.type,
    this.isPickupPoint = false,
    this.isVisible = false,
    required this.wilayaId,
    this.street = '',
    this.district = '',
    this.postalCode = '',
    this.phone = '',
    this.lat,
    this.lng,
  });

  final String id;
  final String zrHubId;
  final String name;
  final String type;
  final bool isPickupPoint;
  final bool isVisible;
  final String wilayaId;
  final String street;
  final String district;
  final String postalCode;
  final String phone;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toMap() => {
        'zrHubId': zrHubId,
        'name': name,
        'type': type,
        'isPickupPoint': isPickupPoint,
        'isVisible': isVisible,
        'wilayaId': wilayaId,
        'street': street,
        'district': district,
        'postalCode': postalCode,
        'phone': phone,
        'lat': lat,
        'lng': lng,
      };

  factory Hub.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Hub(
      id: doc.id,
      zrHubId: m['zrHubId'] as String,
      name: m['name'] as String? ?? '',
      type: m['type'] as String? ?? 'hub',
      isPickupPoint: m['isPickupPoint'] as bool? ?? false,
      isVisible: m['isVisible'] as bool? ?? false,
      wilayaId: m['wilayaId'] as String,
      street: m['street'] as String? ?? '',
      district: m['district'] as String? ?? '',
      postalCode: m['postalCode'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
    );
  }
}
