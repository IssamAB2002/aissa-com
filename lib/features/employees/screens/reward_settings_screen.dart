import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../orders/models/order.dart';
import '../../orders/providers/orders_provider.dart';
import '../models/employee.dart';
import '../providers/employees_provider.dart';

// ─── Calculation helpers ─────────────────────────────────────────────────────

double _calcTotalOrderAmount(List<Order> orders, String period) {
  final now = DateTime.now();
  return orders.where((o) {
    if (!o.paymentConfirmed) return false;
    final d = o.createdAt;
    return _inPeriod(d, now, period);
  }).fold<double>(0.0, (s, o) => s + o.rewardBasis);
}

({int count, double total}) _employeeStats(
    List<Order> orders, String? uid, String period) {
  if (uid == null) return (count: 0, total: 0.0);
  final now = DateTime.now();
  final matched = orders
      .where((o) =>
          o.paymentConfirmed &&
          o.creatorId == uid &&
          _inPeriod(o.createdAt, now, period))
      .toList();
  return (
    count: matched.length,
    total: matched.fold(0.0, (s, o) => s + o.rewardBasis),
  );
}

bool _inPeriod(DateTime d, DateTime now, String period) {
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
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class RewardSettingsScreen extends ConsumerStatefulWidget {
  const RewardSettingsScreen({super.key});

  @override
  ConsumerState<RewardSettingsScreen> createState() =>
      _RewardSettingsScreenState();
}

class _RewardSettingsScreenState extends ConsumerState<RewardSettingsScreen> {
  String _period = 'monthly';
  bool _loaded = false;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<RewardSettings>>(rewardSettingsProvider, (_, next) {
      next.whenData((s) {
        if (!_loaded) {
          _loaded = true;
          setState(() => _period = s.benefitPeriod);
        }
      });
    });

    final employeesAsync = ref.watch(employeesStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final orders = ordersAsync.valueOrNull ?? [];
    final employees = employeesAsync.valueOrNull ?? [];

    final selectedEmp =
        _selectedId == null ? null : employees.where((e) => e.id == _selectedId).firstOrNull;
    final selStats =
        selectedEmp != null ? _employeeStats(orders, selectedEmp.uid, _period) : null;
    final totalRevenue = _calcTotalOrderAmount(orders, _period);

    return Scaffold(
      appBar: AppBar(title: const Text('Reward Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period selector
          Text('Benefit Period',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final e in const [
                ('daily', 'Daily'),
                ('weekly', 'Weekly'),
                ('monthly', 'Monthly'),
              ]) ...[
                _TabButton(
                  label: e.$2,
                  isSelected: _period == e.$1,
                  onPressed: () async {
                    setState(() => _period = e.$1);
                    await ref
                        .read(employeesServiceProvider)
                        .saveSettings(RewardSettings(benefitPeriod: e.$1));
                  },
                ),
                if (e.$1 != 'monthly') const SizedBox(width: 8),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Stats panel — global or selected employee
          if (selectedEmp != null && selStats != null)
            _EmployeeStatsCard(
              employee: selectedEmp,
              stats: selStats,
              period: _period,
              amountOwed: selectedEmp.amountOwed,
              onDismiss: () => setState(() => _selectedId = null),
            )
          else
            _GlobalRevenueCard(
              period: _period,
              revenue: totalRevenue,
              isLoading: ordersAsync.isLoading,
            ),

          const SizedBox(height: 6),
          Text(
            selectedEmp == null
                ? 'From all confirmed orders this ${_period == 'daily' ? 'day' : _period == 'weekly' ? 'week' : 'month'}.'
                : 'Tap the × to go back to global view.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),

          // Employee list
          employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (emps) {
              if (emps.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No employees yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                );
              }

              final totalPct =
                  emps.fold<double>(0, (s, e) => s + e.benefitPercentage);
              final isOver = totalPct > 100.05;
              final isDone = (totalPct - 100).abs() < 0.05;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Employee Benefits',
                          style: Theme.of(context).textTheme.titleMedium),
                      _TotalBadge(
                          total: totalPct, isDone: isDone, isOver: isOver),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reward = benefit % × employee\'s net income from confirmed orders (ZR fee deducted only when shipped via ZR).',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ...emps.map((emp) => _EmployeePctTile(
                        key: ValueKey(emp.id),
                        employee: emp,
                        orders: orders,
                        period: _period,
                        isSelected: _selectedId == emp.id,
                        onTap: () => setState(() {
                          _selectedId =
                              _selectedId == emp.id ? null : emp.id;
                        }),
                        onEditPct: () => _showEditDialog(emp),
                      )),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(Employee emp) async {
    if (emp.amountOwed > 0) {
      final proceed = await AppConfirmDialog.show(
        context,
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.warning,
        title: 'Change Benefit %?',
        message:
            '${emp.name} has an unpaid balance of '
            'DZD ${NumberFormat('#,##0.00').format(emp.amountOwed)}.\n\n'
            'Changing the benefit percentage while a balance is owed may '
            'cause confusion and result in unfair reward calculations for '
            'work already done in this period.',
        confirmLabel: 'Proceed Anyway',
        confirmColor: AppColors.warning,
      );
      if (proceed != true || !mounted) return;
    }

    final result = await showDialog<double>(
      context: context,
      builder: (_) => _EditPctDialog(employee: emp),
    );
    if (result != null && mounted) {
      await ref
          .read(employeesServiceProvider)
          .updateBenefitPercentage(emp.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${emp.name}: ${result.toStringAsFixed(1)}% saved'),
        ));
      }
    }
  }
}

// ─── Global revenue card ─────────────────────────────────────────────────────

class _GlobalRevenueCard extends StatelessWidget {
  const _GlobalRevenueCard({
    required this.period,
    required this.revenue,
    required this.isLoading,
  });
  final String period;
  final double revenue;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${period[0].toUpperCase()}${period.substring(1)} Total Net Income',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        'DZD ${NumberFormat('#,##0.00').format(revenue)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
              ],
            ),
          ),
          Text(
            'Tap an employee\nto view stats',
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Selected employee stats card ────────────────────────────────────────────

class _EmployeeStatsCard extends StatelessWidget {
  const _EmployeeStatsCard({
    required this.employee,
    required this.stats,
    required this.period,
    required this.amountOwed,
    required this.onDismiss,
  });
  final Employee employee;
  final ({int count, double total}) stats;
  final String period;
  final double amountOwed;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final reward = employee.rewardAmount(stats.total);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    employee.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    if (employee.role != null)
                      Text(employee.role!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      size: 15, color: AppColors.primary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Stat chips
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.receipt_long_outlined,
                  label: 'Orders',
                  value: '${stats.count}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.payments_outlined,
                  label: 'Net Income',
                  value:
                      'DZD ${NumberFormat('#,##0').format(stats.total)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.card_giftcard_outlined,
                  label: 'Reward',
                  value:
                      'DZD ${NumberFormat('#,##0').format(reward)}',
                  highlight: true,
                ),
              ),
            ],
          ),

          // Amount owed row
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: amountOwed > 0
                  ? AppColors.warning.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: amountOwed > 0
                    ? AppColors.warning.withValues(alpha: 0.35)
                    : AppColors.cardBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                      color: amountOwed > 0
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Amount Owed',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
                Text(
                  'DZD ${NumberFormat('#,##0.00').format(amountOwed)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: amountOwed > 0
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini stat chip ───────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Employee tile (no expand, has edit pen) ──────────────────────────────────

class _EmployeePctTile extends StatelessWidget {
  const _EmployeePctTile({
    super.key,
    required this.employee,
    required this.orders,
    required this.period,
    required this.isSelected,
    required this.onTap,
    required this.onEditPct,
  });
  final Employee employee;
  final List<Order> orders;
  final String period;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEditPct;

  @override
  Widget build(BuildContext context) {
    final stats = _employeeStats(orders, employee.uid, period);
    final displayCount =
        employee.uid != null ? stats.count : employee.confirmedOrders;
    final amount = employee.rewardAmount(stats.total);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.cardBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    employee.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (employee.role != null) ...[
                          Text(employee.role!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const Text('  ·  ',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                        const Icon(Icons.receipt_long_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('$displayCount orders',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),

              // Benefit % + reward
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${employee.benefitPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.primary),
                  ),
                  Text(
                    'DZD ${NumberFormat('#,##0').format(amount)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),

              const SizedBox(width: 10),

              // Edit pen
              GestureDetector(
                onTap: onEditPct,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_outlined,
                      size: 17, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Edit % dialog ────────────────────────────────────────────────────────────

class _EditPctDialog extends StatefulWidget {
  const _EditPctDialog({required this.employee});
  final Employee employee;

  @override
  State<_EditPctDialog> createState() => _EditPctDialogState();
}

class _EditPctDialogState extends State<_EditPctDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.employee.benefitPercentage.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pct = double.tryParse(_ctrl.text.trim());
    if (pct != null) Navigator.pop(context, pct);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.employee.name[0].toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.employee.name,
                style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'BENEFIT PERCENTAGE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0.0',
                suffixText: '%',
                suffixStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.7)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Period tab button ────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : Border.all(color: AppColors.cardBorder, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Total % badge ────────────────────────────────────────────────────────────

class _TotalBadge extends StatelessWidget {
  const _TotalBadge(
      {required this.total, required this.isDone, required this.isOver});
  final double total;
  final bool isDone;
  final bool isOver;

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? AppColors.success
        : isOver
            ? AppColors.error
            : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Total: ${total.toStringAsFixed(1)}%',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
