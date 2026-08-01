import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:uuid/uuid.dart';

import '../models/order.dart';

class OrdersService {
  OrdersService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('orders');
  CollectionReference get _txCol => _db.collection('transactions');

  Stream<List<Order>> streamOrders() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Order.fromDoc).toList());

  Stream<List<Order>> streamOrdersByCreator(String uid) => _col
      .where('creatorId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Order.fromDoc).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Future<void> createOrder(Order order) async {
    final id = const Uuid().v4();
    await _col.doc(id).set(order.toMap());
  }

  /// Writes the per-item stock changes and matching inventory movements for
  /// this order. [apply] subtracts stock (order delivered); otherwise the
  /// earlier subtraction is restored.
  void _writeStockChanges(
    Order order, {
    required bool apply,
    required void Function(DocumentReference ref, Map<String, dynamic> data)
        update,
    required void Function(DocumentReference ref, Map<String, dynamic> data)
        set,
  }) {
    final shortId = order.id.substring(0, 8).toUpperCase();
    for (final item in order.items) {
      update(
        _db.collection('products').doc(item.productId),
        {
          'stockQuantity':
              FieldValue.increment(apply ? -item.quantity : item.quantity),
          'stockUpdatedAt': Timestamp.now(),
        },
      );
      set(
        _db.collection('inventory_movements').doc(const Uuid().v4()),
        {
          'productId': item.productId,
          'productName': item.productName,
          'type': apply ? 'stockOut' : 'stockIn',
          'quantity': item.quantity,
          'reason': apply ? 'Order' : 'Order reversed',
          'note': 'Order #$shortId – ${order.customerName}',
          'createdAt': Timestamp.now(),
        },
      );
    }
  }

  /// Sets the order status. Setting [OrderStatus.delivered] subtracts the
  /// items from stock; moving off delivered (only possible before payment
  /// confirmation) restores it. Runs in a transaction so a stale UI object
  /// or double tap can never apply the stock change twice.
  Future<void> updateStatus(Order order, OrderStatus newStatus) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_col.doc(order.id));
      final m = snap.data() as Map<String, dynamic>;
      final currentStatus = OrderStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => OrderStatus.pending,
      );
      final paymentConfirmed = m['paymentConfirmed'] as bool? ?? false;
      // Legacy docs: stock was only ever applied by confirmPayment.
      final stockApplied = m['stockApplied'] as bool? ?? paymentConfirmed;

      if (newStatus == currentStatus) return;
      if (paymentConfirmed && newStatus != OrderStatus.delivered) {
        throw StateError('Cannot change status after payment is confirmed');
      }

      final shouldApply =
          newStatus == OrderStatus.delivered && !stockApplied;
      final shouldReverse =
          newStatus != OrderStatus.delivered && stockApplied;

      if (shouldApply || shouldReverse) {
        _writeStockChanges(
          order,
          apply: shouldApply,
          update: (ref, data) => tx.update(ref, data),
          set: (ref, data) => tx.set(ref, data),
        );
      }

      tx.update(_col.doc(order.id), {
        'status': newStatus.name,
        'updatedAt': Timestamp.now(),
        if (shouldApply || shouldReverse) 'stockApplied': shouldApply,
      });
    });
  }

  Future<void> updateFinance({
    required String id,
    required double deliveryPrice,
    required double discountAmount,
    required double total,
  }) => _col.doc(id).update({
        'deliveryPrice': deliveryPrice,
        'discountAmount': discountAmount,
        'total': total,
        'updatedAt': Timestamp.now(),
      });

  /// Marks the order as paid, decrements product stock, adds an income
  /// transaction, auto-sets status to delivered, and credits the creating
  /// employee's reward to their amountOwed.
  /// Returns true if the reward was credited, false if skipped
  /// (employee not found or benefitPercentage == 0).
  Future<bool> confirmPayment(Order order) async {
    // Re-read the doc: stock may already have been applied when the order
    // was marked delivered, and the passed object could be stale.
    final snap = await _col.doc(order.id).get();
    final m = snap.data() as Map<String, dynamic>;
    final alreadyConfirmed = m['paymentConfirmed'] as bool? ?? false;
    final stockApplied = m['stockApplied'] as bool? ?? alreadyConfirmed;

    final batch = _db.batch();

    batch.update(_col.doc(order.id), {
      'paymentConfirmed': true,
      'status': OrderStatus.delivered.name,
      'stockApplied': true,
      'updatedAt': Timestamp.now(),
    });

    // Decrement stock for every item (negative stock = out of stock in UI),
    // unless the delivery status change already did.
    if (!stockApplied) {
      _writeStockChanges(
        order,
        apply: true,
        update: (ref, data) => batch.update(ref, data),
        set: (ref, data) => batch.set(ref, data),
      );
    }

    final txId = const Uuid().v4();
    final shortId = order.id.substring(0, 8).toUpperCase();
    batch.set(
      _txCol.doc(txId),
      {
        'type': 'income',
        'amount': order.total,
        'category': 'Sales',
        'description': 'Order #$shortId – ${order.customerName}',
        'date': Timestamp.now(),
        'createdAt': Timestamp.now(),
      },
    );

    // Credit the employee's reward share automatically
    var rewardCredited = false;
    if (order.creatorId != null) {
      final empSnap = await _db
          .collection('employees')
          .where('uid', isEqualTo: order.creatorId)
          .limit(1)
          .get();
      if (empSnap.docs.isNotEmpty) {
        final empData = empSnap.docs.first.data();
        final pct = (empData['benefitPercentage'] as num? ?? 0).toDouble();
        if (pct > 0) {
          final reward = (pct / 100) * order.netProfit;
          batch.update(empSnap.docs.first.reference,
              {'amountOwed': FieldValue.increment(reward)});
          rewardCredited = true;
        }
      }
    }

    await batch.commit();
    return rewardCredited;
  }

  Future<void> deleteOrder(String id) => _col.doc(id).delete();

  Future<void> markZrPushed(
    String id, {
    required String zrParcelId,
    required String zrTrackingNumber,
    required String zrCustomerId,
  }) =>
      _col.doc(id).update({
        'zrSubmitted': true,
        'zrParcelId': zrParcelId,
        'zrTrackingNumber': zrTrackingNumber,
        'zrCustomerId': zrCustomerId,
        'zrPostedAt': Timestamp.now(),
      });

  Future<void> clearZr(String id) => _col.doc(id).update({
        'zrSubmitted': false,
        'zrParcelId': null,
        'zrTrackingNumber': null,
        'zrPostedAt': null,
      });
}
