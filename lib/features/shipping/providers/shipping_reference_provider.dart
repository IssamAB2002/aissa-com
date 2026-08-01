import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
