import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/order.dart';
import '../services/orders_service.dart';

final ordersServiceProvider =
    Provider((ref) => OrdersService(FirebaseFirestore.instance));

final ordersStreamProvider = StreamProvider<List<Order>>((ref) {
  final appUser = ref.watch(currentUserProvider).valueOrNull;
  final service = ref.watch(ordersServiceProvider);
  // Employees only see orders they created; admin sees all.
  if (appUser != null && appUser.isEmployee) {
    return service.streamOrdersByCreator(appUser.uid);
  }
  return service.streamOrders();
});
