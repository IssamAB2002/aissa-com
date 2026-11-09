import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../orders/models/order.dart';
import '../../orders/providers/orders_provider.dart';
import '../../purchases/models/purchase.dart';
import '../../purchases/providers/purchases_provider.dart';
import '../models/inventaire_resolution.dart';
import '../providers/inventaire_provider.dart';
import '../widgets/bulk_resolve_dialog.dart';

/// Step 1 of an Inventaire session: every Order still `pending`/`confirmed`
/// and every Purchase still `pending` must be forced to a terminal status
/// before the physical count can start — moving an order to `delivered`
/// decrements stock and a purchase to `received` increments it, via the
/// existing OrdersService/PurchasesService logic, so the count afterwards
/// reflects only real-world drift.
class InventaireResolveScreen extends ConsumerWidget {
  const InventaireResolveScreen({super.key, required this.inventaireId});

  final String inventaireId;

  String _orderLabel(Order o) =>
      'Order #${o.id.substring(0, 8).toUpperCase()} – ${o.customerName}';

  String _purchaseLabel(Purchase p) =>
      'Purchase #${p.id.substring(0, 8).toUpperCase()}'
      '${p.supplierName != null ? ' – ${p.supplierName}' : ''}';

  Future<void> _resolveOrder(
    WidgetRef ref,
    Order order,
    OrderStatus newStatus,
  ) async {
    await ref.read(ordersServiceProvider).updateStatus(order, newStatus);
    await ref.read(inventaireServiceProvider).recordOrderResolution(
          inventaireId,
          InventaireResolution(
            refId: order.id,
            label: _orderLabel(order),
            previousStatus: order.status.label,
            newStatus: newStatus.label,
          ),
        );
  }

  Future<void> _resolvePurchase(
    WidgetRef ref,
    Purchase purchase,
    PurchaseStatus newStatus,
  ) async {
    await ref
        .read(purchasesServiceProvider)
        .updateStatus(purchase, newStatus);
    await ref.read(inventaireServiceProvider).recordPurchaseResolution(
          inventaireId,
          InventaireResolution(
            refId: purchase.id,
            label: _purchaseLabel(purchase),
            previousStatus: purchase.status.label,
            newStatus: newStatus.label,
          ),
        );
  }

  Future<void> _settleOrderPayment(WidgetRef ref, Order order) async {
    await ref.read(ordersServiceProvider).confirmPayment(order);
    await ref.read(inventaireServiceProvider).recordOrderPaymentResolution(
          inventaireId,
          InventaireResolution(
            refId: order.id,
            label: _orderLabel(order),
            previousStatus: 'Unpaid',
            newStatus: 'Paid',
          ),
        );
  }

  Future<void> _settlePurchasePayment(WidgetRef ref, Purchase purchase) async {
    await ref.read(purchasesServiceProvider).confirmPayment(purchase);
    await ref
        .read(inventaireServiceProvider)
        .recordPurchasePaymentResolution(
          inventaireId,
          InventaireResolution(
            refId: purchase.id,
            label: _purchaseLabel(purchase),
            previousStatus: 'Unpaid',
            newStatus: 'Paid',
          ),
        );
  }

  Future<void> _bulkSettleOrderPayments(
    BuildContext context,
    WidgetRef ref,
    List<Order> orders,
  ) async {
    await BulkResolveDialog.show(
      context,
      title: 'Settling order payments',
      items: orders
          .map((o) => BulkResolveItem(
                label: _orderLabel(o),
                action: () => _settleOrderPayment(ref, o),
              ))
          .toList(),
    );
  }

  Future<void> _bulkSettlePurchasePayments(
    BuildContext context,
    WidgetRef ref,
    List<Purchase> purchases,
  ) async {
    await BulkResolveDialog.show(
      context,
      title: 'Settling purchase payments',
      items: purchases
          .map((p) => BulkResolveItem(
                label: _purchaseLabel(p),
                action: () => _settlePurchasePayment(ref, p),
              ))
          .toList(),
    );
  }

  Future<void> _bulkResolveOrders(
    BuildContext context,
    WidgetRef ref,
    List<Order> orders,
    OrderStatus newStatus,
  ) async {
    await BulkResolveDialog.show(
      context,
      title: 'Resolving orders',
      items: orders
          .map((o) => BulkResolveItem(
                label: _orderLabel(o),
                action: () => _resolveOrder(ref, o, newStatus),
              ))
          .toList(),
    );
  }

  Future<void> _bulkResolvePurchases(
    BuildContext context,
    WidgetRef ref,
    List<Purchase> purchases,
    PurchaseStatus newStatus,
  ) async {
    await BulkResolveDialog.show(
      context,
      title: 'Resolving purchases',
      items: purchases
          .map((p) => BulkResolveItem(
                label: _purchaseLabel(p),
                action: () => _resolvePurchase(ref, p, newStatus),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final purchasesAsync = ref.watch(purchasesStreamProvider);

    final openOrders = ordersAsync.valueOrNull
            ?.where((o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.confirmed)
            .toList() ??
        [];
    final openPurchases = purchasesAsync.valueOrNull
            ?.where((p) => p.status == PurchaseStatus.pending)
            .toList() ??
        [];
    final unpaidOrders = ordersAsync.valueOrNull
            ?.where((o) =>
                o.status == OrderStatus.delivered && !o.paymentConfirmed)
            .toList() ??
        [];
    final unpaidPurchases = purchasesAsync.valueOrNull
            ?.where((p) =>
                p.status == PurchaseStatus.received && !p.paymentConfirmed)
            .toList() ??
        [];

    final loading = ordersAsync.isLoading || purchasesAsync.isLoading;
    final canContinue = !loading &&
        openOrders.isEmpty &&
        openPurchases.isEmpty &&
        unpaidOrders.isEmpty &&
        unpaidPurchases.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Resolve Orders & Purchases')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(
                  title: 'Orders (${openOrders.length})',
                  action: openOrders.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => _bulkResolveOrders(
                              context, ref, openOrders, OrderStatus.delivered),
                          child: const Text('Mark all Delivered'),
                        ),
                ),
                if (openOrders.isEmpty)
                  const _AllClearTile(label: 'All orders resolved')
                else
                  ...openOrders.map((o) => _OrderTile(
                        order: o,
                        onDelivered: () =>
                            _resolveOrder(ref, o, OrderStatus.delivered),
                        onCancelled: () =>
                            _resolveOrder(ref, o, OrderStatus.cancelled),
                      )),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Purchases (${openPurchases.length})',
                  action: openPurchases.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => _bulkResolvePurchases(context, ref,
                              openPurchases, PurchaseStatus.received),
                          child: const Text('Mark all Received'),
                        ),
                ),
                if (openPurchases.isEmpty)
                  const _AllClearTile(label: 'All purchases resolved')
                else
                  ...openPurchases.map((p) => _PurchaseTile(
                        purchase: p,
                        onReceived: () =>
                            _resolvePurchase(ref, p, PurchaseStatus.received),
                        onCancelled: () =>
                            _resolvePurchase(ref, p, PurchaseStatus.cancelled),
                      )),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Unpaid Orders (${unpaidOrders.length})',
                  action: unpaidOrders.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => _bulkSettleOrderPayments(
                              context, ref, unpaidOrders),
                          child: const Text('Mark all Paid'),
                        ),
                ),
                if (unpaidOrders.isEmpty)
                  const _AllClearTile(label: 'All order payments settled')
                else
                  ...unpaidOrders.map((o) => _UnpaidOrderTile(
                        order: o,
                        onConfirmPayment: () => _settleOrderPayment(ref, o),
                      )),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Unpaid Purchases (${unpaidPurchases.length})',
                  action: unpaidPurchases.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => _bulkSettlePurchasePayments(
                              context, ref, unpaidPurchases),
                          child: const Text('Mark all Paid'),
                        ),
                ),
                if (unpaidPurchases.isEmpty)
                  const _AllClearTile(label: 'All purchase payments settled')
                else
                  ...unpaidPurchases.map((p) => _UnpaidPurchaseTile(
                        purchase: p,
                        onConfirmPayment: () =>
                            _settlePurchasePayment(ref, p),
                      )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canContinue
                        ? () => context
                            .push('/inventaire/$inventaireId/cost-gate')
                        : null,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (action != null) action!,
      ],
    );
  }
}

class _AllClearTile extends StatelessWidget {
  const _AllClearTile({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: EmptyState(icon: Icons.check_circle_outline, title: label),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.onDelivered,
    required this.onCancelled,
  });

  final Order order;
  final VoidCallback onDelivered;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
                Text('#${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(order.customerName,
                    style: Theme.of(context).textTheme.bodySmall),
                Text(order.status.label,
                    style: const TextStyle(
                        color: AppColors.statusPending, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancelled,
            child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
          ),
          FilledButton(
            onPressed: onDelivered,
            child: const Text('Delivered'),
          ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.purchase,
    required this.onReceived,
    required this.onCancelled,
  });

  final Purchase purchase;
  final VoidCallback onReceived;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
                Text('#${purchase.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(purchase.supplierName ?? 'No supplier',
                    style: Theme.of(context).textTheme.bodySmall),
                Text(purchase.status.label,
                    style: const TextStyle(
                        color: AppColors.statusPending, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancelled,
            child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
          ),
          FilledButton(
            onPressed: onReceived,
            child: const Text('Received'),
          ),
        ],
      ),
    );
  }
}

class _UnpaidOrderTile extends StatelessWidget {
  const _UnpaidOrderTile({
    required this.order,
    required this.onConfirmPayment,
  });

  final Order order;
  final VoidCallback onConfirmPayment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
                Text('#${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(order.customerName,
                    style: Theme.of(context).textTheme.bodySmall),
                const Text('Unpaid',
                    style: TextStyle(
                        color: AppColors.statusPending, fontSize: 12)),
              ],
            ),
          ),
          FilledButton(
            onPressed: onConfirmPayment,
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }
}

class _UnpaidPurchaseTile extends StatelessWidget {
  const _UnpaidPurchaseTile({
    required this.purchase,
    required this.onConfirmPayment,
  });

  final Purchase purchase;
  final VoidCallback onConfirmPayment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
                Text('#${purchase.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(purchase.supplierName ?? 'No supplier',
                    style: Theme.of(context).textTheme.bodySmall),
                const Text('Unpaid',
                    style: TextStyle(
                        color: AppColors.statusPending, fontSize: 12)),
              ],
            ),
          ),
          FilledButton(
            onPressed: onConfirmPayment,
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }
}
