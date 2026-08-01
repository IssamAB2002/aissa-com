import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../products/models/product.dart';
import '../../products/providers/products_provider.dart';
import '../models/inventory_movement.dart';
import '../providers/inventory_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key, this.initialProduct});
  final Product? initialProduct;

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState
    extends ConsumerState<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late Product? _selectedProduct;
  MovementType _type = MovementType.stockIn;
  String? _reason;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  static const _reasons = [
    'Received shipment',
    'Returned goods',
    'Damaged/expired',
    'Sold offline',
    'Count correction',
    'Other',
  ];

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedProduct == null) {
      return;
    }
    setState(() => _saving = true);
    await ref.read(inventoryServiceProvider).adjustStock(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          type: _type,
          quantity: int.parse(_qtyCtrl.text.trim()),
          currentStock: _selectedProduct!.stockQuantity,
          reason: _reason,
          note: _noteCtrl.text.trim().isEmpty
              ? null
              : _noteCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Adjust Stock')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Select Product',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            productsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (products) => _ProductSearchField(
                products: products,
                selectedProduct: _selectedProduct,
                onSelected: (p) => setState(() => _selectedProduct = p),
              ),
            ),
            const SizedBox(height: 24),
            Text('Adjustment Type',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: MovementType.values.map((t) {
                final selected = _type == t;
                final color = t == MovementType.stockIn
                    ? AppColors.success
                    : t == MovementType.stockOut
                        ? AppColors.error
                        : AppColors.primary;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      margin:
                          const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.1)
                            : AppColors.background,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? color
                              : AppColors.divider,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        t.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? color
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity *',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Required';
                }
                if (int.tryParse(v.trim()) == null ||
                    int.parse(v.trim()) <= 0) {
                  return 'Enter a valid positive number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _reason,
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Reason (optional)'),
                  ),
                  isExpanded: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  items: _reasons
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r)))
                      .toList(),
                  onChanged: (r) =>
                      setState(() => _reason = r),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration:
                  const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed:
                  _saving || _selectedProduct == null ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Apply Adjustment'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProductSearchField extends StatefulWidget {
  const _ProductSearchField({
    required this.products,
    required this.selectedProduct,
    required this.onSelected,
  });
  final List<Product> products;
  final Product? selectedProduct;
  final ValueChanged<Product?> onSelected;

  @override
  State<_ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<_ProductSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _open = _focus.hasFocus));
    if (widget.selectedProduct != null) {
      _ctrl.text = widget.selectedProduct!.name;
    }
  }

  @override
  void didUpdateWidget(_ProductSearchField old) {
    super.didUpdateWidget(old);
    if (widget.selectedProduct == null && old.selectedProduct != null) {
      _ctrl.clear();
      _query = '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Product> get _filtered => _query.isEmpty
      ? widget.products
      : widget.products
          .where((p) =>
              p.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  void _select(Product p) {
    _ctrl.text = p.name;
    _query = '';
    _focus.unfocus();
    setState(() => _open = false);
    widget.onSelected(p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          decoration: const InputDecoration(
            labelText: 'Product',
            suffixIcon: Icon(Icons.keyboard_arrow_down,
                color: AppColors.textSecondary),
          ),
          onChanged: (v) {
            setState(() {
              _query = v;
              _open = true;
              if (widget.selectedProduct != null) widget.onSelected(null);
            });
          },
        ),
        if (_open) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No results for "$_query"',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final p = _filtered[i];
                      return InkWell(
                        borderRadius: i == 0
                            ? const BorderRadius.vertical(
                                top: Radius.circular(8))
                            : i == _filtered.length - 1
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(8))
                                : BorderRadius.zero,
                        onTap: () => _select(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p.name,
                                  style: theme.textTheme.bodyLarge),
                              Text(
                                '${p.stockQuantity} in stock',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(
                                        color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
