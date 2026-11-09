import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/inventaire.dart';
import '../models/inventaire_resolution.dart';
import '../models/inventaire_stock_line.dart';

/// Orchestrates an Inventaire (periodic stock-take) session. Does not
/// reimplement stock mutation — order/purchase status changes and the
/// physical-count correction are applied via the existing OrdersService,
/// PurchasesService and InventoryService; this service only tracks the
/// session itself and the audit trail of what was resolved/counted.
class InventaireService {
  InventaireService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('inventaires');

  /// Ordered by `createdAt` (a single-field index, created automatically)
  /// rather than `where(status) + orderBy(finalizedAt)`, which would need
  /// a composite index — filtering `finalized` client-side avoids that.
  Stream<List<Inventaire>> streamHistory() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map(Inventaire.fromDoc)
          .where((i) => i.status == InventaireStatus.finalized)
          .toList());

  /// At most one draft session can exist at a time.
  Stream<Inventaire?> watchDraft() => _col
      .where('status', isEqualTo: InventaireStatus.draft.name)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Inventaire.fromDoc(s.docs.first));

  Stream<Inventaire?> watchById(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Inventaire.fromDoc(d) : null);

  /// Starts a new draft session. `periodStart` is auto-set to the last
  /// finalized session's `periodEnd` (null for the very first session).
  /// `periodEnd` defaults to now, but the admin can pick a custom cutoff
  /// date instead (still editable afterwards via [updatePeriodEnd] while
  /// the session remains a draft).
  Future<Inventaire> startSession(
    String? createdBy, {
    DateTime? periodEnd,
  }) async {
    // Same single-field-index approach as streamHistory(): filter and sort
    // the finalized docs client-side instead of a composite query.
    final snap = await _col.orderBy('createdAt', descending: true).get();
    final finalized = snap.docs
        .map(Inventaire.fromDoc)
        .where((i) => i.status == InventaireStatus.finalized)
        .toList()
      ..sort((a, b) => (b.finalizedAt ?? b.createdAt)
          .compareTo(a.finalizedAt ?? a.createdAt));

    final periodStart = finalized.isNotEmpty ? finalized.first.periodEnd : null;

    final id = const Uuid().v4();
    final now = DateTime.now();
    final inventaire = Inventaire(
      id: id,
      periodStart: periodStart,
      periodEnd: periodEnd ?? now,
      status: InventaireStatus.draft,
      createdAt: now,
      createdBy: createdBy,
    );
    await _col.doc(id).set(inventaire.toMap());
    return inventaire;
  }

  /// Only valid while the session is still a draft.
  Future<void> updatePeriodEnd(String id, DateTime newEnd) =>
      _col.doc(id).update({'periodEnd': Timestamp.fromDate(newEnd)});

  Future<void> recordOrderResolution(
    String id,
    InventaireResolution resolution,
  ) =>
      _col
          .doc(id)
          .collection('resolved_orders')
          .doc(resolution.refId)
          .set(resolution.toMap());

  Future<void> recordPurchaseResolution(
    String id,
    InventaireResolution resolution,
  ) =>
      _col
          .doc(id)
          .collection('resolved_purchases')
          .doc(resolution.refId)
          .set(resolution.toMap());

  Stream<List<InventaireResolution>> streamResolvedOrders(String id) => _col
      .doc(id)
      .collection('resolved_orders')
      .snapshots()
      .map((s) => s.docs.map(InventaireResolution.fromDoc).toList());

  Stream<List<InventaireResolution>> streamResolvedPurchases(String id) =>
      _col
          .doc(id)
          .collection('resolved_purchases')
          .snapshots()
          .map((s) => s.docs.map(InventaireResolution.fromDoc).toList());

  /// Separate subcollections from `resolved_orders`/`resolved_purchases`:
  /// those are keyed by refId and already hold the fulfillment-resolution
  /// row for the same order/purchase, so a payment-settlement row needs its
  /// own doc to avoid overwriting it.
  Future<void> recordOrderPaymentResolution(
    String id,
    InventaireResolution resolution,
  ) =>
      _col
          .doc(id)
          .collection('resolved_order_payments')
          .doc(resolution.refId)
          .set(resolution.toMap());

  Future<void> recordPurchasePaymentResolution(
    String id,
    InventaireResolution resolution,
  ) =>
      _col
          .doc(id)
          .collection('resolved_purchase_payments')
          .doc(resolution.refId)
          .set(resolution.toMap());

  Stream<List<InventaireResolution>> streamResolvedOrderPayments(
    String id,
  ) =>
      _col
          .doc(id)
          .collection('resolved_order_payments')
          .snapshots()
          .map((s) => s.docs.map(InventaireResolution.fromDoc).toList());

  Stream<List<InventaireResolution>> streamResolvedPurchasePayments(
    String id,
  ) =>
      _col
          .doc(id)
          .collection('resolved_purchase_payments')
          .snapshots()
          .map((s) => s.docs.map(InventaireResolution.fromDoc).toList());

  /// Writes one row per counted product. Chunked to stay under Firestore's
  /// 500-write batch cap for shops with large catalogs.
  Future<void> saveStockLines(
    String id,
    List<InventaireStockLine> lines,
  ) async {
    const chunkSize = 400;
    for (var i = 0; i < lines.length; i += chunkSize) {
      final batch = _db.batch();
      for (final line in lines.skip(i).take(chunkSize)) {
        batch.set(
          _col.doc(id).collection('stock_lines').doc(line.productId),
          line.toMap(),
        );
      }
      await batch.commit();
    }
  }

  Stream<List<InventaireStockLine>> streamStockLines(String id) => _col
      .doc(id)
      .collection('stock_lines')
      .snapshots()
      .map((s) => s.docs.map(InventaireStockLine.fromDoc).toList());

  Future<void> finalize(
    String id, {
    required double totalStockValuation,
    required int totalOrdersResolved,
    required int totalPurchasesResolved,
    required int totalOrderPaymentsSettled,
    required int totalPurchasePaymentsSettled,
  }) =>
      _col.doc(id).update({
        'status': InventaireStatus.finalized.name,
        'finalizedAt': Timestamp.now(),
        'totalStockValuation': totalStockValuation,
        'totalOrdersResolved': totalOrdersResolved,
        'totalPurchasesResolved': totalPurchasesResolved,
        'totalOrderPaymentsSettled': totalOrderPaymentsSettled,
        'totalPurchasePaymentsSettled': totalPurchasePaymentsSettled,
      });
}
