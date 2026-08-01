import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../models/transaction.dart';
import '../providers/income_provider.dart';
import '../widgets/transaction_tile.dart';

class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  String _period = 'month'; // today, week, month, all

  Future<void> _refresh() async {
    ref.invalidate(transactionsStreamProvider);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  DateTime get _from {
    final now = DateTime.now();
    return switch (_period) {
      'today' => DateTime(now.year, now.month, now.day),
      'week'  => now.subtract(const Duration(days: 7)),
      'month' => DateTime(now.year, now.month, 1),
      _       => DateTime(2000),
    };
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Income & Benefits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/income/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          _PeriodTabs(
            selected: _period,
            onSelected: (p) => setState(() => _period = p),
          ),
          Expanded(
            child: txAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (transactions) {
                final filtered = transactions
                    .where((t) => t.date.isAfter(_from))
                    .toList();

                final totalIncome = filtered
                    .where((t) => t.type == TransactionType.income)
                    .fold<double>(0, (s, t) => s + t.amount);
                final totalExpense = filtered
                    .where((t) => t.type == TransactionType.expense)
                    .fold<double>(0, (s, t) => s + t.amount);
                final netProfit = totalIncome - totalExpense;

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'Revenue',
                            value:
                                'DZD ${totalIncome.toStringAsFixed(2)}',
                            color: AppColors.success,
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Expenses',
                            value:
                                'DZD ${totalExpense.toStringAsFixed(2)}',
                            color: AppColors.error,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SummaryCard(
                      label: 'Net Profit',
                      value: 'DZD ${netProfit.toStringAsFixed(2)}',
                      color: netProfit >= 0
                          ? AppColors.primary
                          : AppColors.error,
                      icon: Icons.account_balance_outlined,
                      isWide: true,
                    ),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'Transactions',
                      action: () => context.push('/income/new'),
                      actionLabel: 'Add',
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions',
                        subtitle:
                            'Record your first income or expense.',
                      )
                    else
                      ...filtered.map(
                        (t) => TransactionTile(
                          transaction: t,
                          onDelete: () => ref
                              .read(incomeServiceProvider)
                              .deleteTransaction(t.id),
                        ),
                      ),
                  ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Period tab bar ──────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  static const _tabs = [
    ('Today', 'today'),
    ('This Week', 'week'),
    ('This Month', 'month'),
    ('All Time', 'all'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          for (final tab in _tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabButton(
                label: tab.$1,
                isSelected: selected == tab.$2,
                onPressed: () => onSelected(tab.$2),
              ),
            ),
        ],
      ),
    );
  }
}

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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : Border.all(
                    color: AppColors.cardBorder, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Summary card ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isWide = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: isWide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(label,
                        style:
                            Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: color),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 4),
                    Text(label,
                        style:
                            Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: color, fontSize: 20),
                ),
              ],
            ),
    );
  }
}
