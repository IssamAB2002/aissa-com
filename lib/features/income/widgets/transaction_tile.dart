import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../models/transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onDelete,
  });

  final AppTransaction transaction;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppColors.success : AppColors.error;

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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category ?? (isIncome ? 'Income' : 'Expense'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (transaction.description != null)
                  Text(transaction.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                Text(
                  DateFormat('MMM d, y').format(transaction.date),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}DZD ${transaction.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                    ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: () async {
                    final ok = await AppConfirmDialog.show(
                      context,
                      icon: Icons.delete_outline,
                      iconColor: AppColors.error,
                      title: 'Delete Transaction',
                      message: 'This action cannot be undone.',
                      confirmLabel: 'Delete',
                    );
                    if (ok == true) onDelete!();
                  },
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.textHint),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
