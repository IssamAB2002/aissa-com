import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase_list.dart';
import '../services/purchase_lists_service.dart';

final purchaseListsServiceProvider =
    Provider((ref) => PurchaseListsService(FirebaseFirestore.instance));

final purchaseListsStreamProvider = StreamProvider<List<PurchaseList>>((ref) {
  return ref.watch(purchaseListsServiceProvider).streamPurchaseLists();
});

final purchaseListProvider =
    StreamProvider.family<PurchaseList?, String>((ref, id) {
  return ref.watch(purchaseListsServiceProvider).streamPurchaseList(id);
});
