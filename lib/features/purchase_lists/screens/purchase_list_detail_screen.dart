import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../models/purchase_list.dart';
import '../providers/purchase_lists_provider.dart';

/// Read-only Purchase List: products are grouped by supplier and can be
/// ticked off as they're sourced. The checklist state has no effect on
/// stock or finance — it's purely a shared "picked up" tracker.
class PurchaseListDetailScreen extends ConsumerWidget {
  const PurchaseListDetailScreen({super.key, required this.listId});
  final String listId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.delete_outline,
      iconColor: AppColors.error,
      title: 'Delete Purchase List',
      message: 'Its source purchases will become eligible for a new '
          'Purchase List again. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (ok != true) return;

    try {
      await ref.read(purchaseListsServiceProvider).deletePurchaseList(listId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete list: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(purchaseListProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list == null) {
            return const Center(child: Text('Purchase list not found'));
          }
          return _PurchaseListBody(list: list);
        },
      ),
    );
  }
}

String _titleLabel(PurchaseList list) {
  if (list.origin == PurchaseListOrigin.order) {
    final n = list.sourceOrderIds.length;
    return 'From $n Order${n != 1 ? 's' : ''}';
  }
  if (list.isAllTime) return 'All Time';
  return '${DateFormat('MMM d, y').format(list.rangeStart!)} '
      '– ${DateFormat('MMM d, y').format(list.rangeEnd!.subtract(const Duration(days: 1)))}';
}

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

class _PurchaseListBody extends ConsumerWidget {
  const _PurchaseListBody({required this.list});
  final PurchaseList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(purchaseListsServiceProvider);
    final progress =
        list.totalProducts == 0 ? 0.0 : list.checkedProducts / list.totalProducts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _titleLabel(list),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (list.origin == PurchaseListOrigin.order)
                    const _FromOrderBadge(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Generated ${DateFormat('MMM d, y · h:mm a').format(list.createdAt)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.background,
                  color: progress >= 1.0
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${list.checkedProducts}/${list.totalProducts} products checked',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final group in list.groups) ...[
          _SupplierGroupCard(
            group: group,
            onItemToggled: (productId, checked) => service.setItemChecked(
              listId: list.id,
              groupKey: group.key,
              productId: productId,
              checked: checked,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SupplierGroupCard extends StatelessWidget {
  const _SupplierGroupCard({required this.group, required this.onItemToggled});
  final PurchaseListGroup group;
  final void Function(String productId, bool checked) onItemToggled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.supplierName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${group.checkedCount}/${group.items.length}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final item in group.items)
            CheckboxListTile(
              value: item.checked,
              onChanged: (v) => onItemToggled(item.productId, v ?? false),
              title: Text(
                item.productName,
                style: TextStyle(
                  decoration:
                      item.checked ? TextDecoration.lineThrough : null,
                  color: item.checked
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
              ),
              subtitle: Text('Qty ${item.quantity}'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
        ],
      ),
    );
  }
}
