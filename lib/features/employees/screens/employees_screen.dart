import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../features/auth/models/app_permission.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../orders/models/order.dart';
import '../../orders/providers/orders_provider.dart';
import '../models/employee.dart';
import '../providers/employees_provider.dart';
import '../widgets/employee_card.dart';

/// Returns confirmed-order count and net-income sum for [employeeId] within [period].
({int count, double total}) _employeeStats(
    List<Order> orders, String employeeId, String period) {
  final now = DateTime.now();
  final matched = orders.where((o) {
    if (!o.paymentConfirmed || o.creatorId != employeeId) return false;
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

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key, this.embedded = false});

  /// True when shown as a tab inside the Directory screen — suppresses this
  /// screen's own app bar so it isn't stacked under Directory's.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final settingsAsync = ref.watch(rewardSettingsProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final appUser = ref.watch(currentUserProvider).valueOrNull;
    final canManage =
        appUser?.hasPermission(AppPermission.manageEmployees) ?? false;

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Employees'),
              actions: [
                if (canManage)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Reward Settings',
                    onPressed: () => context.push('/reward-settings'),
                  ),
              ],
            ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (employees) {
          if (employees.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No employees yet',
              subtitle: 'Employees appear here once they sign up from the '
                  'login screen.',
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
                    _employeeStats(orders, emp.id, settings.benefitPeriod);
                return EmployeeCard(
                  employee: emp,
                  rewardPercent: emp.benefitPercentage,
                  rewardAmount: emp.rewardAmount(stats.total),
                  ordersCount: stats.count,
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
}
