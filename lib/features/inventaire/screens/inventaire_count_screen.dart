import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../inventory/models/inventory_movement.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../products/models/product.dart';
import '../../products/providers/products_provider.dart';
import '../models/inventaire_stock_line.dart';
import '../providers/inventaire_provider.dart';

/// Step 3 of an Inventaire session: the admin enters the real, physically
/// counted quantity for every active product. On finish, every product
/// whose counted quantity differs from the live system quantity is
/// corrected via the existing InventoryService (adjustment movement), a
/// full snapshot of every product is archived as the session's stock
/// lines, and the session is finalized (locked).
class InventaireCountScreen extends ConsumerStatefulWidget {
  const InventaireCountScreen({super.key, required this.inventaireId});

  final String inventaireId;

  @override
  ConsumerState<InventaireCountScreen> createState() =>
      _InventaireCountScreenState();
}

class _InventaireCountScreenState
    extends ConsumerState<InventaireCountScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _initialized = false;
  bool _finalizing = false;
  String _search = '';

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(List<Product> products) {
    if (_initialized) return;
    for (final p in products) {
      _controllers[p.id] =
          TextEditingController(text: p.stockQuantity.toString());
    }
    _initialized = true;
  }

  Future<void> _finish(List<Product> products) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      icon: Icons.fact_check_outlined,
      iconColor: AppColors.primary,
      title: 'Finish & Finalize',
      message: 'Stock corrections will be applied and this Inventaire will '
          'be locked. This cannot be undone.',
      confirmLabel: 'Finalize',
      confirmColor: AppColors.primary,
    );
    if (confirmed != true) return;

    setState(() => _finalizing = true);

    final inventoryService = ref.read(inventoryServiceProvider);
    final inventaireService = ref.read(inventaireServiceProvider);

    final lines = <InventaireStockLine>[];
    for (final p in products) {
      final controller = _controllers[p.id];
      final counted =
          int.tryParse(controller?.text ?? '') ?? p.stockQuantity;
      lines.add(InventaireStockLine(
        productId: p.id,
        productName: p.name,
        systemQtyBefore: p.stockQuantity,
        countedQty: counted,
        costPrice: p.costPrice ?? 0,
      ));
    }

    for (final line in lines) {
      if (line.delta == 0) continue;
      await inventoryService.adjustStock(
        productId: line.productId,
        productName: line.productName,
        type: MovementType.adjustment,
        quantity: line.countedQty,
        currentStock: line.systemQtyBefore,
        reason: 'Inventaire',
        note: 'Physical count correction',
      );
    }

    await inventaireService.saveStockLines(widget.inventaireId, lines);

    final resolvedOrders = await ref
        .read(inventaireServiceProvider)
        .streamResolvedOrders(widget.inventaireId)
        .first;
    final resolvedPurchases = await ref
        .read(inventaireServiceProvider)
        .streamResolvedPurchases(widget.inventaireId)
        .first;
    final resolvedOrderPayments = await ref
        .read(inventaireServiceProvider)
        .streamResolvedOrderPayments(widget.inventaireId)
        .first;
    final resolvedPurchasePayments = await ref
        .read(inventaireServiceProvider)
        .streamResolvedPurchasePayments(widget.inventaireId)
        .first;

    final totalValuation =
        lines.fold(0.0, (s, l) => s + l.valuation);

    await inventaireService.finalize(
      widget.inventaireId,
      totalStockValuation: totalValuation,
      totalOrdersResolved: resolvedOrders.length,
      totalPurchasesResolved: resolvedPurchases.length,
      totalOrderPaymentsSettled: resolvedOrderPayments.length,
      totalPurchasePaymentsSettled: resolvedPurchasePayments.length,
    );

    if (mounted) {
      context.go('/inventaire/${widget.inventaireId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final allActive =
        productsAsync.valueOrNull?.where((p) => p.isActive).toList() ?? [];
    _ensureControllers(allActive);

    final visible = _search.isEmpty
        ? allActive
        : allActive
            .where((p) =>
                p.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Physical Stock Count')),
      body: productsAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search products',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final p = visible[i];
                      return _CountTile(
                        product: p,
                        controller: _controllers[p.id]!,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _finalizing ? null : () => _finish(allActive),
                      child: _finalizing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Finish Count & Finalize'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.product, required this.controller});

  final Product product;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('System: ${product.stockQuantity}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}
