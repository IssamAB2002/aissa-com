import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../products/models/product.dart';
import '../../products/providers/products_provider.dart';
import '../models/purchase.dart';
import '../providers/purchases_provider.dart';

class CreatePurchaseScreen extends ConsumerStatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  ConsumerState<CreatePurchaseScreen> createState() =>
      _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends ConsumerState<CreatePurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _feesCtrl = TextEditingController();
  final List<_CartItem> _cart = [];
  Product? _selectedProduct;
  bool _saving = false;

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _notesCtrl.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _feesCtrl.dispose();
    super.dispose();
  }

  double get _itemsSubtotal =>
      _cart.fold(0, (sum, item) => sum + item.subtotal);
  double get _fees => double.tryParse(_feesCtrl.text.trim()) ?? 0.0;
  double get _total => _itemsSubtotal + _fees;

  void _onProductSelected(Product? p) {
    setState(() {
      _selectedProduct = p;
      if (p != null && p.costPrice != null) {
        _costCtrl.text = p.costPrice!.toStringAsFixed(2);
      } else {
        _costCtrl.clear();
      }
    });
  }

  void _addToCart() {
    if (_selectedProduct == null) return;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    if (qty <= 0) return;

    setState(() {
      final idx =
          _cart.indexWhere((i) => i.product.id == _selectedProduct!.id);
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + qty, unitCost: cost);
      } else {
        _cart.add(
            _CartItem(product: _selectedProduct!, qty: qty, unitCost: cost));
      }
      _selectedProduct = null;
      _costCtrl.clear();
      _qtyCtrl.text = '1';
    });
  }

  void _removeFromCart(_CartItem item) {
    setState(() => _cart.remove(item));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final purchase = Purchase(
        id: const Uuid().v4(),
        supplierName: _supplierCtrl.text.trim(),
        items: _cart
            .map((i) => PurchaseItem(
                  productId: i.product.id,
                  productName: i.product.name,
                  unitCost: i.unitCost,
                  quantity: i.qty,
                ))
            .toList(),
        total: _total,
        fees: _fees,
        status: PurchaseStatus.pending,
        notes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(purchasesServiceProvider).createPurchase(purchase);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create purchase: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Supplier Info',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplierCtrl,
              decoration:
                  const InputDecoration(labelText: 'Supplier Name *'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            Text('Add Products',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            productsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading products: $e'),
              data: (products) {
                if (products.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        const Text(
                          'No products in your catalog yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: AppColors.surface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              builder: (_) => _QuickCreateProductSheet(
                                onCreated: _onProductSelected,
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create New Product'),
                        ),
                      ],
                    ),
                  );
                }
                return _ProductSection(
                  products: products,
                  selectedProduct: _selectedProduct,
                  cart: _cart,
                  qtyCtrl: _qtyCtrl,
                  costCtrl: _costCtrl,
                  onProductSelected: _onProductSelected,
                  onAdd: _addToCart,
                  onRemove: _removeFromCart,
                  total: _itemsSubtotal,
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Fees',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _feesCtrl,
              decoration: const InputDecoration(
                labelText: 'Fees (optional)',
                prefixText: 'DZD ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Purchase'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.products,
    required this.selectedProduct,
    required this.cart,
    required this.qtyCtrl,
    required this.costCtrl,
    required this.onProductSelected,
    required this.onAdd,
    required this.onRemove,
    required this.total,
  });

  final List<Product> products;
  final Product? selectedProduct;
  final List<_CartItem> cart;
  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;
  final ValueChanged<Product?> onProductSelected;
  final VoidCallback onAdd;
  final ValueChanged<_CartItem> onRemove;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shadowColor: Colors.transparent,
                side: const BorderSide(color: AppColors.cardBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ProductSearchField(
            products: products,
            selectedProduct: selectedProduct,
            onSelected: onProductSelected,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: costCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Cost Price (DZD)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          if (cart.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            ...cart.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.product.name,
                              style: theme.textTheme.bodyLarge),
                          Text(
                            '${item.qty} × DZD ${item.unitCost.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'DZD ${item.subtotal.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.error),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => onRemove(item),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Products Subtotal',
                    style: theme.textTheme.titleMedium),
                Text(
                  'DZD ${total.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItem {
  const _CartItem(
      {required this.product, required this.qty, this.unitCost = 0.0});
  final Product product;
  final int qty;
  final double unitCost;
  double get subtotal => unitCost * qty;
  _CartItem copyWith({int? qty, double? unitCost}) => _CartItem(
      product: product,
      qty: qty ?? this.qty,
      unitCost: unitCost ?? this.unitCost);
}

class _ProductSearchField extends ConsumerStatefulWidget {
  const _ProductSearchField({
    required this.products,
    required this.selectedProduct,
    required this.onSelected,
  });
  final List<Product> products;
  final Product? selectedProduct;
  final ValueChanged<Product?> onSelected;

  @override
  ConsumerState<_ProductSearchField> createState() =>
      _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<_ProductSearchField> {
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
    } else if (widget.selectedProduct != null &&
        widget.selectedProduct!.id != old.selectedProduct?.id) {
      _ctrl.text = widget.selectedProduct!.name;
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
          .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  void _select(Product p) {
    _ctrl.text = p.name;
    _query = '';
    _focus.unfocus();
    setState(() => _open = false);
    widget.onSelected(p);
  }

  void _openCreateSheet() {
    _focus.unfocus();
    setState(() => _open = false);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuickCreateProductSheet(
        initialName: _query.trim(),
        onCreated: (product) {
          _select(product);
        },
      ),
    );
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_filtered.isNotEmpty)
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, i) {
                        final p = _filtered[i];
                        return InkWell(
                          borderRadius: i == 0
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(8))
                              : BorderRadius.zero,
                          onTap: () => _select(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(p.name,
                                style: theme.textTheme.bodyLarge),
                          ),
                        );
                      },
                    ),
                  ),
                if (_filtered.isEmpty && _query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'No results for "$_query"',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                if (_filtered.isNotEmpty) const Divider(height: 1),
                InkWell(
                  onTap: _openCreateSheet,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          _query.trim().isNotEmpty
                              ? 'Create "${_query.trim()}"'
                              : 'Create New Product',
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickCreateProductSheet extends ConsumerStatefulWidget {
  const _QuickCreateProductSheet({
    required this.onCreated,
    this.initialName = '',
  });
  final ValueChanged<Product> onCreated;
  final String initialName;

  @override
  ConsumerState<_QuickCreateProductSheet> createState() =>
      _QuickCreateProductSheetState();
}

class _QuickCreateProductSheetState
    extends ConsumerState<_QuickCreateProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  final _costCtrl = TextEditingController();
  final _margeCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _saving = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _costCtrl.addListener(_onCostChanged);
    _margeCtrl.addListener(_onMargeChanged);
    _salePriceCtrl.addListener(_onSalePriceChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _margeCtrl.dispose();
    _salePriceCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _onCostChanged() {
    if (_isUpdating) return;
    final cost = double.tryParse(_costCtrl.text.trim());
    final marge = double.tryParse(_margeCtrl.text.trim());
    if (cost == null || cost <= 0) return;
    if (marge != null) {
      _isUpdating = true;
      _salePriceCtrl.text = (cost * (1 + marge / 100)).toStringAsFixed(2);
      _isUpdating = false;
    }
  }

  void _onMargeChanged() {
    if (_isUpdating) return;
    final cost = double.tryParse(_costCtrl.text.trim());
    final marge = double.tryParse(_margeCtrl.text.trim());
    if (cost == null || cost <= 0 || marge == null) return;
    _isUpdating = true;
    _salePriceCtrl.text = (cost * (1 + marge / 100)).toStringAsFixed(2);
    _isUpdating = false;
  }

  void _onSalePriceChanged() {
    if (_isUpdating) return;
    final cost = double.tryParse(_costCtrl.text.trim());
    final sale = double.tryParse(_salePriceCtrl.text.trim());
    if (cost == null || cost <= 0 || sale == null || sale <= 0) return;
    _isUpdating = true;
    _margeCtrl.text = ((sale - cost) / cost * 100).toStringAsFixed(1);
    _isUpdating = false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final costPrice = double.parse(_costCtrl.text.trim());
      final salePrice = double.tryParse(_salePriceCtrl.text.trim()) ?? 0.0;
      final product = Product(
        id: '',
        name: _nameCtrl.text.trim(),
        price: salePrice,
        costPrice: costPrice,
        category: _categoryCtrl.text.trim().isEmpty
            ? null
            : _categoryCtrl.text.trim(),
        stockQuantity: 0,
        createdAt: now,
      );
      final id = await ref.read(productsServiceProvider).createProduct(product);
      final created = Product(
        id: id,
        name: product.name,
        price: salePrice,
        costPrice: costPrice,
        category: product.category,
        stockQuantity: 0,
        createdAt: now,
      );
      if (mounted) {
        widget.onCreated(created);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create product: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('New Product',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Product Name *'),
              textCapitalization: TextCapitalization.words,
              autofocus: widget.initialName.isEmpty,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costCtrl,
              decoration:
                  const InputDecoration(labelText: 'Cost Price (DZD) *'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: widget.initialName.isNotEmpty,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid price';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _margeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Marge (%)',
                      suffixText: '%',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final val = double.tryParse(v.trim());
                      if (val == null) return 'Invalid';
                      if (val < 0) return 'Cannot be negative';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _salePriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sale Price (DZD)',
                      suffixText: 'DZD',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (double.tryParse(v.trim()) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryCtrl,
              decoration:
                  const InputDecoration(labelText: 'Category (optional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Create Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
