import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';

class IncomeService {
  IncomeService(this._db);

  final FirebaseFirestore _db;
  CollectionReference get _col => _db.collection('transactions');

  Stream<List<AppTransaction>> streamTransactions() => _col
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AppTransaction.fromDoc).toList());

  Future<void> addTransaction(AppTransaction tx) async {
    final id = const Uuid().v4();
    await _col.doc(id).set(tx.toMap());
  }

  Future<void> deleteTransaction(String id) => _col.doc(id).delete();
}
