import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/supplier.dart';
import '../providers/suppliers_provider.dart';
import '../widgets/supplier_card.dart';

final _phonePattern = RegExp(r'^0[567]\d{8}$');

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key, this.embedded = false});

  /// True when shown as a tab inside the Directory screen — suppresses this
  /// screen's own app bar so it isn't stacked under Directory's.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);

    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Suppliers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(context, ref),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add Supplier'),
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No suppliers yet',
              subtitle: 'Add suppliers to buy products from them per order.',
              action: () => _showFormDialog(context, ref),
              actionLabel: 'Add Supplier',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(suppliersStreamProvider);
              await Future.delayed(const Duration(milliseconds: 600));
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: suppliers.length,
              itemBuilder: (context, i) {
                final supplier = suppliers[i];
                return SupplierCard(
                  supplier: supplier,
                  onTap: () =>
                      _showFormDialog(context, ref, supplier: supplier),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showFormDialog(BuildContext context, WidgetRef ref,
      {Supplier? supplier}) {
    showDialog(
      context: context,
      builder: (ctx) => _SupplierFormDialog(ref: ref, supplier: supplier),
    );
  }
}

class _SupplierFormDialog extends ConsumerStatefulWidget {
  const _SupplierFormDialog({required this.ref, this.supplier});

  final WidgetRef ref;
  final Supplier? supplier;

  @override
  ConsumerState<_SupplierFormDialog> createState() =>
      _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<_SupplierFormDialog> {
  late final _nameCtrl =
      TextEditingController(text: widget.supplier?.name ?? '');
  late final _phoneCtrl =
      TextEditingController(text: widget.supplier?.phone ?? '');

  bool _isLoading = false;
  String? _error;

  bool get _isEditing => widget.supplier != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Enter the supplier\'s name.');
      return;
    }
    if (phone.isNotEmpty && !_phonePattern.hasMatch(phone)) {
      setState(() => _error =
          'Enter a valid phone number — must start with 05, 06, or 07 and have 10 digits.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(suppliersServiceProvider);
      if (_isEditing) {
        await service.updateSupplier(widget.supplier!.id,
            name: name, phone: phone.isEmpty ? null : phone);
      } else {
        final now = DateTime.now();
        await service.createSupplier(Supplier(
          id: const Uuid().v4(),
          name: name,
          phone: phone.isEmpty ? null : phone,
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.delete_outline,
      iconColor: AppColors.error,
      title: 'Delete Supplier',
      message:
          'Remove "${widget.supplier!.name}" from your suppliers? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (ok != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(suppliersServiceProvider)
          .deleteSupplier(widget.supplier!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Supplier' : 'Add Supplier'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              decoration:
                  const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _isLoading ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
