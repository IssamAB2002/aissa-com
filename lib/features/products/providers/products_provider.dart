import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../services/products_service.dart';

final productsServiceProvider =
    Provider((ref) => ProductsService(FirebaseFirestore.instance));

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productsServiceProvider).streamProducts();
});
