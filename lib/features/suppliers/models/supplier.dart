import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory Supplier.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Supplier(
      id: doc.id,
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String?,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      updatedAt: (m['updatedAt'] as Timestamp).toDate(),
    );
  }

  Supplier copyWith({String? name, String? phone, DateTime? updatedAt}) =>
      Supplier(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
