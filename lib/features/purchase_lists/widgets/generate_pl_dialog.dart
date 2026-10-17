import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../purchases/models/purchase.dart';
import '../models/purchase_list.dart';
import '../providers/purchase_lists_provider.dart';

/// Lets the admin pick a date range (or "All"), previews how many pending,
/// not-yet-listed purchases fall in it, then generates the [PurchaseList]
/// on confirm. Returns the created list, or null if cancelled.
class GeneratePlDialog extends ConsumerStatefulWidget {
  const GeneratePlDialog({super.key, required this.eligiblePurchases});

  final List<Purchase> eligiblePurchases;

  static Future<PurchaseList?> show(
    BuildContext context, {
    required List<Purchase> eligiblePurchases,
  }) {
    return showDialog<PurchaseList>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) =>
          GeneratePlDialog(eligiblePurchases: eligiblePurchases),
    );
  }

  @override
  ConsumerState<GeneratePlDialog> createState() => _GeneratePlDialogState();
}

class _GeneratePlDialogState extends ConsumerState<GeneratePlDialog> {
  String _rangeFilter = 'all';
  DateTimeRange? _customRange;
  bool _generating = false;

  DateTimeRange? get _activeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_rangeFilter) {
      case 'today':
        return DateTimeRange(
            start: today, end: today.add(const Duration(days: 1)));
      case 'week':
        final ws = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: ws, end: ws.add(const Duration(days: 7)));
      case 'month':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case 'custom':
        return _customRange;
      default:
        return null;
    }
  }

  List<Purchase> get _matching {
    final range = _activeRange;
    if (range == null) return widget.eligiblePurchases;
    return widget.eligiblePurchases
        .where((p) =>
            !p.createdAt.isBefore(range.start) &&
            p.createdAt.isBefore(range.end))
        .toList();
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange,
    );
    if (range != null && mounted) {
      setState(() {
        _rangeFilter = 'custom';
        _customRange = DateTimeRange(
          start: range.start,
          end: range.end.add(const Duration(days: 1)),
        );
      });
    }
  }

  Future<void> _generate() async {
    final matching = _matching;
    if (matching.isEmpty) return;
    setState(() => _generating = true);
    try {
      final range = _activeRange;
      final list = await ref.read(purchaseListsServiceProvider).generate(
            purchases: matching,
            rangeStart: range?.start,
            rangeEnd: range?.end,
            isAllTime: range == null,
          );
      if (mounted) Navigator.of(context).pop(list);
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate list: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matching = _matching;
    final supplierCount =
        matching.map((p) => p.supplierId ?? 'unassigned').toSet().length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Generate Purchase List',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick which pending purchases to pull products from. '
                'Purchases already in a list are never included again.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RangeChip(
                    label: 'All',
                    selected: _rangeFilter == 'all',
                    onTap: () => setState(() => _rangeFilter = 'all'),
                  ),
                  _RangeChip(
                    label: 'Today',
                    selected: _rangeFilter == 'today',
                    onTap: () => setState(() => _rangeFilter = 'today'),
                  ),
                  _RangeChip(
                    label: 'This Week',
                    selected: _rangeFilter == 'week',
                    onTap: () => setState(() => _rangeFilter = 'week'),
                  ),
                  _RangeChip(
                    label: 'This Month',
                    selected: _rangeFilter == 'month',
                    onTap: () => setState(() => _rangeFilter = 'month'),
                  ),
                  _RangeChip(
                    label: 'Custom…',
                    selected: _rangeFilter == 'custom',
                    onTap: _pickCustomRange,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  matching.isEmpty
                      ? 'No pending purchases match this range.'
                      : '${matching.length} pending purchase(s) · '
                          '$supplierCount supplier${supplierCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _generating
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          (_generating || matching.isEmpty) ? null : _generate,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _generating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Generate'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.cardBorder,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
