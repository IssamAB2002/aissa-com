import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';

class ProductsService {
  ProductsService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('products');

  Stream<List<Product>> streamProducts() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Product.fromDoc).toList());

  Future<String> createProduct(Product product) async {
    final id = const Uuid().v4();
    await _col.doc(id).set(product.toMap());
    return id;
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> updateStock(String id, int newQty) =>
      _col.doc(id).update({
        'stockQuantity': newQty,
        'stockUpdatedAt': Timestamp.now(),
      });

  Future<void> deleteProduct(String id) => _col.doc(id).delete();
}
