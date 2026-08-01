import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/products_provider.dart';
import '../models/product.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    return productsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (products) {
        final idx = products.indexWhere((p) => p.id == productId);
        if (idx == -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/products');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final isAdmin =
            ref.read(currentUserProvider).valueOrNull?.isAdmin ?? false;
        return _ProductDetailView(
          product: products[idx],
          service: ref.read(productsServiceProvider),
          isAdmin: isAdmin,
        );
      },
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView(
      {required this.product, required this.service, required this.isAdmin});
  final Product product;
  final dynamic service;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          if (isAdmin) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/products/${product.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await AppConfirmDialog.show(
                context,
                icon: Icons.delete_outline,
                iconColor: AppColors.error,
                title: 'Delete Product',
                message: 'This action cannot be undone.',
                confirmLabel: 'Delete',
              );
              if (ok == true && context.mounted) {
                await service.deleteProduct(product.id);
                if (context.mounted) context.pop();
              }
            },
          ),
          ], // end isAdmin
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image placeholder
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(Icons.inventory_2_outlined,
                  size: 64,
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(product: product),
          const SizedBox(height: 12),
          _PricingCard(product: product),
          const SizedBox(height: 12),
          _StockCard(product: product),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Details',
      children: [
        _Row(label: 'Name', value: product.name),
        if (product.category != null)
          _Row(label: 'Category', value: product.category!),
        if (product.description != null &&
            product.description!.isNotEmpty)
          _Row(label: 'Description', value: product.description!),
        _Row(
            label: 'Status',
            value: product.isActive ? 'Active' : 'Archived'),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final margin = product.costPrice != null
        ? product.price - product.costPrice!
        : null;
    final marginPct = product.marginPercent;
    return _Card(
      title: 'Pricing',
      children: [
        _Row(
            label: 'Cost Price',
            value: product.costPrice != null
                ? 'DZD ${product.costPrice!.toStringAsFixed(2)}'
                : '—'),
        _Row(
            label: 'Sale Price',
            value: 'DZD ${product.price.toStringAsFixed(2)}'),
        if (margin != null)
          _Row(
            label: 'Marge',
            value: marginPct != null
                ? '${marginPct.toStringAsFixed(1)}%'
                    '  (DZD ${margin.toStringAsFixed(2)})'
                : 'DZD ${margin.toStringAsFixed(2)}',
            valueColor:
                margin >= 0 ? AppColors.success : AppColors.error,
          ),
      ],
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final Color stockColor = product.isOutOfStock
        ? AppColors.error
        : product.isLowStock
            ? AppColors.warning
            : AppColors.success;

    return _Card(
      title: 'Inventory',
      children: [
        _Row(
          label: 'In Stock',
          value: '${product.stockQuantity} units',
          valueColor: stockColor,
        ),
        _Row(
            label: 'Low Stock At',
            value: '${product.lowStockThreshold} units'),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: valueColor,
                    fontWeight: valueColor != null
                        ? FontWeight.w600
                        : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
