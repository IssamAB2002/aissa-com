import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final initial = await Connectivity().checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);

  await for (final results in Connectivity().onConnectivityChanged) {
    yield results.any((r) => r != ConnectivityResult.none);
  }
});
