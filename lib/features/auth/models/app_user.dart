import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, employee }

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.employeeId,
    required this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? employeeId;
  final DateTime createdAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'employeeId': employeeId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: m['email'] as String,
      displayName: m['displayName'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == (m['role'] as String?),
        orElse: () => UserRole.employee,
      ),
      employeeId: m['employeeId'] as String?,
      createdAt: m['createdAt'] != null
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  AppUser copyWith({
    String? displayName,
    UserRole? role,
    String? employeeId,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        employeeId: employeeId ?? this.employeeId,
        createdAt: createdAt,
      );
}
