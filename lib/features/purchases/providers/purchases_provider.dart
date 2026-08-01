import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase.dart';
import '../services/purchases_service.dart';

final purchasesServiceProvider =
    Provider((ref) => PurchasesService(FirebaseFirestore.instance));

final purchasesStreamProvider = StreamProvider<List<Purchase>>((ref) {
  return ref.watch(purchasesServiceProvider).streamPurchases();
});
