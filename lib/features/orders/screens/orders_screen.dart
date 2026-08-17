import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/order.dart';
import '../providers/orders_provider.dart';
import '../widgets/multi_zr_send_dialog.dart';
import '../widgets/order_card.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _filter;
  String _search = '';
  String _dateFilter = 'all';
  DateTimeRange? _customRange;
  bool _multiZrMode = false;
  final Set<String> _selectedForZr = {};

  DateTimeRange? _activeDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_dateFilter) {
      case 'today':
        return DateTimeRange(
            start: today, end: today.add(const Duration(days: 1)));
      case 'week':
        final ws = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
            start: ws, end: ws.add(const Duration(days: 7)));
      case 'month':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case 'custom':
        return _customRange;
      default:
        return null;
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(ordersStreamProvider);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<bool> _confirmDelete(Order order) async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.delete_outline,
      iconColor: AppColors.error,
      title: 'Delete Order',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (ok != true) return false;

    try {
      await ref.read(ordersServiceProvider).deleteOrder(order.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete order: $e')),
        );
      }
    }
    // Always snap back — the card leaves the list naturally once the
    // orders stream re-emits without the deleted order, rather than
    // playing Dismissible's own slide-away animation.
    return false;
  }

  Future<bool> _confirmStatusToggle(Order order) async {
    final newStatus = order.status == OrderStatus.pending
        ? OrderStatus.delivered
        : OrderStatus.pending;

    final ok = await AppConfirmDialog.show(
      context,
      icon: newStatus == OrderStatus.delivered
          ? Icons.check_circle_outline
          : Icons.hourglass_empty,
      iconColor: newStatus == OrderStatus.delivered
          ? AppColors.statusDelivered
          : AppColors.statusPending,
      confirmColor: newStatus == OrderStatus.delivered
          ? AppColors.statusDelivered
          : AppColors.statusPending,
      title: 'Mark as ${newStatus.label}',
      message:
          "Change this order's status from ${order.status.label} to ${newStatus.label}?",
      confirmLabel: 'Confirm',
    );
    if (ok != true) return false;

    try {
      await ref.read(ordersServiceProvider).updateStatus(order, newStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
    return false;
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange,
    );
    if (range != null && mounted) {
      setState(() {
        _dateFilter = 'custom';
        _customRange = DateTimeRange(
          start: range.start,
          end: range.end.add(const Duration(days: 1)),
        );
      });
    }
  }

  Future<void> _startSending() async {
    final allOrders = ref.read(ordersStreamProvider).valueOrNull ?? [];
    final selected =
        allOrders.where((o) => _selectedForZr.contains(o.id)).toList();
    if (selected.isEmpty) return;

    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.local_shipping_outlined,
      iconColor: AppColors.primary,
      confirmColor: AppColors.primary,
      title: 'Send to ZR Express',
      message:
          'This will submit ${selected.length} order(s) to ZR Express. This cannot be undone.',
      confirmLabel: 'Start Sending',
    );
    if (ok != true || !mounted) return;

    final service = ref.read(ordersServiceProvider);
    final result =
        await MultiZrSendDialog.show(context, orders: selected, service: service);
    if (!mounted) return;

    setState(() {
      _multiZrMode = false;
      _selectedForZr.clear();
    });

    if (result.errorMessage != null) {
      await AppConfirmDialog.showAlert(
        context,
        icon: Icons.error_outline,
        iconColor: AppColors.error,
        title: result.succeeded > 0 ? 'Sending Stopped' : 'Send Failed',
        message: result.succeeded > 0
            ? '${result.succeeded} order(s) sent successfully before an error occurred:\n\n${result.errorMessage}'
            : result.errorMessage!,
      );
    } else {
      await AppConfirmDialog.showAlert(
        context,
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        title: 'Sent to ZR Express',
        message:
            'Successfully sent ${result.succeeded} order(s) to ZR Express.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
      floatingActionButton: !_multiZrMode
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/orders/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Order'),
            )
          : (_selectedForZr.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _startSending,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: Text('Start Sending (${_selectedForZr.length})'),
                )),
      body: Column(
        children: [
          _SearchBar(onChanged: (v) => setState(() => _search = v)),
          if (_multiZrMode)
            _MultiZrHeader(
              onCancel: () => setState(() {
                _multiZrMode = false;
                _selectedForZr.clear();
              }),
            )
          else
            _FilterChips(
              selected: _filter,
              onSelected: (s) => setState(() => _filter = s),
              showMultiZr: isAdmin,
              onMultiZr: () => setState(() => _multiZrMode = true),
            ),
          _DateFilterChips(
            selected: _dateFilter,
            onSelected: (v) => setState(() => _dateFilter = v),
            onCustom: _pickCustomRange,
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) {
                final activeRange = _activeDateRange();
                final eligible = _multiZrMode
                    ? orders.where((o) =>
                        o.status == OrderStatus.pending &&
                        !o.zrSubmitted &&
                        o.hasZrShippingData)
                    : orders;
                final filtered = eligible.where((o) {
                  final matchStatus = _multiZrMode ||
                      _filter == null ||
                      o.status == _filter;
                  final matchSearch = _search.isEmpty ||
                      o.customerName
                          .toLowerCase()
                          .contains(_search.toLowerCase());
                  final matchDate = activeRange == null ||
                      (!o.createdAt.isBefore(activeRange.start) &&
                          o.createdAt.isBefore(activeRange.end));
                  return matchStatus && matchSearch && matchDate;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: _multiZrMode
                              ? const EmptyState(
                                  icon: Icons.local_shipping_outlined,
                                  title: 'No orders to send',
                                  subtitle:
                                      'No pending orders with ZR shipping info match this date range.',
                                )
                              : EmptyState(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'No orders found',
                                  subtitle:
                                      'Create your first order to get started.',
                                  action: () => context.push('/orders/new'),
                                  actionLabel: 'Create Order',
                                ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final order = filtered[i];
                      if (_multiZrMode) {
                        return OrderCard(
                          order: order,
                          selectionMode: true,
                          isSelected: _selectedForZr.contains(order.id),
                          onTap: () => setState(() {
                            if (!_selectedForZr.remove(order.id)) {
                              _selectedForZr.add(order.id);
                            }
                          }),
                        );
                      }
                      return Dismissible(
                        key: ValueKey(order.id),
                        direction: order.status == OrderStatus.cancelled
                            ? DismissDirection.startToEnd
                            : DismissDirection.horizontal,
                        background: const _SwipeBackground(
                          alignment: Alignment.centerLeft,
                          color: AppColors.error,
                          icon: Icons.delete_outline,
                          label: 'Delete',
                        ),
                        secondaryBackground: _SwipeBackground(
                          alignment: Alignment.centerRight,
                          color: order.status == OrderStatus.pending
                              ? AppColors.statusDelivered
                              : AppColors.statusPending,
                          icon: order.status == OrderStatus.pending
                              ? Icons.check_circle_outline
                              : Icons.hourglass_empty,
                          label: order.status == OrderStatus.pending
                              ? 'Mark Delivered'
                              : 'Mark Pending',
                        ),
                        confirmDismiss: (direction) =>
                            direction == DismissDirection.startToEnd
                                ? _confirmDelete(order)
                                : _confirmStatusToggle(order),
                        child: OrderCard(
                          order: order,
                          onTap: () => context.push('/orders/${order.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Search by customer name...',
          prefixIcon: Icon(Icons.search, color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelected,
    this.showMultiZr = false,
    this.onMultiZr,
  });
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelected;
  final bool showMultiZr;
  final VoidCallback? onMultiZr;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          _TabButton(
            label: 'All',
            isSelected: selected == null,
            onPressed: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...OrderStatus.values.map(
            (s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabButton(
                label: s.label,
                isSelected: selected == s,
                onPressed: () =>
                    onSelected(selected == s ? null : s),
              ),
            ),
          ),
          if (showMultiZr) ...[
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMultiZr,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 15, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Multi-ZR',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MultiZrHeader extends StatelessWidget {
  const _MultiZrHeader({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Select pending orders not yet sent to ZR',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _DateFilterChips extends StatelessWidget {
  const _DateFilterChips({
    required this.selected,
    required this.onSelected,
    required this.onCustom,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          _TabButton(
              label: 'All',
              isSelected: selected == 'all',
              onPressed: () => onSelected('all')),
          const SizedBox(width: 8),
          _TabButton(
              label: 'Today',
              isSelected: selected == 'today',
              onPressed: () => onSelected('today')),
          const SizedBox(width: 8),
          _TabButton(
              label: 'This Week',
              isSelected: selected == 'week',
              onPressed: () => onSelected('week')),
          const SizedBox(width: 8),
          _TabButton(
              label: 'This Month',
              isSelected: selected == 'month',
              onPressed: () => onSelected('month')),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCustom,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected == 'custom'
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected == 'custom'
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 17,
                  color: selected == 'custom'
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

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
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : Border.all(color: AppColors.cardBorder, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
