import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inventaire.dart';
import '../models/inventaire_resolution.dart';
import '../models/inventaire_stock_line.dart';
import '../services/inventaire_export_service.dart';
import '../services/inventaire_service.dart';

final inventaireServiceProvider =
    Provider((ref) => InventaireService(FirebaseFirestore.instance));

final inventaireExportServiceProvider =
    Provider((ref) => InventaireExportService());

final inventaireHistoryStreamProvider =
    StreamProvider<List<Inventaire>>((ref) {
  return ref.watch(inventaireServiceProvider).streamHistory();
});

final inventaireDraftStreamProvider = StreamProvider<Inventaire?>((ref) {
  return ref.watch(inventaireServiceProvider).watchDraft();
});

final inventaireByIdProvider =
    StreamProvider.family<Inventaire?, String>((ref, id) {
  return ref.watch(inventaireServiceProvider).watchById(id);
});

final inventaireStockLinesProvider =
    StreamProvider.family<List<InventaireStockLine>, String>((ref, id) {
  return ref.watch(inventaireServiceProvider).streamStockLines(id);
});

final inventaireResolvedOrdersProvider =
    StreamProvider.family<List<InventaireResolution>, String>((ref, id) {
  return ref.watch(inventaireServiceProvider).streamResolvedOrders(id);
});

final inventaireResolvedPurchasesProvider =
    StreamProvider.family<List<InventaireResolution>, String>((ref, id) {
  return ref.watch(inventaireServiceProvider).streamResolvedPurchases(id);
});

final inventaireResolvedOrderPaymentsProvider =
    StreamProvider.family<List<InventaireResolution>, String>((ref, id) {
  return ref.watch(inventaireServiceProvider).streamResolvedOrderPayments(id);
});

final inventaireResolvedPurchasePaymentsProvider =
    StreamProvider.family<List<InventaireResolution>, String>((ref, id) {
  return ref
      .watch(inventaireServiceProvider)
      .streamResolvedPurchasePayments(id);
});
