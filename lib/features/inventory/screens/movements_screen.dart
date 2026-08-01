import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/inventory_movement.dart';
import '../providers/inventory_provider.dart';

class MovementsScreen extends ConsumerWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(movementsStreamProvider);
    final service = ref.read(inventoryServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Movements'),
        actions: [
          movementsAsync.maybeWhen(
            data: (movements) => movements.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear All',
                    onPressed: () async {
                      final ok = await AppConfirmDialog.show(
                        context,
                        icon: Icons.delete_sweep_outlined,
                        iconColor: AppColors.error,
                        title: 'Clear All History',
                        message:
                            'This will permanently delete all movement records. This cannot be undone.',
                        confirmLabel: 'Clear All',
                      );
                      if (ok == true && context.mounted) {
                        await service.clearAllMovements();
                      }
                    },
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: movementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (movements) {
          if (movements.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No movements yet',
              subtitle: 'Stock adjustments will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movements.length,
            itemBuilder: (context, i) => _MovementTile(
              movement: movements[i],
              onDelete: () async {
                final ok = await AppConfirmDialog.show(
                  context,
                  icon: Icons.delete_outline,
                  iconColor: AppColors.error,
                  title: 'Delete Movement',
                  message: 'Remove this record? This cannot be undone.',
                  confirmLabel: 'Delete',
                );
                if (ok == true && context.mounted) {
                  await service.deleteMovement(movements[i].id);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.onDelete});
  final InventoryMovement movement;
  final VoidCallback onDelete;

  Color get _color => switch (movement.type) {
        MovementType.stockIn => AppColors.success,
        MovementType.stockOut => AppColors.error,
        MovementType.adjustment => AppColors.primary,
      };

  String get _prefix => movement.type == MovementType.stockIn
      ? '+'
      : movement.type == MovementType.stockOut
          ? '-'
          : '=';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              movement.type == MovementType.stockIn
                  ? Icons.arrow_downward
                  : movement.type == MovementType.stockOut
                      ? Icons.arrow_upward
                      : Icons.tune,
              color: _color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movement.productName,
                    style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  movement.type.label +
                      (movement.reason != null
                          ? ' · ${movement.reason}'
                          : ''),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  DateFormat('MMM d, y · h:mm a').format(movement.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Text(
            '$_prefix${movement.quantity}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: _color),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
