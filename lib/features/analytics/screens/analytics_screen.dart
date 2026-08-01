import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../income/providers/income_provider.dart';
import '../providers/analytics_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTimeRange? _dateFilter;

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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateFilter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: Icon(
              _dateFilter != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
              color: Colors.white,
            ),
            onPressed: _pickDateRange,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Monthly'),
            Tab(text: 'Weekly'),
            Tab(text: 'Daily'),
          ],
        ),
      ),
      body: txAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (transactions) {
          final data = AnalyticsData(transactions);
          return Column(
            children: [
              if (_dateFilter != null)
                _ActiveFilterBanner(
                  dateFilter: _dateFilter!,
                  onClear: () => setState(() => _dateFilter = null),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PeriodList(
                      summaries: _dateFilter == null
                          ? data.monthlyLast12()
                          : data.monthlyInRange(
                              _dateFilter!.start, _dateFilter!.end),
                    ),
                    _PeriodList(
                      summaries: _dateFilter == null
                          ? data.weeklyLast12()
                          : data.weeklyInRange(
                              _dateFilter!.start, _dateFilter!.end),
                    ),
                    _PeriodList(
                      summaries: _dateFilter == null
                          ? data.dailyLast30()
                          : data.dailyInRange(
                              _dateFilter!.start, _dateFilter!.end),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Active filter banner ─────────────────────────────────────────────────────

class _ActiveFilterBanner extends StatelessWidget {
  const _ActiveFilterBanner({
    required this.dateFilter,
    required this.onClear,
  });
  final DateTimeRange dateFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${fmt.format(dateFilter.start)} – ${fmt.format(dateFilter.end)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 18, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─── Period list ──────────────────────────────────────────────────────────────

class _PeriodList extends StatelessWidget {
  const _PeriodList({required this.summaries});
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: summaries.length,
      itemBuilder: (_, i) => _PeriodCard(summary: summaries[i]),
    );
  }
}

// ─── Period card ──────────────────────────────────────────────────────────────

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.summary});
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
              color: hasActivity
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _StatRow(
            label: 'Revenue',
            amount: summary.revenue,
            color: AppColors.success,
            icon: Icons.arrow_upward_rounded,
            muted: !hasActivity,
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: 'Expenses',
            amount: summary.expenses,
            color: AppColors.error,
            icon: Icons.arrow_downward_rounded,
            muted: !hasActivity,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
                height: 1, color: AppColors.cardBorder),
          ),
          _StatRow(
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

class _StatRow extends StatelessWidget {
  const _StatRow({
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
