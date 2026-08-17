import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../employees/models/employee.dart';
import '../../employees/providers/employees_provider.dart';
import '../../products/models/product.dart';
import '../../products/providers/products_provider.dart';
import '../../shipping/models/baladia.dart';
import '../../shipping/models/hub.dart';
import '../../shipping/models/wilaya.dart';
import '../../shipping/providers/shipping_reference_provider.dart';
import '../models/order.dart';
import '../providers/orders_provider.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() =>
      _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _feesCtrl = TextEditingController();
  final List<_CartItem> _cart = [];
  Product? _selectedProduct;
  DeliveryType _deliveryType = DeliveryType.homeDelivery;
  Wilaya? _selectedWilaya;
  Baladia? _selectedBaladia;
  Hub? _selectedHub;
  Employee? _selectedEmployee;
  bool _saving = false;
  bool _triedSubmit = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_onPriceChanged);
    _discountCtrl.addListener(_onExtraFieldChanged);
    _feesCtrl.addListener(_onExtraFieldChanged);
  }

  void _onPriceChanged() => setState(() {});
  void _onExtraFieldChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.removeListener(_onPriceChanged);
    _priceCtrl.dispose();
    _discountCtrl.removeListener(_onExtraFieldChanged);
    _discountCtrl.dispose();
    _feesCtrl.removeListener(_onExtraFieldChanged);
    _feesCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  double get _discountAmount =>
      double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
  double get _fees => double.tryParse(_feesCtrl.text.trim()) ?? 0.0;
  double get _total => _subtotal - _discountAmount;

  void _onProductSelected(Product? p) {
    setState(() {
      _selectedProduct = p;
      _priceCtrl.text = p != null ? p.price.toStringAsFixed(2) : '';
    });
  }

  void _addToCart() {
    if (_selectedProduct == null) return;
    final product = _selectedProduct!;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? product.price;
    if (qty <= 0) return;

    final alreadyInCart = _cart
        .where((i) => i.product.id == product.id)
        .fold(0, (sum, i) => sum + i.qty);
    final totalOrdered = alreadyInCart + qty;

    if (totalOrdered > product.stockQuantity) {
      _warnNegativeStock(product, qty, price, totalOrdered);
    } else {
      _doAddToCart(product, qty, price);
    }
  }

  Future<void> _warnNegativeStock(
      Product product, int qty, double price, int totalOrdered) async {
    final resultStock = product.stockQuantity - totalOrdered;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppColors.warning, size: 36),
        title: const Text('Stock Warning'),
        content: Text(
          '"${product.name}" only has ${product.stockQuantity} unit(s) in stock, '
          'but this order requires $totalOrdered.\n\n'
          'Stock will become $resultStock. Proceed anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed Anyway'),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) {
      _doAddToCart(product, qty, price);
    }
  }

  void _doAddToCart(Product product, int qty, double price) {
    setState(() {
      final idx = _cart.indexWhere((i) => i.product.id == product.id);
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + qty, unitPrice: price);
      } else {
        _cart.add(_CartItem(product: product, qty: qty, unitPrice: price));
      }
      _selectedProduct = null;
      _priceCtrl.clear();
      _qtyCtrl.text = '1';
    });
  }

  void _removeFromCart(_CartItem item) {
    setState(() => _cart.remove(item));
  }

  void _onWilayaChanged(Wilaya? wilaya) {
    setState(() {
      _selectedWilaya = wilaya;
      _selectedBaladia = null;
      _selectedHub = null;
    });
  }

  void _onDeliveryTypeChanged(DeliveryType type) {
    setState(() {
      _deliveryType = type;
      _selectedBaladia = null;
      _selectedHub = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);
    if (!_formKey.currentState!.validate()) return;
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product.')),
      );
      return;
    }
    if (_selectedWilaya == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a wilaya.')),
      );
      return;
    }
    if (_deliveryType == DeliveryType.homeDelivery &&
        _selectedBaladia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a baladia.')),
      );
      return;
    }
    if (_deliveryType == DeliveryType.pickupPoint && _selectedHub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup point.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final appUser = ref.read(currentUserProvider).valueOrNull;
      final selectedEmployee = _selectedEmployee;
      final creatorId =
          selectedEmployee != null ? selectedEmployee.uid : appUser?.uid;
      final creatorName =
          selectedEmployee != null ? selectedEmployee.name : appUser?.displayName;
      final wilaya = _selectedWilaya!;
      final order = Order(
        id: const Uuid().v4(),
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        city: wilaya.nameFr,
        items: _cart
            .map((i) => OrderItem(
                  productId: i.product.id,
                  productName: i.product.name,
                  unitPrice: i.unitPrice,
                  unitCostPrice: i.unitCostPrice,
                  quantity: i.qty,
                ))
            .toList(),
        status: OrderStatus.pending,
        total: _total,
        discountAmount: _discountAmount,
        fees: _fees,
        deliveryType: _deliveryType,
        notes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
        creatorId: creatorId,
        creatorName: creatorName,
        wilayaId: wilaya.id,
        wilayaName: wilaya.nameFr,
        wilayaZrTerritoryId: wilaya.zrTerritoryId,
        baladiaId: _selectedBaladia?.id,
        baladiaName: _selectedBaladia?.nameFr,
        baladiaZrTerritoryId: _selectedBaladia?.zrTerritoryId,
        hubId: _selectedHub?.id,
        hubZrId: _selectedHub?.zrHubId,
        hubName: _selectedHub?.name,
      );
      await ref.read(ordersServiceProvider).createOrder(order);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isAdmin) ...[
              Text('Order Creator',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _EmployeeDropdown(
                selected: _selectedEmployee,
                onChanged: (e) => setState(() => _selectedEmployee = e),
              ),
              const SizedBox(height: 24),
            ],
            Text('Customer Info',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Customer Name *'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration:
                  const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _WilayaDropdown(
              selected: _selectedWilaya,
              onChanged: _onWilayaChanged,
              showError: _triedSubmit && _selectedWilaya == null,
            ),
            if (_deliveryType == DeliveryType.homeDelivery) ...[
              const SizedBox(height: 12),
              _BaladiaDropdown(
                wilayaId: _selectedWilaya?.id,
                selected: _selectedBaladia,
                onChanged: (b) => setState(() => _selectedBaladia = b),
                showError: _triedSubmit && _selectedBaladia == null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Address (street, optional)'),
                textCapitalization: TextCapitalization.sentences,
              ),
            ] else ...[
              const SizedBox(height: 12),
              _HubDropdown(
                wilayaId: _selectedWilaya?.id,
                selected: _selectedHub,
                onChanged: (h) => setState(() => _selectedHub = h),
                showError: _triedSubmit && _selectedHub == null,
              ),
            ],
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 16),
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
                          style:
                              TextStyle(color: AppColors.textSecondary),
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
                  priceCtrl: _priceCtrl,
                  onProductSelected: _onProductSelected,
                  onAdd: _addToCart,
                  onRemove: _removeFromCart,
                  subtotal: _subtotal,
                  isAdmin: isAdmin,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(isAdmin ? 'Delivery & Discount' : 'Delivery',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: DeliveryType.values.map((type) {
                final selected = _deliveryType == type;
                final isFirst = type == DeliveryType.values.first;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onDeliveryTypeChanged(type),
                    child: Container(
                      margin: EdgeInsets.only(right: isFirst ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type == DeliveryType.pickupPoint
                                ? Icons.store_outlined
                                : Icons.home_outlined,
                            size: 22,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _discountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Discount Amount (DZD)',
                  prefixText: 'DZD ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fees (DZD)',
                  prefixText: 'DZD ',
                  helperText:
                      'Charged to the client, added to net profit.',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            if (_cart.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                        label: 'Products',
                        value: _subtotal),
                    if (_discountAmount > 0)
                      _SummaryRow(
                          label: 'Discount',
                          value: _discountAmount,
                          prefix: '-',
                          valueColor: AppColors.error),
                    if (_fees > 0)
                      _SummaryRow(
                          label: 'Fees',
                          value: _fees,
                          prefix: '+',
                          valueColor: AppColors.success),
                    const Divider(height: 18),
                    _SummaryRow(
                        label: 'Total',
                        value: _total,
                        bold: true),
                  ],
                ),
              ),
            ],
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
                  : const Text('Create Order'),
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
    required this.priceCtrl,
    required this.onProductSelected,
    required this.onAdd,
    required this.onRemove,
    required this.subtotal,
    required this.isAdmin,
  });

  final List<Product> products;
  final Product? selectedProduct;
  final List<_CartItem> cart;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final ValueChanged<Product?> onProductSelected;
  final VoidCallback onAdd;
  final ValueChanged<_CartItem> onRemove;
  final double subtotal;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Compute live marge from current price input
    final costPrice = selectedProduct?.costPrice;
    final liveSalePrice = double.tryParse(priceCtrl.text.trim());
    final double? liveMarge = liveSalePrice != null &&
            costPrice != null &&
            costPrice > 0
        ? ((liveSalePrice - costPrice) / costPrice) * 100
        : (costPrice != null ? selectedProduct?.marginPercent : null);

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
          // Add Product button — above the inputs
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
            isAdmin: isAdmin,
          ),
          if (selectedProduct != null && costPrice != null) ...[
            const SizedBox(height: 6),
            Text(
              'Cost: DZD ${costPrice.toStringAsFixed(2)}'
              '  •  Marge: ${liveMarge != null ? '${liveMarge.toStringAsFixed(1)}%' : '—'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: liveMarge != null && liveMarge < 0
                    ? AppColors.error
                    : AppColors.textSecondary,
                fontWeight: liveMarge != null && liveMarge < 0
                    ? FontWeight.w600
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Quantity + Sale Price row
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
                  controller: priceCtrl,
                  readOnly: !isAdmin,
                  decoration: InputDecoration(
                    labelText: 'Sale Price (DZD)',
                    suffixIcon: !isAdmin
                        ? const Icon(Icons.lock_outline,
                            size: 16, color: AppColors.textHint)
                        : null,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: isAdmin ? null : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          // Added products list
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
                            '${item.qty} × DZD ${item.unitPrice.toStringAsFixed(2)}',
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
                Text('Products Subtotal', style: theme.textTheme.titleMedium),
                Text(
                  'DZD ${subtotal.toStringAsFixed(2)}',
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

class _EmployeeDropdown extends ConsumerWidget {
  const _EmployeeDropdown({
    required this.selected,
    required this.onChanged,
  });
  final Employee? selected;
  final ValueChanged<Employee?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    return employeesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading employees: $e'),
      data: (employees) => DropdownButtonFormField<Employee?>(
        initialValue: selected != null &&
                employees.any((e) => e.id == selected!.id)
            ? selected
            : null,
        decoration: const InputDecoration(
          labelText: 'Created By',
          helperText: 'Leave empty to create the order as yourself',
        ),
        isExpanded: true,
        items: [
          const DropdownMenuItem<Employee?>(
            value: null,
            child: Text('Myself (Admin)'),
          ),
          ...employees.map((e) => DropdownMenuItem<Employee?>(
                value: e,
                child: Text(e.name),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _WilayaDropdown extends ConsumerWidget {
  const _WilayaDropdown({
    required this.selected,
    required this.onChanged,
    required this.showError,
  });
  final Wilaya? selected;
  final ValueChanged<Wilaya?> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wilayasAsync = ref.watch(wilayasStreamProvider);
    return wilayasAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading wilayas: $e'),
      data: (wilayas) => DropdownButtonFormField<Wilaya>(
        initialValue: selected != null &&
                wilayas.any((w) => w.id == selected!.id)
            ? selected
            : null,
        decoration: InputDecoration(
          labelText: 'Wilaya *',
          errorText: showError ? 'Required' : null,
        ),
        isExpanded: true,
        items: wilayas
            .map((w) => DropdownMenuItem(
                  value: w,
                  child: Text('${w.code} — ${w.nameFr}'),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _BaladiaDropdown extends ConsumerWidget {
  const _BaladiaDropdown({
    required this.wilayaId,
    required this.selected,
    required this.onChanged,
    required this.showError,
  });
  final String? wilayaId;
  final Baladia? selected;
  final ValueChanged<Baladia?> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (wilayaId == null) {
      return DropdownButtonFormField<Baladia>(
        items: const [],
        onChanged: null,
        decoration: InputDecoration(
          labelText: 'Baladia *',
          hintText: 'Select a wilaya first',
          errorText: showError ? 'Required' : null,
        ),
      );
    }
    final baladiasAsync = ref.watch(baladiasStreamProvider(wilayaId));
    return baladiasAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading baladias: $e'),
      data: (baladias) => DropdownButtonFormField<Baladia>(
        initialValue: selected != null &&
                baladias.any((b) => b.id == selected!.id)
            ? selected
            : null,
        decoration: InputDecoration(
          labelText: 'Baladia *',
          errorText: showError ? 'Required' : null,
        ),
        isExpanded: true,
        items: baladias
            .map((b) => DropdownMenuItem(value: b, child: Text(b.nameFr)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _HubDropdown extends ConsumerWidget {
  const _HubDropdown({
    required this.wilayaId,
    required this.selected,
    required this.onChanged,
    required this.showError,
  });
  final String? wilayaId;
  final Hub? selected;
  final ValueChanged<Hub?> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (wilayaId == null) {
      return DropdownButtonFormField<Hub>(
        items: const [],
        onChanged: null,
        decoration: InputDecoration(
          labelText: 'Pickup Point *',
          hintText: 'Select a wilaya first',
          errorText: showError ? 'Required' : null,
        ),
      );
    }
    final hubsAsync = ref.watch(hubsStreamProvider(wilayaId));
    return hubsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading pickup points: $e'),
      data: (hubs) => DropdownButtonFormField<Hub>(
        initialValue:
            selected != null && hubs.any((h) => h.id == selected!.id)
                ? selected
                : null,
        decoration: InputDecoration(
          labelText: 'Pickup Point *',
          errorText: showError ? 'Required' : null,
        ),
        isExpanded: true,
        items: hubs
            .map((h) => DropdownMenuItem(value: h, child: Text(h.name)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.prefix = '',
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final double value;
  final String prefix;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          fontSize: bold ? 15 : null,
          color: valueColor,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: style?.copyWith(
                  color: bold ? null : AppColors.textSecondary)),
          Text('$prefix DZD ${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _CartItem {
  const _CartItem(
      {required this.product, required this.qty, required this.unitPrice});
  final Product product;
  final int qty;
  final double unitPrice;
  double get unitCostPrice => product.costPrice ?? 0.0;
  double get subtotal => unitPrice * qty;
  _CartItem copyWith({int? qty, double? unitPrice}) => _CartItem(
      product: product,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice);
}

class _ProductSearchField extends ConsumerStatefulWidget {
  const _ProductSearchField({
    required this.products,
    required this.selectedProduct,
    required this.onSelected,
    required this.isAdmin,
  });
  final List<Product> products;
  final Product? selectedProduct;
  final ValueChanged<Product?> onSelected;
  final bool isAdmin;

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
                if (widget.isAdmin) ...[
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
  late final _nameCtrl =
      TextEditingController(text: widget.initialName);
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _margeCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _saving = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_onSalePriceChanged);
    _margeCtrl.addListener(_onMargeChanged);
    _costCtrl.addListener(_onCostChanged);
  }

  void _onSalePriceChanged() {
    if (_isUpdating) return;
    final sale = double.tryParse(_priceCtrl.text.trim());
    final cost = double.tryParse(_costCtrl.text.trim());
    if (sale != null && cost != null && cost > 0) {
      _isUpdating = true;
      _margeCtrl.text = (((sale - cost) / cost) * 100).toStringAsFixed(1);
      _isUpdating = false;
    }
  }

  void _onMargeChanged() {
    if (_isUpdating) return;
    final marge = double.tryParse(_margeCtrl.text.trim());
    final cost = double.tryParse(_costCtrl.text.trim());
    if (marge != null && cost != null) {
      _isUpdating = true;
      _priceCtrl.text = (cost * (1 + marge / 100)).toStringAsFixed(2);
      _isUpdating = false;
    }
  }

  void _onCostChanged() {
    if (_isUpdating) return;
    final cost = double.tryParse(_costCtrl.text.trim());
    final marge = double.tryParse(_margeCtrl.text.trim());
    if (cost != null && marge != null) {
      _isUpdating = true;
      _priceCtrl.text = (cost * (1 + marge / 100)).toStringAsFixed(2);
      _isUpdating = false;
    } else {
      final sale = double.tryParse(_priceCtrl.text.trim());
      if (cost != null && cost > 0 && sale != null) {
        _isUpdating = true;
        _margeCtrl.text = (((sale - cost) / cost) * 100).toStringAsFixed(1);
        _isUpdating = false;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _margeCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final cost = _costCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_costCtrl.text.trim());
      final product = Product(
        id: '',
        name: _nameCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        costPrice: cost,
        category: _categoryCtrl.text.trim().isEmpty
            ? null
            : _categoryCtrl.text.trim(),
        stockQuantity: 0,
        createdAt: now,
      );
      final id =
          await ref.read(productsServiceProvider).createProduct(product);
      final created = Product(
        id: id,
        name: product.name,
        price: product.price,
        costPrice: product.costPrice,
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Cost Price',
                        prefixText: 'DZD '),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    autofocus: widget.initialName.isNotEmpty,
                    validator: (v) {
                      if (v != null &&
                          v.trim().isNotEmpty &&
                          double.tryParse(v.trim()) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Sale Price *',
                        prefixText: 'DZD '),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _margeCtrl,
              decoration: const InputDecoration(
                labelText: 'Marge (%)',
                suffixText: '%',
                helperText: 'Auto-calculé depuis Cost & Sale Price',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              validator: (v) {
                if (v != null &&
                    v.trim().isNotEmpty &&
                    double.tryParse(v.trim()) == null) {
                  return 'Invalid';
                }
                return null;
              },
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
