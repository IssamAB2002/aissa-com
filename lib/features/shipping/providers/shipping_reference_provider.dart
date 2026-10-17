import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/services/session_manager.dart';
import '../models/baladia.dart';
import '../models/hub.dart';
import '../models/wilaya.dart';
import '../models/zr_settings.dart';
import '../services/shipping_reference_service.dart';
import '../services/zr_client.dart';

final shippingReferenceServiceProvider = Provider(
    (ref) => ShippingReferenceService(FirebaseFirestore.instance));

final zrClientProvider =
    Provider((ref) => ZrClient(FirebaseFirestore.instance));

final wilayasStreamProvider = StreamProvider<List<Wilaya>>((ref) {
  return ref.watch(shippingReferenceServiceProvider).streamWilayas();
});

final baladiasStreamProvider =
    StreamProvider.family<List<Baladia>, String?>((ref, wilayaId) {
  return ref.watch(shippingReferenceServiceProvider).streamBaladias(wilayaId);
});

final hubsStreamProvider =
    StreamProvider.family<List<Hub>, String?>((ref, wilayaId) {
  return ref.watch(shippingReferenceServiceProvider).streamHubs(wilayaId);
});

final zrSettingsStreamProvider = StreamProvider<ZrSettings>((ref) {
  return ref.watch(shippingReferenceServiceProvider).streamZrSettings();
});

/// Resolves ZR credentials for an API call: prefers the live Firestore value
/// (already loaded by [zrSettingsStreamProvider]), falling back to the
/// device-local session cache so a parcel can still be sent before that
/// stream has resolved (e.g. right after an app restart).
Future<ZrSettings?> resolveZrSettings(WidgetRef ref) async {
  final live = ref.read(zrSettingsStreamProvider).valueOrNull;
  if (live != null && live.isConfigured) return live;

  final cached = await ref.read(sessionManagerProvider).readZrSecrets();
  if (cached == null) return null;
  return ZrSettings(secretKey: cached.secretKey, tenantId: cached.tenantId);
}
