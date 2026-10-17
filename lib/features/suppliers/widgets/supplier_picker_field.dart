import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../models/supplier.dart';
import '../providers/suppliers_provider.dart';

final _phonePattern = RegExp(r'^0[567]\d{8}$');

/// Searchable supplier picker with an inline "Create new supplier" action,
/// following the same UX as the product picker in `CreatePurchaseScreen`.
class SupplierPickerField extends ConsumerStatefulWidget {
  const SupplierPickerField({
    super.key,
    required this.suppliers,
    required this.selectedSupplier,
    required this.onSelected,
    this.label = 'Supplier',
  });

  final List<Supplier> suppliers;
  final Supplier? selectedSupplier;
  final ValueChanged<Supplier?> onSelected;
  final String label;

  @override
  ConsumerState<SupplierPickerField> createState() =>
      _SupplierPickerFieldState();
}

class _SupplierPickerFieldState extends ConsumerState<SupplierPickerField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _open = _focus.hasFocus));
    if (widget.selectedSupplier != null) {
      _ctrl.text = widget.selectedSupplier!.name;
    }
  }

  @override
  void didUpdateWidget(SupplierPickerField old) {
    super.didUpdateWidget(old);
    if (widget.selectedSupplier == null && old.selectedSupplier != null) {
      _ctrl.clear();
      _query = '';
    } else if (widget.selectedSupplier != null &&
        widget.selectedSupplier!.id != old.selectedSupplier?.id) {
      _ctrl.text = widget.selectedSupplier!.name;
      _query = '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Supplier> get _filtered => _query.isEmpty
      ? widget.suppliers
      : widget.suppliers
          .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  void _select(Supplier s) {
    _ctrl.text = s.name;
    _query = '';
    _focus.unfocus();
    setState(() => _open = false);
    widget.onSelected(s);
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
      builder: (_) => _QuickCreateSupplierSheet(
        initialName: _query.trim(),
        onCreated: _select,
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
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: const Icon(Icons.keyboard_arrow_down,
                color: AppColors.textSecondary),
          ),
          onChanged: (v) {
            setState(() {
              _query = v;
              _open = true;
              if (widget.selectedSupplier != null) widget.onSelected(null);
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
                        final s = _filtered[i];
                        return InkWell(
                          borderRadius: i == 0
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(8))
                              : BorderRadius.zero,
                          onTap: () => _select(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(s.name,
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
                              : 'Create New Supplier',
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

class _QuickCreateSupplierSheet extends ConsumerStatefulWidget {
  const _QuickCreateSupplierSheet({
    required this.onCreated,
    this.initialName = '',
  });

  final ValueChanged<Supplier> onCreated;
  final String initialName;

  @override
  ConsumerState<_QuickCreateSupplierSheet> createState() =>
      _QuickCreateSupplierSheetState();
}

class _QuickCreateSupplierSheetState
    extends ConsumerState<_QuickCreateSupplierSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final phone = _phoneCtrl.text.trim();
      final supplier = Supplier(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        phone: phone.isEmpty ? null : phone,
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(suppliersServiceProvider).createSupplier(supplier);
      if (mounted) {
        widget.onCreated(supplier);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create supplier: $e')),
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
            Text('New Supplier',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              textCapitalization: TextCapitalization.words,
              autofocus: widget.initialName.isEmpty,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration:
                  const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
              autofocus: widget.initialName.isNotEmpty,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                if (!_phonePattern.hasMatch(value)) {
                  return 'Must start with 05, 06, or 07 and have 10 digits';
                }
                return null;
              },
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
                    : const Text('Create Supplier'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
