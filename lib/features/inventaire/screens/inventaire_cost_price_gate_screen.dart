import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../products/models/product.dart';
import '../../products/providers/products_provider.dart';

/// Step 2 of an Inventaire session: the closing stock is valued at cost
/// price, so every active product must have a real (non-zero) cost price
/// before the count can proceed.
class InventaireCostPriceGateScreen extends ConsumerWidget {
  const InventaireCostPriceGateScreen({super.key, required this.inventaireId});

  final String inventaireId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final missing = productsAsync.valueOrNull
            ?.where((p) =>
                p.isActive && (p.costPrice == null || p.costPrice! <= 0))
            .toList() ??
        [];
    final loading = productsAsync.isLoading;
    final canContinue = !loading && missing.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Set Missing Cost Prices')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: missing.isEmpty
                      ? const EmptyState(
                          icon: Icons.check_circle_outline,
                          title: 'All products have a cost price',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: missing.length,
                          itemBuilder: (context, i) =>
                              _CostPriceTile(product: missing[i]),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canContinue
                          ? () => context
                              .push('/inventaire/$inventaireId/count')
                          : null,
                      child: const Text('Continue'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CostPriceTile extends ConsumerStatefulWidget {
  const _CostPriceTile({required this.product});
  final Product product;

  @override
  ConsumerState<_CostPriceTile> createState() => _CostPriceTileState();
}

class _CostPriceTileState extends ConsumerState<_CostPriceTile> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    setState(() => _saving = true);
    await ref
        .read(productsServiceProvider)
        .updateProduct(widget.product.id, {'costPrice': value});
    if (mounted) setState(() => _saving = false);
  }

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
            child: Text(widget.product.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Cost price',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: AppColors.success),
                  onPressed: _save,
                ),
        ],
      ),
    );
  }
}
