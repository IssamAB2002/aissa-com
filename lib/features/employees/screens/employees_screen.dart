import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../orders/models/order.dart';
import '../../orders/providers/orders_provider.dart';
import '../models/employee.dart';
import '../providers/employees_provider.dart';
import '../widgets/employee_card.dart';

/// Returns confirmed-order count and net profit total for [uid] within [period].
({int count, double total}) _employeeStats(
    List<Order> orders, String? uid, String period) {
  if (uid == null) return (count: 0, total: 0.0);
  final now = DateTime.now();
  final matched = orders.where((o) {
    if (!o.paymentConfirmed || o.creatorId != uid) return false;
    final d = o.createdAt;
    switch (period) {
      case 'daily':
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case 'weekly':
        final weekStart =
            DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return d.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
            d.isBefore(weekEnd);
      case 'monthly':
        return d.year == now.year && d.month == now.month;
      default:
        return false;
    }
  }).toList();
  return (
    count: matched.length,
    total: matched.fold(0.0, (s, o) => s + o.netProfit),
  );
}

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final settingsAsync = ref.watch(rewardSettingsProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final appUser = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = appUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Reward Settings',
              onPressed: () => context.push('/reward-settings'),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add Employee'),
            )
          : null,
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (employees) {
          if (employees.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: 'No employees yet',
              subtitle: 'Add your team members to track rewards.',
              action: isAdmin ? () => _showAddDialog(context, ref) : null,
              actionLabel: 'Add Employee',
            );
          }

          final settings =
              settingsAsync.valueOrNull ?? const RewardSettings();
          final orders = ordersAsync.valueOrNull ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(employeesStreamProvider);
              ref.invalidate(ordersStreamProvider);
              ref.invalidate(rewardSettingsProvider);
              await Future.delayed(const Duration(milliseconds: 600));
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: employees.length,
              itemBuilder: (context, i) {
                final emp = employees[i];
                final stats =
                    _employeeStats(orders, emp.uid, settings.benefitPeriod);
                final displayCount =
                    emp.uid != null ? stats.count : emp.confirmedOrders;
                return EmployeeCard(
                  employee: emp,
                  rewardPercent: emp.benefitPercentage,
                  rewardAmount: emp.rewardAmount(stats.total),
                  ordersCount: displayCount,
                  amountOwed: emp.amountOwed,
                  onTap: () => context.push('/employees/${emp.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _AddEmployeeDialog(ref: ref),
    );
  }
}

class _AddEmployeeDialog extends ConsumerStatefulWidget {
  const _AddEmployeeDialog({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_AddEmployeeDialog> createState() =>
      _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends ConsumerState<_AddEmployeeDialog> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _createAccount = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    if (_createAccount) {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      if (email.isEmpty || !email.contains('@')) {
        setState(() => _error = 'Enter a valid email address.');
        return;
      }
      if (password.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final employeeId = const Uuid().v4();
      String? uid;

      if (_createAccount) {
        uid = await ref.read(authServiceProvider).createEmployeeAccount(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
              name: name,
              employeeId: employeeId,
            );
      }

      final emp = Employee(
        id: employeeId,
        name: name,
        role: _roleCtrl.text.trim().isEmpty ? null : _roleCtrl.text.trim(),
        phone:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email:
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        uid: uid,
        createdAt: DateTime.now(),
      );

      await ref.read(employeesServiceProvider).createEmployee(emp);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Employee'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _roleCtrl,
              decoration:
                  const InputDecoration(labelText: 'Job Title (optional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              decoration:
                  const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Create Login Account'),
              subtitle: const Text('Employee can sign in to the app'),
              value: _createAccount,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() {
                _createAccount = v;
                _error = null;
              }),
            ),
            if (_createAccount) ...[
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            minimumSize: Size.zero,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
