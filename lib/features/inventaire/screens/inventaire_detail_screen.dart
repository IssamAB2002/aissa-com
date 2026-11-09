import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stat_card.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../income/providers/income_provider.dart';
import '../models/inventaire.dart';
import '../providers/inventaire_provider.dart';
import '../widgets/financial_export_option_dialog.dart';
import '../widgets/inventaire_financial_section.dart';

class InventaireDetailScreen extends ConsumerStatefulWidget {
  const InventaireDetailScreen({super.key, required this.inventaireId});

  final String inventaireId;

  @override
  ConsumerState<InventaireDetailScreen> createState() =>
      _InventaireDetailScreenState();
}

class _InventaireDetailScreenState
    extends ConsumerState<InventaireDetailScreen> {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  bool _exporting = false;

  Future<void> _export(Inventaire inventaire) async {
    final option = await showFinancialExportOptionDialog(context);
    if (option == null) return;

    setState(() => _exporting = true);
    try {
      final stockLines =
          await ref.read(inventaireStockLinesProvider(widget.inventaireId).future);
      final resolvedOrders = await ref
          .read(inventaireResolvedOrdersProvider(widget.inventaireId).future);
      final resolvedPurchases = await ref.read(
          inventaireResolvedPurchasesProvider(widget.inventaireId).future);
      final resolvedOrderPayments = await ref.read(
          inventaireResolvedOrderPaymentsProvider(widget.inventaireId)
              .future);
      final resolvedPurchasePayments = await ref.read(
          inventaireResolvedPurchasePaymentsProvider(widget.inventaireId)
              .future);

      PeriodSummary? totalSummary;
      var daily = const <PeriodSummary>[];
      var weekly = const <PeriodSummary>[];
      var monthly = const <PeriodSummary>[];
      if (option != FinancialExportOption.none) {
        final transactions = await ref.read(transactionsStreamProvider.future);
        final data = AnalyticsData(transactions);
        final rangeStart = inventaireRangeStart(inventaire, transactions);
        totalSummary = data.totalSummary(
            rangeStart, inventaireTotalRangeEnd(inventaire));
        if (option == FinancialExportOption.daily ||
            option == FinancialExportOption.all) {
          daily = data.dailyInRange(rangeStart, inventaire.periodEnd);
        }
        if (option == FinancialExportOption.weekly ||
            option == FinancialExportOption.all) {
          weekly = data.weeklyInRange(rangeStart, inventaire.periodEnd);
        }
        if (option == FinancialExportOption.monthly ||
            option == FinancialExportOption.all) {
          monthly = data.monthlyInRange(rangeStart, inventaire.periodEnd);
        }
      }

      await ref.read(inventaireExportServiceProvider).exportAndShare(
            inventaire: inventaire,
            stockLines: stockLines,
            resolvedOrders: resolvedOrders,
            resolvedPurchases: resolvedPurchases,
            resolvedOrderPayments: resolvedOrderPayments,
            resolvedPurchasePayments: resolvedPurchasePayments,
            financialOption: option,
            totalSummary: totalSummary,
            dailySummaries: daily,
            weeklySummaries: weekly,
            monthlySummaries: monthly,
          );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventaireAsync =
        ref.watch(inventaireByIdProvider(widget.inventaireId));

    return Scaffold(
      appBar: AppBar(title: const Text('Inventaire')),
      body: inventaireAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (inventaire) {
          if (inventaire == null) {
            return const Center(child: Text('Not found'));
          }
          final from = inventaire.periodStart != null
              ? _dateFmt.format(inventaire.periodStart!)
              : 'Depuis le début';
          final to = _dateFmt.format(inventaire.periodEnd);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('$from → $to',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Stock Valuation',
                      value:
                          '${inventaire.totalStockValuation.toStringAsFixed(2)} DA',
                      icon: Icons.payments_outlined,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Orders Resolved',
                      value: '${inventaire.totalOrdersResolved}',
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatCard(
                title: 'Purchases Resolved',
                value: '${inventaire.totalPurchasesResolved}',
                icon: Icons.local_shipping_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Order Payments Settled',
                      value: '${inventaire.totalOrderPaymentsSettled}',
                      icon: Icons.price_check_outlined,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Purchase Payments Settled',
                      value: '${inventaire.totalPurchasePaymentsSettled}',
                      icon: Icons.price_check_outlined,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              InventaireFinancialSection(inventaire: inventaire),
              const SizedBox(height: 24),
              if (inventaire.status == InventaireStatus.finalized)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _exporting ? null : () => _export(inventaire),
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.ios_share),
                    label: const Text('Export to Excel'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
