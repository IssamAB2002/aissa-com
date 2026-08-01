import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';

// Dev-only mock user — null in production builds
final mockUserProvider = StateProvider<AppUser?>((ref) => null);

final _mockAdminUser = AppUser(
  uid: 'dev-mock-uid',
  email: 'dev@aissacom.test',
  displayName: 'Dev Admin',
  role: UserRole.admin,
  createdAt: DateTime(2024, 1, 1),
);

final _mockEmployeeUser = AppUser(
  uid: 'dev-employee-uid',
  email: 'employee@aissacom.test',
  displayName: 'Test Employee',
  role: UserRole.employee,
  createdAt: DateTime(2024, 1, 1),
);

// Convenience getters used by the login screens
AppUser get mockAdminUser => _mockAdminUser;
AppUser get mockEmployeeUser => _mockEmployeeUser;

final firebaseAuthStateProvider = StreamProvider<User?>((ref) async* {
  final auth = FirebaseAuth.instance;
  // Restore (or expire) the saved 7-day session before the first auth state
  // is emitted — the router holds the splash screen until this completes.
  await ref.read(sessionManagerProvider).restoreSession(auth);
  yield* auth.authStateChanges();
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  if (kDebugMode) {
    final mock = ref.watch(mockUserProvider);
    if (mock != null) return Stream.value(mock);
  }
  final authAsync = ref.watch(firebaseAuthStateProvider);
  final firebaseUser = authAsync.valueOrNull;
  if (firebaseUser == null) return Stream.value(null);
  return ref.read(authServiceProvider).userProfileStream(firebaseUser.uid);
});
