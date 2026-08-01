import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../products/providers/products_provider.dart';
import '../widgets/inventory_item_tile.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() =>
      _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _search = '';
  String _filter = 'all'; // all, low, out

  Future<void> _refresh() async {
    ref.invalidate(productsStreamProvider);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Movements',
              onPressed: () => context.push('/inventory/movements'),
            ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/inventory/adjust'),
              icon: const Icon(Icons.tune),
              label: const Text('Adjust Stock'),
            )
          : null,
      body: productsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          final lowCount =
              products.where((p) => p.isLowStock).length;
          final outCount =
              products.where((p) => p.isOutOfStock).length;

          final filtered = products.where((p) {
            final matchSearch = _search.isEmpty ||
                p.name
                    .toLowerCase()
                    .contains(_search.toLowerCase());
            final matchFilter = _filter == 'all' ||
                (_filter == 'low' && p.isLowStock) ||
                (_filter == 'out' && p.isOutOfStock);
            return matchSearch && matchFilter;
          }).toList();

          return Column(
            children: [
              // Summary cards
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Total SKUs',
                        value: '${products.length}',
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        title: 'Low Stock',
                        value: '$lowCount',
                        icon: Icons.warning_amber_outlined,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        title: 'Out of Stock',
                        value: '$outCount',
                        icon: Icons.remove_circle_outline,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.textHint),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'All',
                      isSelected: _filter == 'all',
                      onPressed: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _TabButton(
                      label: 'Low Stock ($lowCount)',
                      isSelected: _filter == 'low',
                      onPressed: () => setState(() => _filter = 'low'),
                    ),
                    const SizedBox(width: 8),
                    _TabButton(
                      label: 'Out of Stock ($outCount)',
                      isSelected: _filter == 'out',
                      onPressed: () => setState(() => _filter = 'out'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _refresh,
                        child: LayoutBuilder(
                          builder: (ctx, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: constraints.maxHeight,
                              child: const EmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: 'No products found',
                              ),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) =>
                              InventoryItemTile(product: filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
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
