import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/purchase.dart';
import '../providers/purchases_provider.dart';
import '../services/purchases_service.dart';
import '../widgets/purchase_card.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.purchaseId});
  final String purchaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesStreamProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;
    return purchasesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (purchases) {
        final idx = purchases.indexWhere((p) => p.id == purchaseId);
        if (idx == -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/purchases');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _PurchaseDetailView(
          purchase: purchases[idx],
          service: ref.read(purchasesServiceProvider),
          isAdmin: isAdmin,
        );
      },
    );
  }
}

class _PurchaseDetailView extends StatelessWidget {
  const _PurchaseDetailView({
    required this.purchase,
    required this.service,
    required this.isAdmin,
  });
  final Purchase purchase;
  final PurchasesService service;
  final bool isAdmin;

  void _onEditTap(BuildContext context) {
    if (purchase.paymentConfirmed) {
      AppConfirmDialog.showAlert(
        context,
        icon: Icons.lock_outline,
        iconColor: AppColors.error,
        title: 'Editing Not Allowed',
        message:
            'This purchase has been paid and received.\nNo further edits are permitted.',
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _EditPurchaseSheet(purchase: purchase, service: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#${purchase.id.substring(0, 8).toUpperCase()}'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Purchase',
              onPressed: () => _onEditTap(context),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await AppConfirmDialog.show(
                context,
                icon: Icons.delete_outline,
                iconColor: AppColors.error,
                title: 'Delete Purchase',
                message: 'This action cannot be undone.',
                confirmLabel: 'Delete',
              );
              if (ok == true && context.mounted) {
                await service.deletePurchase(purchase.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(purchase: purchase),
          const SizedBox(height: 12),
          _ItemsCard(purchase: purchase),
          const SizedBox(height: 12),
          _StatusCard(purchase: purchase, service: service),
          const SizedBox(height: 12),
          _PaymentCard(purchase: purchase, service: service),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Info ───────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.purchase});
  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Purchase Info',
                  style: Theme.of(context).textTheme.titleMedium),
              PurchaseStatusBadge(status: purchase.status),
            ],
          ),
          const SizedBox(height: 12),
          if (purchase.supplierName != null)
            _Row(label: 'Supplier', value: purchase.supplierName!),
          _Row(
            label: 'Date',
            value: DateFormat('MMM d, y · h:mm a')
                .format(purchase.createdAt),
          ),
          if (purchase.notes != null && purchase.notes!.isNotEmpty)
            _Row(label: 'Notes', value: purchase.notes!),
        ],
      ),
    );
  }
}

// ─── Items ──────────────────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.purchase});
  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Divider(),
          ...purchase.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName,
                            style:
                                Theme.of(context).textTheme.bodyLarge),
                        Text(
                          '${item.quantity} × DZD ${item.unitCost.toStringAsFixed(2)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'DZD ${item.subtotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          _FinanceRow(
            label: 'Products Subtotal',
            value: 'DZD ${purchase.itemsSubtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _FinanceRow(
            label: 'Fees',
            value: purchase.fees == 0
                ? '—'
                : '+ DZD ${purchase.fees.toStringAsFixed(2)}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Cost',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                'DZD ${purchase.total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary)),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ─── Status ─────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.purchase, required this.service});
  final Purchase purchase;
  final PurchasesService service;

  @override
  Widget build(BuildContext context) {
    final visibleStatuses = purchase.paymentConfirmed
        ? [PurchaseStatus.received]
        : PurchaseStatus.values;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Update Status',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleStatuses.map((s) {
              final isActive = purchase.status == s;
              return _StatusTabButton(
                label: s.label,
                isActive: isActive,
                onPressed: isActive
                    ? null
                    : () async {
                        try {
                          await service.updateStatus(purchase, s);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to update status: $e')),
                          );
                        }
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Payment ─────────────────────────────────────────────────────────────────

class _PaymentCard extends StatefulWidget {
  const _PaymentCard({required this.purchase, required this.service});
  final Purchase purchase;
  final PurchasesService service;

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _confirming = false;

  Future<void> _onConfirmPressed() async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.payments_outlined,
      iconColor: AppColors.success,
      title: 'Confirm Payment',
      message:
          'Has this purchase been paid to the supplier?\nThis will mark the purchase as received.',
      confirmLabel: 'Yes, Confirm',
      confirmColor: AppColors.success,
      cancelLabel: 'Not Yet',
    );
    if (ok != true || !mounted) return;
    setState(() => _confirming = true);
    try {
      await widget.service.confirmPayment(widget.purchase);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment confirmed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm payment: $e')),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment',
                  style: Theme.of(context).textTheme.titleMedium),
              if (widget.purchase.paymentConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('Confirmed',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success)),
                    ],
                  ),
                ),
            ],
          ),
          if (!widget.purchase.paymentConfirmed) ...[
            const SizedBox(height: 8),
            Text(
              'Payment not yet confirmed. Confirming will add an expense to Finance.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirming ? null : _onConfirmPressed,
                icon: _confirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Confirm Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Edit Purchase Sheet ─────────────────────────────────────────────────────

class _EditPurchaseSheet extends StatefulWidget {
  const _EditPurchaseSheet(
      {required this.purchase, required this.service});
  final Purchase purchase;
  final PurchasesService service;

  @override
  State<_EditPurchaseSheet> createState() => _EditPurchaseSheetState();
}

class _EditPurchaseSheetState extends State<_EditPurchaseSheet> {
  late final _feesCtrl = TextEditingController(
    text: widget.purchase.fees > 0
        ? widget.purchase.fees.toStringAsFixed(2)
        : '',
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _feesCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _feesCtrl.dispose();
    super.dispose();
  }

  double get _fees => double.tryParse(_feesCtrl.text.trim()) ?? 0.0;
  double get _newTotal => widget.purchase.itemsSubtotal + _fees;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateFinance(
        id: widget.purchase.id,
        fees: _fees,
        total: _newTotal,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
          Text('Edit Purchase', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Adjust fees for this purchase.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _feesCtrl,
            decoration: const InputDecoration(
              labelText: 'Fees (DZD)',
              prefixText: 'DZD ',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                _EditSummaryRow(
                  label: 'Products',
                  value:
                      'DZD ${widget.purchase.itemsSubtotal.toStringAsFixed(2)}',
                ),
                if (_fees != 0) ...[
                  const SizedBox(height: 4),
                  _EditSummaryRow(
                    label: 'Fees',
                    value: '+ DZD ${_fees.toStringAsFixed(2)}',
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _EditSummaryRow(
                  label: 'New Total',
                  value: 'DZD ${_newTotal.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSummaryRow extends StatelessWidget {
  const _EditSummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    bold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : null,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

class _StatusTabButton extends StatelessWidget {
  const _StatusTabButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

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
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: AppColors.primary, width: 1.5)
                : Border.all(color: AppColors.cardBorder, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
