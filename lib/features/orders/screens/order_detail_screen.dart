import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../shipping/providers/shipping_reference_provider.dart';
import '../../shipping/services/zr_client.dart';
import '../models/order.dart';
import '../providers/orders_provider.dart';
import '../services/orders_service.dart';
import '../widgets/order_status_badge.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;
    return ordersAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (orders) {
        final idx = orders.indexWhere((o) => o.id == orderId);
        if (idx == -1) {
          return const Scaffold(
              body: Center(child: Text('Order not found')));
        }
        return _OrderDetailView(
          order: orders[idx],
          service: ref.read(ordersServiceProvider),
          isAdmin: isAdmin,
        );
      },
    );
  }
}

class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView(
      {required this.order, required this.service, required this.isAdmin});
  final Order order;
  final OrdersService service;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#${order.id.substring(0, 8).toUpperCase()}'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Order',
              onPressed: () {
                if (order.paymentConfirmed) {
                  AppConfirmDialog.showAlert(
                    context,
                    icon: Icons.lock_outline,
                    iconColor: AppColors.error,
                    title: 'Editing Not Allowed',
                    message:
                        'This order has been paid and delivered.\nNo further edits are permitted.',
                  );
                  return;
                }
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) =>
                      _EditOrderSheet(order: order, service: service),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await AppConfirmDialog.show(
                context,
                icon: Icons.delete_outline,
                iconColor: AppColors.error,
                title: 'Delete Order',
                message: 'This action cannot be undone.',
                confirmLabel: 'Delete',
              );
              if (ok == true && context.mounted) {
                context.pop();
                service.deleteOrder(order.id);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(order: order, isAdmin: isAdmin),
          const SizedBox(height: 12),
          _ItemsCard(order: order),
          const SizedBox(height: 12),
          _StatusCard(order: order, service: service),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            _ZrExpressCard(order: order, service: service),
          ],
          const SizedBox(height: 12),
          _PaymentCard(
              order: order, service: service, isAdmin: isAdmin),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.order, required this.isAdmin});
  final Order order;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Customer',
                  style: Theme.of(context).textTheme.titleMedium),
              OrderStatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          _Row(label: 'Name', value: order.customerName),
          if (order.customerPhone != null)
            _Row(label: 'Phone', value: order.customerPhone!),
          if (order.address != null && order.address!.isNotEmpty)
            _Row(label: 'Address', value: order.address!),
          if (order.city != null && order.city!.isNotEmpty)
            _Row(label: 'City', value: order.city!),
          _Row(
              label: 'Date',
              value: DateFormat('MMM d, y · h:mm a')
                  .format(order.createdAt)),
          if (order.creatorName != null)
            _Row(label: 'Creator', value: order.creatorName!),
          _DeliveryTypeBadge(type: order.deliveryType),
          if (order.notes != null && order.notes!.isNotEmpty)
            _Row(label: 'Notes', value: order.notes!),
          if (isAdmin) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Profit',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                Text(
                  'DZD ${order.netProfit.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Divider(),
          ...order.items.map(
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
                            style: theme.textTheme.bodyLarge),
                        Text(
                          '${item.quantity} × DZD ${item.unitPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'DZD ${item.subtotal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          // Finance breakdown
          _FinanceRow(
            label: 'Products Subtotal',
            value: 'DZD ${order.itemsSubtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _FinanceRow(
            label: 'Delivery Fees',
            value: order.deliveryPrice == 0
                ? '—'
                : '+ DZD ${order.deliveryPrice.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _FinanceRow(
            label: 'Discount',
            value: order.discountAmount == 0
                ? '—'
                : '- DZD ${order.discountAmount.toStringAsFixed(2)}',
            valueColor:
                order.discountAmount > 0 ? AppColors.error : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: theme.textTheme.titleMedium),
              Text(
                'DZD ${order.total.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
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
  const _FinanceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

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
                color: valueColor,
              ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order, required this.service});
  final Order order;
  final OrdersService service;

  @override
  Widget build(BuildContext context) {
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
            children: (order.paymentConfirmed
                    ? [OrderStatus.delivered]
                    : OrderStatus.values)
                .map((s) {
              final isActive = order.status == s;
              return _StatusTabButton(
                label: s.label,
                isActive: isActive,
                onPressed: isActive
                    ? null
                    : () async {
                        try {
                          await service.updateStatus(order, s);
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

class _ZrExpressCard extends ConsumerStatefulWidget {
  const _ZrExpressCard({required this.order, required this.service});
  final Order order;
  final OrdersService service;

  @override
  ConsumerState<_ZrExpressCard> createState() => _ZrExpressCardState();
}

class _ZrExpressCardState extends ConsumerState<_ZrExpressCard> {
  bool _busy = false;

  Future<void> _send() async {
    final settings = ref.read(zrSettingsStreamProvider).valueOrNull;
    if (settings == null || !settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'ZR Express is not configured yet — set it up in ZR Settings.'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final zrClient = ref.read(zrClientProvider);
      final result = await zrClient.postParcel(
          widget.order, settings.secretKey, settings.tenantId);
      await widget.service.markZrPushed(
        widget.order.id,
        zrParcelId: result.parcelId,
        zrTrackingNumber: result.trackingNumber,
        zrCustomerId: result.customerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.trackingNumber.isNotEmpty
            ? 'Sent to ZR Express. Tracking: ${result.trackingNumber}'
            : 'Sent to ZR Express.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ZrServiceException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.local_shipping_outlined,
      iconColor: AppColors.error,
      title: 'Cancel ZR Shipment',
      message: 'This will delete the parcel from ZR Express and let you '
          'resubmit this order.',
      confirmLabel: 'Cancel Shipment',
    );
    if (ok != true || !mounted) return;

    final settings = ref.read(zrSettingsStreamProvider).valueOrNull;
    if (settings == null || !settings.isConfigured) return;

    setState(() => _busy = true);
    try {
      final zrClient = ref.read(zrClientProvider);
      await zrClient.deleteParcel(
          widget.order, settings.secretKey, settings.tenantId);
      await widget.service.clearZr(widget.order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ZR shipment cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ZrServiceException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ZR Express',
                  style: Theme.of(context).textTheme.titleMedium),
              if (order.zrSubmitted)
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
                      Text('Sent',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success)),
                    ],
                  ),
                ),
            ],
          ),
          if (!order.hasZrShippingData) ...[
            const SizedBox(height: 8),
            Text(
              'This order has no ZR shipping data (created before this feature).',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ] else if (!order.zrSubmitted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Send to ZR Express'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            if (order.zrTrackingNumber != null &&
                order.zrTrackingNumber!.isNotEmpty)
              _Row(label: 'Tracking', value: order.zrTrackingNumber!),
            if (order.zrPostedAt != null)
              _Row(
                label: 'Posted',
                value: DateFormat('MMM d, y · h:mm a')
                    .format(order.zrPostedAt!),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _cancel,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined,
                        size: 18, color: AppColors.error),
                label: const Text('Cancel ZR Shipment',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error)),
              ),
            ),
          ],
        ],
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

class _DeliveryTypeBadge extends StatelessWidget {
  const _DeliveryTypeBadge({required this.type});
  final DeliveryType type;

  @override
  Widget build(BuildContext context) {
    final isPickup = type == DeliveryType.pickupPoint;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text('Delivery',
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPickup
                      ? Icons.store_outlined
                      : Icons.home_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  type.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatefulWidget {
  const _PaymentCard(
      {required this.order, required this.service, required this.isAdmin});
  final Order order;
  final OrdersService service;
  final bool isAdmin;

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
          'Has this customer paid for their order?\nThis will mark the order as delivered.',
      confirmLabel: 'Yes, Confirm',
      confirmColor: AppColors.success,
      cancelLabel: 'Not Yet',
    );
    if (ok != true || !mounted) return;
    await _confirmPayment();
  }

  Future<void> _confirmPayment() async {
    setState(() => _confirming = true);
    try {
      final rewardCredited =
          await widget.service.confirmPayment(widget.order);
      if (!mounted) return;
      final msg = rewardCredited
          ? 'Payment confirmed. Reward credited to employee.'
          : widget.order.creatorId != null
              ? 'Payment confirmed. No reward credited — check benefit % in Reward Settings.'
              : 'Payment confirmed.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
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
              if (widget.order.paymentConfirmed)
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
          if (!widget.order.paymentConfirmed && widget.isAdmin) ...[
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
          if (!widget.order.paymentConfirmed && !widget.isAdmin) ...[
            const SizedBox(height: 8),
            Text('Awaiting payment confirmation.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _EditOrderSheet extends StatefulWidget {
  const _EditOrderSheet({required this.order, required this.service});
  final Order order;
  final OrdersService service;

  @override
  State<_EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<_EditOrderSheet> {
  late final _deliveryCtrl = TextEditingController(
    text: widget.order.deliveryPrice > 0
        ? widget.order.deliveryPrice.toStringAsFixed(2)
        : '',
  );
  late final _discountCtrl = TextEditingController(
    text: widget.order.discountAmount > 0
        ? widget.order.discountAmount.toStringAsFixed(2)
        : '',
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _deliveryCtrl.addListener(_onChanged);
    _discountCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _deliveryCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  double get _deliveryPrice =>
      double.tryParse(_deliveryCtrl.text.trim()) ?? 0.0;
  double get _discountAmount =>
      double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
  double get _newTotal =>
      widget.order.itemsSubtotal + _deliveryPrice - _discountAmount;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateFinance(
        id: widget.order.id,
        deliveryPrice: _deliveryPrice,
        discountAmount: _discountAmount,
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
          Text('Edit Order', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Adjust delivery & discount for this order.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deliveryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Price (DZD)',
                    prefixText: 'DZD ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _discountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Discount (DZD)',
                    prefixText: 'DZD ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
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
                  value: 'DZD ${widget.order.itemsSubtotal.toStringAsFixed(2)}',
                ),
                if (_deliveryPrice != 0) ...[
                  const SizedBox(height: 4),
                  _EditSummaryRow(
                    label: 'Delivery',
                    value: '+ DZD ${_deliveryPrice.toStringAsFixed(2)}',
                  ),
                ],
                if (_discountAmount != 0) ...[
                  const SizedBox(height: 4),
                  _EditSummaryRow(
                    label: 'Discount',
                    value: '- DZD ${_discountAmount.toStringAsFixed(2)}',
                    valueColor: AppColors.error,
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
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : null,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
