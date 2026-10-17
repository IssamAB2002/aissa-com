import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/purchase_list.dart';
import '../providers/purchase_lists_provider.dart';

class PurchaseListsScreen extends ConsumerWidget {
  const PurchaseListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(purchaseListsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Lists')),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lists) {
          if (lists.isEmpty) {
            return const EmptyState(
              icon: Icons.checklist_outlined,
              title: 'No purchase lists yet',
              subtitle:
                  'Generate one from the Purchases screen to group pending '
                  'purchases by supplier.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lists.length,
            itemBuilder: (context, i) => _PurchaseListCard(list: lists[i]),
          );
        },
      ),
    );
  }
}

class _PurchaseListCard extends ConsumerWidget {
  const _PurchaseListCard({required this.list});
  final PurchaseList list;

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
                  Text(
                    list.isAllTime
                        ? 'All Time'
                        : '${DateFormat('MMM d, y').format(list.rangeStart!)} '
                            '– ${DateFormat('MMM d, y').format(list.rangeEnd!.subtract(const Duration(days: 1)))}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (allChecked)
                    const Icon(Icons.check_circle,
                        size: 18, color: AppColors.success),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${list.supplierCount} supplier${list.supplierCount != 1 ? 's' : ''} · '
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
