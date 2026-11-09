import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/inventaire.dart';
import '../providers/inventaire_provider.dart';
import '../widgets/period_end_picker.dart';

class InventaireHomeScreen extends ConsumerWidget {
  const InventaireHomeScreen({super.key});

  static final _dateFmt = DateFormat('dd MMM yyyy');

  Future<void> _startSession(
    BuildContext context,
    WidgetRef ref,
    DateTime? earliestAllowed,
  ) async {
    final periodEnd = await pickInventairePeriodEnd(
      context,
      initialDate: DateTime.now(),
      firstDate: earliestAllowed,
    );
    if (periodEnd == null) return;

    final uid = ref.read(currentUserProvider).valueOrNull?.uid;
    final service = ref.read(inventaireServiceProvider);
    final inventaire = await service.startSession(uid, periodEnd: periodEnd);
    if (context.mounted) {
      context.push('/inventaire/${inventaire.id}/resolve');
    }
  }

  Future<void> _editDraftPeriodEnd(
    BuildContext context,
    WidgetRef ref,
    Inventaire draft,
  ) async {
    final periodEnd = await pickInventairePeriodEnd(
      context,
      initialDate: draft.periodEnd,
      firstDate: draft.periodStart,
    );
    if (periodEnd == null) return;
    await ref.read(inventaireServiceProvider).updatePeriodEnd(
          draft.id,
          periodEnd,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(inventaireDraftStreamProvider);
    final historyAsync = ref.watch(inventaireHistoryStreamProvider);

    // The new session's periodStart will be the latest finalized session's
    // periodEnd (same lookup InventaireService.startSession does server
    // side); used here only to bound the date picker.
    final finalizedByRecency = [...(historyAsync.valueOrNull ?? [])]
      ..sort((a, b) =>
          (b.finalizedAt ?? b.createdAt).compareTo(a.finalizedAt ?? a.createdAt));
    final earliestAllowed =
        finalizedByRecency.isNotEmpty ? finalizedByRecency.first.periodEnd : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventaire')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          draftAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (draft) => draft == null
                ? _StartCard(
                    onStart: () =>
                        _startSession(context, ref, earliestAllowed))
                : _ResumeCard(
                    draft: draft,
                    dateFmt: _dateFmt,
                    onContinue: () =>
                        context.push('/inventaire/${draft.id}/resolve'),
                    onEditPeriodEnd: () =>
                        _editDraftPeriodEnd(context, ref, draft),
                  ),
          ),
          const SizedBox(height: 24),
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (history) => history.isEmpty
                ? const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No Inventaire yet',
                    subtitle: 'Finalized sessions will appear here.',
                  )
                : Column(
                    children: history
                        .map((inv) => _HistoryTile(
                              inventaire: inv,
                              dateFmt: _dateFmt,
                              onTap: () =>
                                  context.push('/inventaire/${inv.id}'),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.fact_check_outlined,
              size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'Start a new stock-take',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Resolves open orders & purchases, then records a physical '
            'stock count and archives the period.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start New Inventaire'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.draft,
    required this.dateFmt,
    required this.onContinue,
    required this.onEditPeriodEnd,
  });
  final Inventaire draft;
  final DateFormat dateFmt;
  final VoidCallback onContinue;
  final VoidCallback onEditPeriodEnd;

  @override
  Widget build(BuildContext context) {
    final from = draft.periodStart != null
        ? dateFmt.format(draft.periodStart!)
        : 'Depuis le début';
    final to = dateFmt.format(draft.periodEnd);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pending_actions, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'Inventaire in progress',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('$from → $to',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              TextButton.icon(
                onPressed: onEditPeriodEnd,
                icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                label: const Text('Edit end date'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.inventaire,
    required this.dateFmt,
    required this.onTap,
  });

  final Inventaire inventaire;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final from = inventaire.periodStart != null
        ? dateFmt.format(inventaire.periodStart!)
        : 'Depuis le début';
    final to = dateFmt.format(inventaire.periodEnd);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$from → $to',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${inventaire.totalStockValuation.toStringAsFixed(2)} DA valuation',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
