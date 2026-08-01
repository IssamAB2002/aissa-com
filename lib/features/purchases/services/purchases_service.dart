import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/purchase.dart';

class PurchasesService {
  PurchasesService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('purchases');

  Stream<List<Purchase>> streamPurchases() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Purchase.fromDoc).toList());

  /// Creates the purchase record only — stock is updated on confirm payment.
  Future<void> createPurchase(Purchase purchase) async {
    final id = const Uuid().v4();
    await _col.doc(id).set(purchase.toMap());
  }

  /// Writes the per-item stock changes and matching inventory movements for
  /// this purchase. [apply] adds stock (purchase received); otherwise the
  /// earlier addition is reversed.
  void _writeStockChanges(
    Purchase purchase, {
    required bool apply,
    required void Function(DocumentReference ref, Map<String, dynamic> data)
        update,
    required void Function(DocumentReference ref, Map<String, dynamic> data)
        set,
  }) {
    for (final item in purchase.items) {
      update(
        _db.collection('products').doc(item.productId),
        {
          'stockQuantity':
              FieldValue.increment(apply ? item.quantity : -item.quantity),
          'stockUpdatedAt': Timestamp.now(),
        },
      );
      set(
        _db.collection('inventory_movements').doc(const Uuid().v4()),
        {
          'productId': item.productId,
          'productName': item.productName,
          'type': apply ? 'stockIn' : 'stockOut',
          'quantity': item.quantity,
          'reason': apply ? 'Purchase' : 'Purchase reversed',
          'note': purchase.supplierName != null
              ? 'Supplier: ${purchase.supplierName}'
              : null,
          'createdAt': Timestamp.now(),
        },
      );
    }
  }

  /// Marks the purchase as paid, increments product stock for each item
  /// (unless the received status change already did), records StockIn
  /// movements, and adds an expense transaction to Finance.
  Future<void> confirmPayment(Purchase purchase) async {
    // Re-read the doc: stock may already have been applied when the purchase
    // was marked received, and the passed object could be stale.
    final snap = await _col.doc(purchase.id).get();
    final m = snap.data() as Map<String, dynamic>;
    final alreadyConfirmed = m['paymentConfirmed'] as bool? ?? false;
    final stockApplied = m['stockApplied'] as bool? ?? alreadyConfirmed;

    final batch = _db.batch();

    batch.update(_col.doc(purchase.id), {
      'paymentConfirmed': true,
      'status': PurchaseStatus.received.name,
      'stockApplied': true,
      'updatedAt': Timestamp.now(),
    });

    if (!stockApplied) {
      _writeStockChanges(
        purchase,
        apply: true,
        update: (ref, data) => batch.update(ref, data),
        set: (ref, data) => batch.set(ref, data),
      );
    }

    final txId = const Uuid().v4();
    final shortId = purchase.id.substring(0, 8).toUpperCase();
    batch.set(
      _db.collection('transactions').doc(txId),
      {
        'type': 'expense',
        'amount': purchase.total,
        'category': 'Supplier payment',
        'description':
            'Purchase #$shortId${purchase.supplierName != null ? ' – ${purchase.supplierName}' : ''}',
        'date': Timestamp.now(),
        'createdAt': Timestamp.now(),
      },
    );

    await batch.commit();
  }

  Future<void> updateFinance({
    required String id,
    required double fees,
    required double total,
  }) =>
      _col.doc(id).update({
        'fees': fees,
        'total': total,
        'updatedAt': Timestamp.now(),
      });

  /// Sets the purchase status. Setting [PurchaseStatus.received] adds the
  /// items to stock; moving off received (only possible before payment
  /// confirmation) reverses it. Runs in a transaction so a stale UI object
  /// or double tap can never apply the stock change twice.
  Future<void> updateStatus(Purchase purchase, PurchaseStatus newStatus) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_col.doc(purchase.id));
      final m = snap.data() as Map<String, dynamic>;
      final currentStatus = PurchaseStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => PurchaseStatus.pending,
      );
      final paymentConfirmed = m['paymentConfirmed'] as bool? ?? false;
      // Legacy docs: stock was only ever applied by confirmPayment.
      final stockApplied = m['stockApplied'] as bool? ?? paymentConfirmed;

      if (newStatus == currentStatus) return;
      if (paymentConfirmed && newStatus != PurchaseStatus.received) {
        throw StateError('Cannot change status after payment is confirmed');
      }

      final shouldApply =
          newStatus == PurchaseStatus.received && !stockApplied;
      final shouldReverse =
          newStatus != PurchaseStatus.received && stockApplied;

      if (shouldApply || shouldReverse) {
        _writeStockChanges(
          purchase,
          apply: shouldApply,
          update: (ref, data) => tx.update(ref, data),
          set: (ref, data) => tx.set(ref, data),
        );
      }

      tx.update(_col.doc(purchase.id), {
        'status': newStatus.name,
        'updatedAt': Timestamp.now(),
        if (shouldApply || shouldReverse) 'stockApplied': shouldApply,
      });
    });
  }

  Future<void> deletePurchase(String id) => _col.doc(id).delete();
}
