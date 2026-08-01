import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.category,
    this.description,
    this.employeeId,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String? category;
  final String? description;
  final String? employeeId; // linked employee for Salaries expense
  final DateTime date;
  final DateTime createdAt;

  static const incomeCategories = [
    'Sales',
    'Service',
    'Refund received',
    'Other income',
  ];

  static const expenseCategories = [
    'Supplier payment',
    'Shipping',
    'Refund issued',
    'Marketing',
    'Utilities',
    'Salaries',
    'Other expense',
  ];

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'amount': amount,
        'category': category,
        'description': description,
        if (employeeId != null) 'employeeId': employeeId,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory AppTransaction.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return AppTransaction(
      id: doc.id,
      type: TransactionType.values.byName(m['type'] as String),
      amount: (m['amount'] as num).toDouble(),
      category: m['category'] as String?,
      description: m['description'] as String?,
      employeeId: m['employeeId'] as String?,
      date: (m['date'] as Timestamp).toDate(),
      createdAt: (m['createdAt'] as Timestamp).toDate(),
    );
  }
}
