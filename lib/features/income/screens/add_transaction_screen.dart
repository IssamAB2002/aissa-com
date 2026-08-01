import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../employees/providers/employees_provider.dart';
import '../models/transaction.dart';
import '../providers/income_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TransactionType _type = TransactionType.income;
  String? _category;
  String? _selectedEmployeeId; // only used when category == 'Salaries'
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isSalary =>
      _type == TransactionType.expense && _category == 'Salaries';

  List<String> get _categories => _type == TransactionType.income
      ? AppTransaction.incomeCategories
      : AppTransaction.expenseCategories;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final amount = double.parse(_amountCtrl.text.trim());

    final tx = AppTransaction(
      id: const Uuid().v4(),
      type: _type,
      amount: amount,
      category: _category,
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      employeeId: _isSalary ? _selectedEmployeeId : null,
      date: _date,
      createdAt: DateTime.now(),
    );

    await ref.read(incomeServiceProvider).addTransaction(tx);

    // Deduct from employee's amountOwed when a salary is paid to a specific employee
    if (_isSalary && _selectedEmployeeId != null) {
      await ref
          .read(employeesServiceProvider)
          .deductAmountOwed(_selectedEmployeeId!, amount);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final employees = employeesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Add Entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: TransactionType.values.map((t) {
                  final selected = _type == t;
                  final isIncome = t == TransactionType.income;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = t;
                        _category = null;
                        _selectedEmployeeId = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? (isIncome
                                  ? Colors.green.shade600
                                  : Colors.red.shade600)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isIncome ? 'Income' : 'Expense',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixText: 'DZD ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration:
                  const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (c) => setState(() {
                _category = c;
                if (c != 'Salaries') _selectedEmployeeId = null;
              }),
            ),
            const SizedBox(height: 12),

            // Employee picker — shown only for Salaries expense
            if (_isSalary) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SALARY PAYMENT FOR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: _selectedEmployeeId,
                      decoration: const InputDecoration(
                        labelText: 'Employee',
                        hintText: 'Select employee (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Admin / General'),
                        ),
                        if (employees.isEmpty)
                          const DropdownMenuItem<String?>(
                            value: '__loading__',
                            enabled: false,
                            child: Text('No employees found'),
                          )
                        else
                          ...employees.map((e) => DropdownMenuItem<String?>(
                                value: e.id,
                                child: Row(
                                  children: [
                                    Text(e.name),
                                    if (e.amountOwed > 0) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(owed DZD ${e.amountOwed.toStringAsFixed(0)})',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.warning),
                                      ),
                                    ],
                                  ],
                                ),
                              )),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedEmployeeId = v),
                    ),
                    if (_selectedEmployeeId != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'The entered amount will be deducted from this employee\'s owed balance.',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(
                  '${_date.day}/${_date.month}/${_date.year}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE5E5EA)),
              ),
              tileColor: Colors.white,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Entry'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
