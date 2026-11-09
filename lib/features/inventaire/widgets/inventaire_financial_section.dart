import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stat_card.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../income/models/transaction.dart';
import '../../income/providers/income_provider.dart';
import '../models/inventaire.dart';

/// Resolves the start of an Inventaire session's financial period: the
/// session's own `periodStart`, or — for the very first session ever run,
/// where `periodStart` is null — the earliest known transaction date, so
/// bucketing doesn't have to walk from an arbitrary epoch.
DateTime inventaireRangeStart(
  Inventaire inventaire,
  List<AppTransaction> transactions,
) {
  if (inventaire.periodStart != null) return inventaire.periodStart!;
  if (transactions.isEmpty) return inventaire.periodEnd;
  return transactions
      .map((t) => t.date)
      .reduce((a, b) => a.isBefore(b) ? a : b);
}

/// `dailyInRange`/`weeklyInRange`/`monthlyInRange` always include the whole
/// calendar day/week/month containing `periodEnd`, regardless of its
/// time-of-day (relevant since a draft session's `periodEnd` is the exact
/// moment the session was started). An unbucketed total must use the same
/// end-of-day boundary, or it silently excludes same-day transactions dated
/// after that moment that the bucketed tabs already include.
DateTime inventaireTotalRangeEnd(Inventaire inventaire) {
  final end = inventaire.periodEnd;
  return DateTime(end.year, end.month, end.day + 1);
}

/// Mirrors the Analytics feature's Income/Expenses/Net Profit breakdown,
/// scoped to a single Inventaire session's period instead of "last N" or a
/// free-pick date range.
class InventaireFinancialSection extends ConsumerStatefulWidget {
  const InventaireFinancialSection({super.key, required this.inventaire});

  final Inventaire inventaire;

  @override
  ConsumerState<InventaireFinancialSection> createState() =>
      _InventaireFinancialSectionState();
}

class _InventaireFinancialSectionState
    extends ConsumerState<InventaireFinancialSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsStreamProvider);

    return txAsync.when(
      loading: () =>
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )),
      error: (e, _) => Text('Error loading transactions: $e'),
      data: (transactions) {
        final data = AnalyticsData(transactions);
        final rangeStart =
            inventaireRangeStart(widget.inventaire, transactions);
        final total = data.totalSummary(
            rangeStart, inventaireTotalRangeEnd(widget.inventaire));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Financial Situation',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Income',
                    value: '${total.revenue.toStringAsFixed(2)} DA',
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Total Expenses',
                    value: '${total.expenses.toStringAsFixed(2)} DA',
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StatCard(
              title: 'Net Profit',
              value: '${total.netProfit.toStringAsFixed(2)} DA',
              icon: total.netProfit >= 0
                  ? Icons.check_circle_outline
                  : Icons.remove_circle_outline,
              color: total.netProfit >= 0 ? AppColors.success : AppColors.error,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Monthly'),
                  Tab(text: 'Weekly'),
                  Tab(text: 'Daily'),
                ],
              ),
            ),
            SizedBox(
              height: 420,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FinancialPeriodList(
                    summaries:
                        data.monthlyInRange(rangeStart, widget.inventaire.periodEnd),
                  ),
                  _FinancialPeriodList(
                    summaries:
                        data.weeklyInRange(rangeStart, widget.inventaire.periodEnd),
                  ),
                  _FinancialPeriodList(
                    summaries:
                        data.dailyInRange(rangeStart, widget.inventaire.periodEnd),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Period list ──────────────────────────────────────────────────────────────

class _FinancialPeriodList extends StatelessWidget {
  const _FinancialPeriodList({required this.summaries});
  final List<PeriodSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const Center(
        child: Text(
          'No data for this period',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      itemCount: summaries.length,
      itemBuilder: (_, i) => _FinancialPeriodCard(summary: summaries[i]),
    );
  }
}

// ─── Period card ──────────────────────────────────────────────────────────────

class _FinancialPeriodCard extends StatelessWidget {
  const _FinancialPeriodCard({required this.summary});
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasActivity = summary.revenue > 0 || summary.expenses > 0;
    final isProfit = summary.netProfit >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasActivity ? AppColors.cardBorder : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color:
                  hasActivity ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _FinancialStatRow(
            label: 'Income',
            amount: summary.revenue,
            color: AppColors.success,
            icon: Icons.arrow_upward_rounded,
            muted: !hasActivity,
          ),
          const SizedBox(height: 8),
          _FinancialStatRow(
            label: 'Expenses',
            amount: summary.expenses,
            color: AppColors.error,
            icon: Icons.arrow_downward_rounded,
            muted: !hasActivity,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.cardBorder),
          ),
          _FinancialStatRow(
            label: 'Net Profit',
            amount: summary.netProfit,
            color: hasActivity
                ? (isProfit ? AppColors.success : AppColors.error)
                : AppColors.textHint,
            icon: hasActivity
                ? (isProfit
                    ? Icons.check_circle_outline
                    : Icons.remove_circle_outline)
                : Icons.circle_outlined,
            bold: true,
            muted: !hasActivity,
            showSign: true,
          ),
        ],
      ),
    );
  }
}

// ─── Stat row ─────────────────────────────────────────────────────────────────

class _FinancialStatRow extends StatelessWidget {
  const _FinancialStatRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.bold = false,
    this.muted = false,
    this.showSign = false,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool bold;
  final bool muted;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = muted ? AppColors.textHint : color;
    final sign = showSign && amount > 0 ? '+' : '';
    return Row(
      children: [
        Icon(icon, size: 14, color: effectiveColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: muted
                  ? AppColors.textHint
                  : (bold ? AppColors.textPrimary : AppColors.textSecondary),
            ),
          ),
        ),
        Text(
          '$sign DZD ${NumberFormat('#,##0.00').format(amount.abs())}',
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
