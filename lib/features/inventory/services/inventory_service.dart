import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../products/services/products_service.dart';
import '../models/inventory_movement.dart';

class InventoryService {
  InventoryService(this._db) : _productsService = ProductsService(_db);

  final FirebaseFirestore _db;
  final ProductsService _productsService;
  CollectionReference get _col => _db.collection('inventory_movements');

  Stream<List<InventoryMovement>> streamMovements() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(InventoryMovement.fromDoc).toList());

  Future<void> deleteMovement(String id) => _col.doc(id).delete();

  Future<void> clearAllMovements() async {
    final snap = await _col.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> adjustStock({
    required String productId,
    required String productName,
    required MovementType type,
    required int quantity,
    required int currentStock,
    String? reason,
    String? note,
  }) async {
    final id = const Uuid().v4();
    final movement = InventoryMovement(
      id: id,
      productId: productId,
      productName: productName,
      type: type,
      quantity: quantity,
      reason: reason,
      note: note,
      createdAt: DateTime.now(),
    );

    final newStock = type == MovementType.stockIn
        ? currentStock + quantity
        : type == MovementType.stockOut
            ? currentStock - quantity
            : quantity; // adjustment sets absolute value

    await Future.wait([
      _col.doc(id).set(movement.toMap()),
      _productsService.updateStock(productId, newStock),
    ]);
  }
}
