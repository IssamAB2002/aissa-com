import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../income/models/transaction.dart';
import '../../income/providers/income_provider.dart';
import '../../orders/models/order.dart';
import '../../orders/providers/orders_provider.dart';
import '../models/employee.dart';
import '../providers/employees_provider.dart';

/// Returns confirmed-order count and revenue total for [uid] within [period].
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
    total: matched.fold(0.0, (s, o) => s + o.rewardBasis),
  );
}

class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({super.key, required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final settingsAsync = ref.watch(rewardSettingsProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);

    return employeesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (employees) {
        final idx = employees.indexWhere((e) => e.id == employeeId);
        if (idx == -1) {
          return const Scaffold(
              body: Center(child: Text('Employee not found')));
        }
        final employee = employees[idx];
        final settings =
            settingsAsync.valueOrNull ?? const RewardSettings();
        final allOrders = ordersAsync.valueOrNull ?? [];
        final stats =
            _employeeStats(allOrders, employee.uid, settings.benefitPeriod);
        final displayCount =
            employee.uid != null ? stats.count : employee.confirmedOrders;
        final rewardAmount = employee.rewardAmount(stats.total);
        final amountOwed = employee.amountOwed;
        final salaryPayments = ref.watch(salaryPaymentsProvider(employee.id));

        // All-time confirmed orders for this employee (list view)
        final confirmedOrders = employee.uid != null
            ? allOrders
                .where((o) =>
                    o.creatorId == employee.uid && o.paymentConfirmed)
                .toList()
            : <Order>[];

        return Scaffold(
          appBar: AppBar(
            title: Text(employee.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await AppConfirmDialog.show(
                    context,
                    icon: Icons.delete_outline,
                    iconColor: AppColors.error,
                    title: 'Remove Employee',
                    message: 'This action cannot be undone.',
                    confirmLabel: 'Remove',
                  );
                  if (ok == true && context.mounted) {
                    await ref
                        .read(employeesServiceProvider)
                        .deleteEmployee(employeeId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile card
              _Card(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          employee.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(employee.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (employee.role != null)
                      Text(employee.role!,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                    if (employee.phone != null)
                      Text(employee.phone!,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Reward card
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reward Share',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Based on net income of ${settings.benefitPeriod} confirmed orders.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                      children: [
                        _RewardStat(
                          label: 'Benefit %',
                          value:
                              '${employee.benefitPercentage.toStringAsFixed(1)}%',
                          color: AppColors.primary,
                        ),
                        _RewardStat(
                          label: 'Reward',
                          value: 'DZD ${rewardAmount.toStringAsFixed(0)}',
                          color: AppColors.success,
                        ),
                        _RewardStat(
                          label: 'Net Income',
                          value: 'DZD ${stats.total.toStringAsFixed(0)}',
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: employee.benefitPercentage / 100,
                        minHeight: 8,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Amount Owed card (only when > 0)
              if (amountOwed > 0) ...[
                _Card(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Amount Owed',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'DZD ${NumberFormat('#,##0.00').format(amountOwed)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Confirmed Orders summary card
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Confirmed Orders',
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$displayCount this ${settings.benefitPeriod == 'daily' ? 'day' : settings.benefitPeriod == 'weekly' ? 'week' : 'month'}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.uid != null
                          ? 'Auto-tracked from orders created by this employee.'
                          : 'No app account — orders cannot be auto-tracked.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Confirmed Orders list (all-time)
              if (confirmedOrders.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order History',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          Text(
                            '${confirmedOrders.length} total',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      ...confirmedOrders.take(10).map(
                            (o) => _OrderRow(order: o),
                          ),
                      if (confirmedOrders.length > 10) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '+ ${confirmedOrders.length - 10} more orders',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Salary History
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Salary History',
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        if (salaryPayments.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'DZD ${NumberFormat('#,##0').format(salaryPayments.fold(0.0, (s, t) => s + t.amount))} total',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success),
                            ),
                          ),
                      ],
                    ),
                    if (salaryPayments.isEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'No salary payments recorded yet.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      ...salaryPayments.map(
                        (t) => _SalaryRow(transaction: t),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  DateFormat('MMM d, y').format(order.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            'DZD ${order.rewardBasis.toStringAsFixed(0)}',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _SalaryRow extends StatelessWidget {
  const _SalaryRow({required this.transaction});
  final AppTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_outlined,
                size: 16, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? 'Salary payment',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  DateFormat('MMM d, y').format(transaction.date),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            'DZD ${NumberFormat('#,##0').format(transaction.amount)}',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

class _RewardStat extends StatelessWidget {
  const _RewardStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: color, fontSize: 20)),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}
