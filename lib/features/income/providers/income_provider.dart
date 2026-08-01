import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../services/income_service.dart';

final incomeServiceProvider =
    Provider((ref) => IncomeService(FirebaseFirestore.instance));

final transactionsStreamProvider =
    StreamProvider<List<AppTransaction>>((ref) {
  return ref.watch(incomeServiceProvider).streamTransactions();
});

/// Filters all transactions to salary payments linked to a specific employee.
final salaryPaymentsProvider =
    Provider.family<List<AppTransaction>, String>((ref, employeeId) {
  final transactions =
      ref.watch(transactionsStreamProvider).valueOrNull ?? [];
  return transactions
      .where((t) =>
          t.type == TransactionType.expense &&
          t.category == 'Salaries' &&
          t.employeeId == employeeId)
      .toList();
});
