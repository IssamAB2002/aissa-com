import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

/// Opt-in, debug-only switch to point the app at the local Firebase
/// emulators (see firebase.emulator.json) instead of the real "aissa-com"
/// project — for manually testing features like Inventaire without
/// touching real data. Run:
///   firebase emulators:start --config firebase.emulator.json
///   flutter run --dart-define=USE_FIREBASE_EMULATOR=true
/// Never true in a release build, regardless of this flag.
const _useFirebaseEmulator =
    bool.fromEnvironment('USE_FIREBASE_EMULATOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode && _useFirebaseEmulator) {
    // 10.0.2.2 is how the Android emulator reaches the host machine's
    // localhost; every other target (iOS simulator, desktop, web) uses
    // localhost directly.
    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const ProviderScope(child: HamidEquipementApp()));
}
