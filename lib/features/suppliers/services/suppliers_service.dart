import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier.dart';

class SuppliersService {
  SuppliersService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('suppliers');

  Stream<List<Supplier>> streamSuppliers() => _col
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Supplier.fromDoc).toList());

  Future<void> createSupplier(Supplier supplier) =>
      _col.doc(supplier.id).set(supplier.toMap());

  Future<void> updateSupplier(String id, {
    required String name,
    String? phone,
  }) =>
      _col.doc(id).update({
        'name': name,
        'phone': phone,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

  Future<void> deleteSupplier(String id) => _col.doc(id).delete();
}
