import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../purchases/models/purchase.dart';
import '../models/purchase_list.dart';

class _GroupBuilder {
  _GroupBuilder({this.supplierId, required this.supplierName});

  final String? supplierId;
  final String supplierName;
  final List<String> _order = [];
  final Map<String, String> _names = {};
  final Map<String, int> _quantities = {};

  void addItem(String productId, String productName, int quantity) {
    if (!_quantities.containsKey(productId)) {
      _order.add(productId);
      _names[productId] = productName;
      _quantities[productId] = 0;
    }
    _quantities[productId] = _quantities[productId]! + quantity;
  }

  PurchaseListGroup build(String key) => PurchaseListGroup(
        key: key,
        supplierId: supplierId,
        supplierName: supplierName,
        items: _order
            .map((pid) => PurchaseListItem(
                  productId: pid,
                  productName: _names[pid]!,
                  quantity: _quantities[pid]!,
                ))
            .toList(),
      );
}

class PurchaseListsService {
  PurchaseListsService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('purchase_lists');
  CollectionReference get _purchasesCol => _db.collection('purchases');

  Stream<List<PurchaseList>> streamPurchaseLists() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PurchaseList.fromDoc).toList());

  Stream<PurchaseList?> streamPurchaseList(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? PurchaseList.fromDoc(d) : null);

  /// Builds a [PurchaseList] grouping [purchases]' items by supplier (merging
  /// same-product quantities), then marks every source purchase as
  /// `plGenerated` in the same batch so it can never be pulled into another
  /// list.
  Future<PurchaseList> generate({
    required List<Purchase> purchases,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    required bool isAllTime,
  }) async {
    final order = <String>[];
    final builders = <String, _GroupBuilder>{};

    for (final p in purchases) {
      final key = p.supplierId ?? 'unassigned';
      final builder = builders.putIfAbsent(key, () {
        order.add(key);
        return _GroupBuilder(
          supplierId: p.supplierId,
          supplierName: p.supplierName ?? 'No Supplier',
        );
      });
      for (final item in p.items) {
        builder.addItem(item.productId, item.productName, item.quantity);
      }
    }

    order.sort(
        (a, b) => builders[a]!.supplierName.compareTo(builders[b]!.supplierName));

    final list = PurchaseList(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      isAllTime: isAllTime,
      groups: order.map((k) => builders[k]!.build(k)).toList(),
      sourcePurchaseIds: purchases.map((p) => p.id).toList(),
    );

    final batch = _db.batch();
    batch.set(_col.doc(list.id), list.toMap());
    for (final p in purchases) {
      batch.update(_purchasesCol.doc(p.id), {
        'plGenerated': true,
        'plId': list.id,
      });
    }
    await batch.commit();
    return list;
  }

  /// Toggles a single product's checklist state within a list. Uses a
  /// [FieldPath] so arbitrary supplier/product ids never need escaping.
  Future<void> setItemChecked({
    required String listId,
    required String groupKey,
    required String productId,
    required bool checked,
  }) =>
      _col.doc(listId).update({
        FieldPath(['groups', groupKey, 'items', productId, 'checked']):
            checked,
      });

  /// Deletes the list and resets every purchase that fed into it back to
  /// `plGenerated: false` so it becomes eligible for a new list again.
  /// Looks purchases up by `plId` (rather than the list's own
  /// `sourcePurchaseIds`) so it still cleans up correctly even if a source
  /// purchase was deleted in the meantime.
  Future<void> deletePurchaseList(String id) async {
    final sourceSnap =
        await _purchasesCol.where('plId', isEqualTo: id).get();

    final batch = _db.batch();
    for (final doc in sourceSnap.docs) {
      batch.update(doc.reference, {
        'plGenerated': false,
        'plId': null,
      });
    }
    batch.delete(_col.doc(id));
    await batch.commit();
  }
}
