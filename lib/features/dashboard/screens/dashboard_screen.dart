import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../employees/providers/employees_provider.dart';
import '../../income/providers/income_provider.dart';
import '../../orders/models/order.dart';
import '../../orders/providers/orders_provider.dart';
import '../../orders/widgets/order_card.dart';
import '../../products/models/product.dart';
import '../../products/providers/products_provider.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../../tasks/widgets/task_tile.dart';

double _calcBenefits(List<Order> orders, String period) {
  final now = DateTime.now();
  return orders.where((o) {
    if (!o.paymentConfirmed) return false;
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
  }).fold<double>(0.0, (sum, o) => sum + o.netProfit);
}

double _calcEmployeeBenefits(
    List<Order> orders, String? employeeId, String period) {
  if (employeeId == null) return 0.0;
  final now = DateTime.now();
  return orders.where((o) {
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
  }).fold<double>(0.0, (sum, o) => sum + o.netProfit);
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final employeesAsync = ref.watch(employeesStreamProvider);
    final settingsAsync = ref.watch(rewardSettingsProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = currentUser?.isAdmin ?? false;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aissa Com'),
            Text(
              DateFormat('EEEE, MMM d').format(now),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersStreamProvider);
          ref.invalidate(productsStreamProvider);
          ref.invalidate(tasksStreamProvider);
          ref.invalidate(employeesStreamProvider);
          ref.invalidate(rewardSettingsProvider);
          ref.invalidate(transactionsStreamProvider);
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // --- Summary cards ---
          ordersAsync.when(
            loading: () => const _LoadingCards(),
            error: (_, __) => const SizedBox.shrink(),
            data: (orders) {
              final todaySales = orders
                  .where((o) =>
                      o.createdAt.isAfter(todayStart) &&
                      o.status != OrderStatus.cancelled)
                  .fold<double>(0, (s, o) => s + o.total);
              final pending = orders
                  .where((o) => o.status == OrderStatus.pending)
                  .length;

              return productsAsync.when(
                loading: () => const _LoadingCards(),
                error: (_, __) => const SizedBox.shrink(),
                data: (products) {
                  final lowStock = products
                      .where((p) => p.isLowStock || p.isOutOfStock)
                      .length;

                  // Employees: 3 cards (no Open Tasks)
                  if (!isAdmin) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: "Today's Sales",
                                value: 'DZD ${todaySales.toStringAsFixed(0)}',
                                icon: Icons.attach_money,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatCard(
                                title: 'Pending Orders',
                                value: '$pending',
                                icon: Icons.shopping_bag_outlined,
                                color: AppColors.statusPending,
                                onTap: () => context.go('/orders'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: StatCard(
                            title: 'Low Stock',
                            value: '$lowStock',
                            icon: Icons.warning_amber_outlined,
                            color: AppColors.warning,
                            onTap: () => context.push('/inventory'),
                          ),
                        ),
                      ],
                    );
                  }

                  return tasksAsync.when(
                    loading: () => const _LoadingCards(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (tasks) {
                      final pendingTasks = tasks
                          .where((t) => t.status != TaskStatus.done)
                          .length;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: StatCard(
                                  title: "Today's Sales",
                                  value:
                                      'DZD ${todaySales.toStringAsFixed(0)}',
                                  icon: Icons.attach_money,
                                  color: AppColors.success,
                                  onTap: () => context.push('/income'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: StatCard(
                                  title: 'Pending Orders',
                                  value: '$pending',
                                  icon: Icons.shopping_bag_outlined,
                                  color: AppColors.statusPending,
                                  onTap: () => context.go('/orders'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: StatCard(
                                  title: 'Low Stock',
                                  value: '$lowStock',
                                  icon: Icons.warning_amber_outlined,
                                  color: AppColors.warning,
                                  onTap: () => context.push('/inventory'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: StatCard(
                                  title: 'Open Tasks',
                                  value: '$pendingTasks',
                                  icon: Icons.task_alt_outlined,
                                  color: AppColors.primary,
                                  onTap: () => context.go('/tasks'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          // --- Amount Owed (employee only) ---
          if (!isAdmin) ...[
            const SizedBox(height: 10),
            employeesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (employees) {
                final employeeId = currentUser?.employeeId;
                if (employeeId == null) return const SizedBox.shrink();
                final idx = employees.indexWhere((e) => e.id == employeeId);
                if (idx == -1) return const SizedBox.shrink();
                final emp = employees[idx];
                final amountOwed = emp.amountOwed;
                return SizedBox(
                  width: double.infinity,
                  child: StatCard(
                    title: 'Amount Owed to You',
                    value:
                        'DZD ${NumberFormat('#,##0').format(amountOwed)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.success,
                    subtitle: 'Your accumulated reward balance',
                  ),
                );
              },
            ),
          ],

          // --- Needs Restock (admin only) ---
          if (isAdmin) productsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (products) {
              // Only negative stock, capped at the 5 most recently changed.
              final needsRestock = (products
                      .where((p) => p.stockQuantity < 0)
                      .toList()
                    ..sort((a, b) => (b.stockUpdatedAt ?? b.createdAt)
                        .compareTo(a.stockUpdatedAt ?? a.createdAt)))
                  .take(5)
                  .toList();
              if (needsRestock.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Needs Restock',
                      action: () => context.push('/inventory'),
                      actionLabel: 'Inventory',
                    ),
                    const SizedBox(height: 12),
                    ...needsRestock.map((p) => _RestockProductTile(
                          product: p,
                          onTap: () => context.push('/inventory'),
                        )),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // --- Quick Actions ---
          SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickAction(
                  icon: Icons.add_shopping_cart,
                  label: 'New Order',
                  color: AppColors.primary,
                  onTap: () => context.push('/orders/new'),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.shopping_bag_outlined,
                    label: 'New Purchase',
                    color: AppColors.secondary,
                    onTap: () => context.push('/purchases/new'),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.tune,
                    label: 'Adjust Stock',
                    color: AppColors.warning,
                    onTap: () => context.push('/inventory/adjust'),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.add_task,
                    label: 'New Task',
                    color: AppColors.success,
                    onTap: () => context.push('/tasks/new'),
                  ),
                  const SizedBox(width: 10),
                  _QuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Add Income',
                    color: const Color(0xFF7B1FA2),
                    onTap: () => context.push('/income/new'),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Daily Profits (admin only) ---
          if (isAdmin) transactionsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (transactions) {
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todayEnd = todayStart.add(const Duration(days: 1));
              final todayTransactions = transactions.where((t) =>
                  t.date.isAfter(todayStart) && t.date.isBefore(todayEnd)).toList();
              final todayIncome = todayTransactions
                  .where((t) => t.type.name == 'income')
                  .fold<double>(0, (sum, t) => sum + t.amount);
              final todayExpenses = todayTransactions
                  .where((t) => t.type.name == 'expense')
                  .fold<double>(0, (sum, t) => sum + t.amount);
              final dailyProfit = todayIncome - todayExpenses;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StatCard(
                  title: 'Daily Profits',
                  value: 'DZD ${NumberFormat('#,##0').format(dailyProfit)}',
                  icon: Icons.trending_up_outlined,
                  color: AppColors.success,
                  onTap: () => context.push('/income'),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // --- Recent Orders ---
          ordersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (orders) {
              if (orders.isEmpty) return const SizedBox.shrink();
              final recent = orders.take(3).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Recent Orders',
                    action: () => context.go('/orders'),
                    actionLabel: 'See all',
                  ),
                  const SizedBox(height: 12),
                  ...recent.map(
                    (o) => OrderCard(
                      order: o,
                      onTap: () => context.push('/orders/${o.id}'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),

          // --- Top Products Sold ---
          ordersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (orders) {
              final Map<String, int> unitsSold = {};
              for (final order in orders) {
                if (order.status == OrderStatus.cancelled) continue;
                for (final item in order.items) {
                  unitsSold[item.productName] =
                      (unitsSold[item.productName] ?? 0) + item.quantity;
                }
              }
              if (unitsSold.isEmpty) return const SizedBox.shrink();
              final top = unitsSold.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final top2 = top.take(2).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Top Products Sold',
                    action: () => context.go('/products'),
                    actionLabel: 'All products',
                  ),
                  const SizedBox(height: 12),
                  ...top2.asMap().entries.map(
                        (e) => _ProductRankTile(
                          rank: e.key + 1,
                          name: e.value.key,
                          unitsSold: e.value.value,
                        ),
                      ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),

          // --- Top Employee Rewards (admin only) ---
          if (isAdmin) employeesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (employees) => settingsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (settings) {
                if (employees.isEmpty) return const SizedBox.shrink();
                final hasData =
                    employees.any((e) => e.benefitPercentage > 0);
                if (!hasData) return const SizedBox.shrink();
                
                // Calculate rewards for each employee
                final employeeRewards = employees.map((emp) {
                  final benefits = _calcEmployeeBenefits(
                      ordersAsync.valueOrNull ?? [],
                      emp.uid,
                      settings.benefitPeriod);
                  return (
                    employee: emp,
                    amount: emp.rewardAmount(benefits),
                  );
                }).toList();

                // Sort by actual reward amount (descending)
                final ranked = employeeRewards
                  ..sort((a, b) => b.amount.compareTo(a.amount));
                final top2 = ranked.take(2).toList();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Top Employee Rewards',
                      action: () => context.push('/employees'),
                      actionLabel: 'All employees',
                    ),
                    const SizedBox(height: 12),
                    ...top2.asMap().entries.map((e) {
                      final pct = e.value.employee.benefitPercentage / 100;
                      return _EmployeeRewardTile(
                        rank: e.key + 1,
                        name: e.value.employee.name,
                        role: e.value.employee.role,
                        percent: pct,
                        amount: e.value.amount,
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),

          // --- Open Tasks (admin only) ---
          if (isAdmin) tasksAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (tasks) {
              final open = tasks
                  .where((t) => t.status != TaskStatus.done)
                  .take(3)
                  .toList();
              if (open.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Open Tasks',
                    action: () => context.go('/tasks'),
                    actionLabel: 'See all',
                  ),
                  const SizedBox(height: 12),
                  ...open.map(
                    (t) => TaskTile(
                      task: t,
                      isAdmin: true,
                      onStatusToggle: () {
                        final next = t.status == TaskStatus.todo
                            ? TaskStatus.inProgress
                            : TaskStatus.done;
                        ref
                            .read(tasksServiceProvider)
                            .updateStatus(t.id, next);
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 100,
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRankTile extends StatelessWidget {
  const _ProductRankTile({
    required this.rank,
    required this.name,
    required this.unitsSold,
  });
  final int rank;
  final String name;
  final int unitsSold;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isFirst
                  ? Colors.amber.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isFirst
                      ? Colors.amber.shade700
                      : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '$unitsSold units',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestockProductTile extends StatelessWidget {
  const _RestockProductTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNegative = product.stockQuantity < 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNegative
                ? AppColors.error.withValues(alpha: 0.3)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isNegative
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNegative
                    ? Icons.trending_down
                    : Icons.inventory_2_outlined,
                size: 18,
                color: isNegative ? AppColors.error : AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  if (product.category != null)
                    Text(
                      product.category!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isNegative
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${product.stockQuantity}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isNegative ? AppColors.error : AppColors.warning,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmployeeRewardTile extends StatelessWidget {
  const _EmployeeRewardTile({
    required this.rank,
    required this.name,
    this.role,
    required this.percent,
    required this.amount,
  });
  final int rank;
  final String name;
  final String? role;
  final double percent;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isFirst
                  ? Colors.amber.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 18,
              color:
                  isFirst ? Colors.amber.shade700 : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (role != null)
                  Text(
                    role!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'DZD ${NumberFormat('#,##0').format(amount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.success),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(1)}% of benefits',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
