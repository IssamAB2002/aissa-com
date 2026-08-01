import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../products/models/product.dart';

class InventoryItemTile extends StatelessWidget {
  const InventoryItemTile({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final Color stockColor = product.isOutOfStock
        ? AppColors.error
        : product.isLowStock
            ? AppColors.warning
            : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: product.isOutOfStock || product.isLowStock
              ? stockColor.withValues(alpha: 0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2_outlined,
                color: stockColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: Theme.of(context).textTheme.titleMedium),
                if (product.category != null)
                  Text(product.category!,
                      style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.stockQuantity} units',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: stockColor,
                    ),
              ),
              Text(
                product.isOutOfStock
                    ? 'Out of stock'
                    : product.isLowStock
                        ? 'Low stock'
                        : 'In stock',
                style: TextStyle(
                    color: stockColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.tune, size: 20,
                color: AppColors.textSecondary),
            onPressed: () => context.push('/inventory/adjust',
                extra: product),
          ),
        ],
      ),
    );
  }
}
