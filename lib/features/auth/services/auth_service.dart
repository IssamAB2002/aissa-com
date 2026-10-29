import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import 'session_manager.dart';

class AuthService {
  AuthService(this._auth, this._firestore, this._session);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final SessionManager _session;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<AppUser?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
        );
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  Future<AppUser> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    AppUser? profile = await getUserProfile(uid);

    // Fallback: the Firestore document was created manually with a custom ID
    // that does not match the Firebase Auth UID. Query by email, then migrate
    // the document so it uses the correct UID as its key going forward.
    if (profile == null) {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final m = doc.data();
        profile = AppUser(
          uid: uid,
          email: m['email'] as String,
          displayName: m['displayName'] as String? ?? email.trim().split('@').first,
          role: UserRole.values.firstWhere(
            (r) => r.name == (m['role'] as String?),
            orElse: () => UserRole.employee,
          ),
          employeeId: m['employeeId'] as String?,
          createdAt: m['createdAt'] != null
              ? (m['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          permissions:
              ((m['permissions'] as List?)?.cast<String>() ?? const [])
                  .toSet(),
        );
        // Write document under the correct UID key and remove the mismatched one.
        await _firestore.collection('users').doc(uid).set(profile.toMap());
        if (doc.id != uid) await doc.reference.delete();
      }
    }

    if (profile == null) throw Exception('Account not found. Contact your admin.');
    await _session.saveSession(email.trim(), password);
    return profile;
  }

  Future<AppUser> registerEmployee(
      String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    try {
      await credential.user!.updateDisplayName(name.trim());
      final employeeId = const Uuid().v4();
      final now = DateTime.now();
      final user = AppUser(
        uid: uid,
        email: email.trim(),
        displayName: name.trim(),
        role: UserRole.employee,
        employeeId: employeeId,
        createdAt: now,
      );
      // Batch write: both docs succeed or neither does. This prevents the
      // router from redirecting to the dashboard before the employees doc
      // exists, which would leave the employee invisible in the list.
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(uid), user.toMap());
      batch.set(_firestore.collection('employees').doc(employeeId), {
        'name': name.trim(),
        'role': null,
        'phone': null,
        'email': email.trim(),
        'uid': uid,
        'confirmedOrders': 0,
        'benefitPercentage': 0.0,
        'createdAt': Timestamp.fromDate(now),
      });
      await batch.commit();
      await _session.saveSession(email.trim(), password);
      return user;
    } catch (e) {
      // Clean up the Auth account so the user can retry with the same email.
      await credential.user?.delete();
      rethrow;
    }
  }

  Future<AppUser> registerFirstAdmin(
      String email, String password, String name) async {
    final existing =
        await _firestore.collection('users').limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw Exception('An admin already exists. Please log in instead.');
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name.trim());
    final user = AppUser(
      uid: credential.user!.uid,
      email: email.trim(),
      displayName: name.trim(),
      role: UserRole.admin,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
    await _session.saveSession(email.trim(), password);
    return user;
  }

  Future<void> updateUserPermissions(String uid, Set<String> permissions) =>
      _firestore
          .collection('users')
          .doc(uid)
          .update({'permissions': permissions.toList()});

  /// Repairs a user's `employeeId` link, e.g. when it still holds a stale
  /// value (such as the old Firebase Auth uid from before employees had
  /// their own doc id) instead of a real `employees` document id.
  Future<void> repairEmployeeId(String uid, String employeeId) =>
      _firestore.collection('users').doc(uid).update({
        'employeeId': employeeId,
      });

  Future<void> signOut() async {
    await _session.clearSession();
    await _auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
    ref.read(sessionManagerProvider),
  );
});
