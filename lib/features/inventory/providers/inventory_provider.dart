import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inventory_movement.dart';
import '../services/inventory_service.dart';

final inventoryServiceProvider =
    Provider((ref) => InventoryService(FirebaseFirestore.instance));

final movementsStreamProvider =
    StreamProvider<List<InventoryMovement>>((ref) {
  return ref.watch(inventoryServiceProvider).streamMovements();
});
