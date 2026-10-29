import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/purchase_list.dart';
import '../providers/purchase_lists_provider.dart';

class PurchaseListsScreen extends ConsumerStatefulWidget {
  const PurchaseListsScreen({super.key});

  @override
  ConsumerState<PurchaseListsScreen> createState() =>
      _PurchaseListsScreenState();
}

class _PurchaseListsScreenState extends ConsumerState<PurchaseListsScreen> {
  String _dateFilter = 'all';
  DateTimeRange? _customRange;
  PurchaseListOrigin? _originFilter;

  DateTimeRange? _activeDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_dateFilter) {
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

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange,
    );
    if (range != null && mounted) {
      setState(() {
        _dateFilter = 'custom';
        _customRange = DateTimeRange(
          start: range.start,
          end: range.end.add(const Duration(days: 1)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(purchaseListsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Lists')),
      body: Column(
        children: [
          _DateFilterChips(
            selected: _dateFilter,
            onSelected: (v) => setState(() => _dateFilter = v),
            onCustom: _pickCustomRange,
          ),
          _OriginFilterChips(
            selected: _originFilter,
            onSelected: (o) => setState(() => _originFilter = o),
          ),
          Expanded(
            child: listsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (lists) {
                final activeRange = _activeDateRange();
                final filtered = lists.where((l) {
                  final matchDate = activeRange == null ||
                      (!l.createdAt.isBefore(activeRange.start) &&
                          l.createdAt.isBefore(activeRange.end));
                  final matchOrigin =
                      _originFilter == null || l.origin == _originFilter;
                  return matchDate && matchOrigin;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.checklist_outlined,
                    title: 'No purchase lists found',
                    subtitle:
                        'Generate one from the Purchases screen, or create one '
                        'directly from Orders, to see it here.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _PurchaseListCard(list: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateFilterChips extends StatelessWidget {
  const _DateFilterChips({
    required this.selected,
    required this.onSelected,
    required this.onCustom,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          _TabButton(
              label: 'All',
              isSelected: selected == 'all',
              onPressed: () => onSelected('all')),
          const SizedBox(width: 8),
          _TabButton(
              label: 'Today',
              isSelected: selected == 'today',
              onPressed: () => onSelected('today')),
          const SizedBox(width: 8),
          _TabButton(
              label: 'This Week',
              isSelected: selected == 'week',
              onPressed: () => onSelected('week')),
          const SizedBox(width: 8),
          _TabButton(
              label: 'This Month',
              isSelected: selected == 'month',
              onPressed: () => onSelected('month')),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCustom,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected == 'custom'
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected == 'custom'
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 17,
                  color:
                      selected == 'custom' ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginFilterChips extends StatelessWidget {
  const _OriginFilterChips({required this.selected, required this.onSelected});
  final PurchaseListOrigin? selected;
  final ValueChanged<PurchaseListOrigin?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          _TabButton(
            label: 'All',
            isSelected: selected == null,
            onPressed: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'From Purchases',
            isSelected: selected == PurchaseListOrigin.purchase,
            onPressed: () => onSelected(selected == PurchaseListOrigin.purchase
                ? null
                : PurchaseListOrigin.purchase),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'From Orders',
            isSelected: selected == PurchaseListOrigin.order,
            onPressed: () => onSelected(
                selected == PurchaseListOrigin.order
                    ? null
                    : PurchaseListOrigin.order),
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
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseListCard extends ConsumerWidget {
  const _PurchaseListCard({required this.list});
  final PurchaseList list;

  String get _titleLabel {
    if (list.origin == PurchaseListOrigin.order) {
      final n = list.sourceOrderIds.length;
      return 'From $n Order${n != 1 ? 's' : ''}';
    }
    if (list.isAllTime) return 'All Time';
    return '${DateFormat('MMM d, y').format(list.rangeStart!)} '
        '– ${DateFormat('MMM d, y').format(list.rangeEnd!.subtract(const Duration(days: 1)))}';
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.delete_outline,
      iconColor: AppColors.error,
      title: 'Delete Purchase List',
      message: 'Its source purchases will become eligible for a new '
          'Purchase List again. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (ok != true) return false;

    try {
      await ref.read(purchaseListsServiceProvider).deletePurchaseList(list.id);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete list: $e')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allChecked =
        list.totalProducts > 0 && list.checkedProducts == list.totalProducts;

    return Dismissible(
      key: ValueKey(list.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, ref),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => context.push('/purchase-lists/${list.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _titleLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (list.origin == PurchaseListOrigin.order) ...[
                    const _FromOrderBadge(),
                    const SizedBox(width: 6),
                  ],
                  if (allChecked)
                    const Icon(Icons.check_circle,
                        size: 18, color: AppColors.success),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                list.origin == PurchaseListOrigin.order
                    ? '${list.checkedProducts}/${list.totalProducts} products checked'
                    : '${list.supplierCount} supplier${list.supplierCount != 1 ? 's' : ''} · '
                        '${list.checkedProducts}/${list.totalProducts} products checked',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Generated ${DateFormat('MMM d, y · h:mm a').format(list.createdAt)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks a [PurchaseList] built via the "create PL from Orders" shortcut,
/// as opposed to the default path (generated from pending Purchases).
class _FromOrderBadge extends StatelessWidget {
  const _FromOrderBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 12, color: AppColors.primary),
          SizedBox(width: 4),
          Text(
            'From Order',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
