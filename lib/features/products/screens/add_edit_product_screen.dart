import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../providers/products_provider.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  const AddEditProductScreen({super.key, this.productId});
  final String? productId;

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState
    extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _margeCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController(text: '5');
  bool _saving = false;
  bool _loaded = false;
  bool _isUpdating = false;

  bool get _isEdit => widget.productId != null;

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
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _margeCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _loadProduct(Product p) {
    if (_loaded) return;
    _loaded = true;
    _isUpdating = true;
    _nameCtrl.text = p.name;
    _descCtrl.text = p.description ?? '';
    _categoryCtrl.text = p.category ?? '';
    _costCtrl.text = p.costPrice?.toStringAsFixed(2) ?? '';
    _priceCtrl.text = p.price.toStringAsFixed(2);
    if (p.costPrice != null && p.costPrice! > 0) {
      _margeCtrl.text = p.marginPercent!.toStringAsFixed(1);
    }
    _stockCtrl.text = p.stockQuantity.toString();
    _thresholdCtrl.text = p.lowStockThreshold.toString();
    _isUpdating = false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final service = ref.read(productsServiceProvider);
    final price = double.parse(_priceCtrl.text.trim());
    final cost = _costCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_costCtrl.text.trim());
    final stock = int.parse(_stockCtrl.text.trim());
    final threshold = int.tryParse(_thresholdCtrl.text.trim()) ?? 5;

    try {
      if (_isEdit) {
        await service.updateProduct(widget.productId!, {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          'category': _categoryCtrl.text.trim().isEmpty
              ? null
              : _categoryCtrl.text.trim(),
          'price': price,
          'costPrice': cost,
          'stockQuantity': stock,
          'lowStockThreshold': threshold,
          'stockUpdatedAt': Timestamp.now(),
        });
      } else {
        final product = Product(
          id: const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          category: _categoryCtrl.text.trim().isEmpty
              ? null
              : _categoryCtrl.text.trim(),
          price: price,
          costPrice: cost,
          stockQuantity: stock,
          lowStockThreshold: threshold,
          createdAt: DateTime.now(),
        );
        await service.createProduct(product);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save product: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    if (_isEdit) {
      productsAsync.whenData((products) {
        final idx =
            products.indexWhere((p) => p.id == widget.productId);
        if (idx >= 0) _loadProduct(products[idx]);
      });
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Edit Product' : 'New Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                  labelText: 'Category (optional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text('Pricing',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // Cost Price first, then Sale Price (swapped)
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
                      if (v == null || v.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(v.trim()) == null) {
                        return 'Invalid';
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
                helperText:
                    'Edit Marge → recalcule Prix Vente  |  Edit Prix Vente → recalcule Marge',
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
            const SizedBox(height: 24),
            Text('Inventory',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Stock Qty *'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(v.trim()) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _thresholdCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Low Stock At'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
                  : Text(_isEdit ? 'Save Changes' : 'Add Product'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
