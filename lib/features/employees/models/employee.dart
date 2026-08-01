import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  const Employee({
    required this.id,
    required this.name,
    this.role,
    this.phone,
    this.email,
    this.uid,
    this.confirmedOrders = 0,
    this.benefitPercentage = 0.0,
    this.amountOwed = 0.0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? role;
  final String? phone;
  final String? email;
  final String? uid;
  final int confirmedOrders;
  final double benefitPercentage; // 0–100
  final double amountOwed;        // accumulated unpaid reward balance
  final DateTime createdAt;

  bool get hasAccount => uid != null;

  double rewardAmount(double benefits) => (benefitPercentage / 100) * benefits;

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
        'uid': uid,
        'confirmedOrders': confirmedOrders,
        'benefitPercentage': benefitPercentage,
        'amountOwed': amountOwed,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Employee.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Employee(
      id: doc.id,
      name: m['name'] as String,
      role: m['role'] as String?,
      phone: m['phone'] as String?,
      email: m['email'] as String?,
      uid: m['uid'] as String?,
      // falls back to old ordersProcessed field for existing documents
      confirmedOrders: m['confirmedOrders'] as int? ??
          (m['ordersProcessed'] as int? ?? 0),
      benefitPercentage:
          (m['benefitPercentage'] as num? ?? 0.0).toDouble(),
      amountOwed: (m['amountOwed'] as num? ?? 0.0).toDouble(),
      createdAt: (m['createdAt'] as Timestamp).toDate(),
    );
  }

  Employee copyWith({
    String? name,
    String? role,
    String? phone,
    String? email,
    String? uid,
    int? confirmedOrders,
    double? benefitPercentage,
    double? amountOwed,
  }) =>
      Employee(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        uid: uid ?? this.uid,
        confirmedOrders: confirmedOrders ?? this.confirmedOrders,
        benefitPercentage: benefitPercentage ?? this.benefitPercentage,
        amountOwed: amountOwed ?? this.amountOwed,
        createdAt: createdAt,
      );
}

class RewardSettings {
  const RewardSettings({this.benefitPeriod = 'monthly'});

  final String benefitPeriod; // 'daily', 'weekly', 'monthly'

  Map<String, dynamic> toMap() => {'benefitPeriod': benefitPeriod};

  factory RewardSettings.fromMap(Map<String, dynamic> m) =>
      RewardSettings(
        benefitPeriod: m['benefitPeriod'] as String? ?? 'monthly',
      );
}
