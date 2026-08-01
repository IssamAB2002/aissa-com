import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the user signed in across app restarts for up to [sessionDuration].
///
/// Firebase Auth normally persists its own session, but if the platform drops
/// it, this silently re-authenticates with the credentials saved (in the
/// OS keystore) at the last sign-in. Opening the app renews the window, so
/// the user is only asked to log in again after a full week of not using it.
class SessionManager {
  SessionManager(this._storage);

  final FlutterSecureStorage _storage;

  static const sessionDuration = Duration(days: 7);

  static const _kEmail = 'session_email';
  static const _kPassword = 'session_password';
  static const _kLoginAt = 'session_login_at';

  Future<void> saveSession(String email, String password) async {
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kPassword, value: password);
    await _refreshTimestamp();
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPassword);
    await _storage.delete(key: _kLoginAt);
  }

  Future<void> _refreshTimestamp() =>
      _storage.write(key: _kLoginAt, value: DateTime.now().toIso8601String());

  /// Called once on app start, before the router reads the auth state.
  /// Restores the session if Firebase lost it, or expires it after a week.
  /// Never throws — on any failure the user simply sees the login screen.
  Future<void> restoreSession(FirebaseAuth auth) async {
    try {
      final email = await _storage.read(key: _kEmail);
      final password = await _storage.read(key: _kPassword);
      final loginAtRaw = await _storage.read(key: _kLoginAt);

      if (email == null || password == null) {
        // No saved session (first run after this update). If Firebase itself
        // kept the user signed in, keep them — the week starts counting now.
        if (auth.currentUser != null && loginAtRaw == null) {
          await _refreshTimestamp();
        }
        return;
      }

      final loginAt = DateTime.tryParse(loginAtRaw ?? '');
      final expired = loginAt == null ||
          DateTime.now().difference(loginAt) > sessionDuration;
      if (expired) {
        await clearSession();
        if (auth.currentUser != null) await auth.signOut();
        return;
      }

      if (auth.currentUser == null) {
        try {
          await auth.signInWithEmailAndPassword(
              email: email, password: password);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'network-request-failed') return; // retry next launch
          await clearSession(); // password changed, account disabled, etc.
          return;
        }
      }

      // Rolling window: each app open within the week renews it.
      await _refreshTimestamp();
    } catch (_) {
      // Storage failure — fall back to whatever Firebase has.
    }
  }
}

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(const FlutterSecureStorage());
});
