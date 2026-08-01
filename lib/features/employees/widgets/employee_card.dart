import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../models/employee.dart';

class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.employee,
    required this.rewardPercent,
    required this.rewardAmount,
    required this.ordersCount,
    required this.amountOwed,
    required this.onTap,
  });

  final Employee employee;
  final double rewardPercent;
  final double rewardAmount;
  final int ordersCount;
  final double amountOwed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final owed = amountOwed;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            // Main row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        employee.name.isNotEmpty
                            ? employee.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name / role / orders
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee.name,
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        if (employee.role != null)
                          Text(employee.role!,
                              style:
                                  Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        _ConfirmedOrdersChip(count: ordersCount),
                      ],
                    ),
                  ),

                  // Benefit % + reward
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${rewardPercent.toStringAsFixed(1)}%',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: AppColors.primary),
                      ),
                      Text(
                        'DZD ${rewardAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount owed strip (only when > 0)
            if (owed > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(11)),
                  border: Border(
                    top: BorderSide(
                        color: AppColors.warning.withValues(alpha: 0.25)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 13, color: AppColors.warning),
                    const SizedBox(width: 6),
                    const Text('Amount Owed: ',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    Text(
                      'DZD ${NumberFormat('#,##0.00').format(owed)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfirmedOrdersChip extends StatelessWidget {
  const _ConfirmedOrdersChip({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_outlined,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$count confirmed orders',
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
