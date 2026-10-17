import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/supplier.dart';
import '../services/suppliers_service.dart';

final suppliersServiceProvider =
    Provider((ref) => SuppliersService(FirebaseFirestore.instance));

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  return ref.watch(suppliersServiceProvider).streamSuppliers();
});
