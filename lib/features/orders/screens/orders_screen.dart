import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../employees/models/employee.dart';
import '../../employees/providers/employees_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../purchase_lists/providers/purchase_lists_provider.dart';
import '../../purchases/providers/purchases_provider.dart';
import '../models/order.dart';
import '../providers/orders_provider.dart';
import '../widgets/multi_cp_dialog.dart';
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
  bool _multiCpMode = false;
  bool _multiPlMode = false;
  final Set<String> _selectedForPl = {};
  bool _creatingPl = false;
  bool _multiCpoMode = false;
  final Set<String> _selectedForCpo = {};
  Employee? _employeeFilter;

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

  List<Order> _filteredForMultiZr(List<Order> orders) {
    final activeRange = _activeDateRange();
    return orders.where((o) {
      final matchStatus = (o.status == OrderStatus.pending ||
              o.status == OrderStatus.confirmed) &&
          !o.zrSubmitted &&
          o.hasZrShippingData;
      final matchSearch = _search.isEmpty ||
          o.customerName.toLowerCase().contains(_search.toLowerCase());
      final matchDate = activeRange == null ||
          (!o.createdAt.isBefore(activeRange.start) &&
              o.createdAt.isBefore(activeRange.end));
      return matchStatus && matchSearch && matchDate;
    }).toList();
  }

  /// Orders selectable for the "create PL from Orders" shortcut: not
  /// already pulled into a PL, and with no Purchase created from them yet
  /// (that path already covers their restocking via its own Purchase/PL
  /// flow).
  List<Order> _filteredForMultiPl(List<Order> orders, Set<String> orderIdsWithPurchase) {
    final activeRange = _activeDateRange();
    return orders.where((o) {
      final matchStatus = !o.plGenerated && !orderIdsWithPurchase.contains(o.id);
      final matchSearch = _search.isEmpty ||
          o.customerName.toLowerCase().contains(_search.toLowerCase());
      final matchDate = activeRange == null ||
          (!o.createdAt.isBefore(activeRange.start) &&
              o.createdAt.isBefore(activeRange.end));
      return matchStatus && matchSearch && matchDate;
    }).toList();
  }

  void _toggleSelectAll(List<Order> eligible) {
    final allSelected = eligible.isNotEmpty &&
        eligible.every((o) => _selectedForZr.contains(o.id));
    setState(() {
      if (allSelected) {
        _selectedForZr.removeAll(eligible.map((o) => o.id));
      } else {
        _selectedForZr.addAll(eligible.map((o) => o.id));
      }
    });
  }

  void _togglePlSelectAll(List<Order> eligible) {
    final allSelected = eligible.isNotEmpty &&
        eligible.every((o) => _selectedForPl.contains(o.id));
    setState(() {
      if (allSelected) {
        _selectedForPl.removeAll(eligible.map((o) => o.id));
      } else {
        _selectedForPl.addAll(eligible.map((o) => o.id));
      }
    });
  }

  void _toggleCpoSelectAll(List<Order> eligible) {
    final allSelected = eligible.isNotEmpty &&
        eligible.every((o) => _selectedForCpo.contains(o.id));
    setState(() {
      if (allSelected) {
        _selectedForCpo.removeAll(eligible.map((o) => o.id));
      } else {
        _selectedForCpo.addAll(eligible.map((o) => o.id));
      }
    });
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

  Future<void> _startMultiCp() async {
    final allOrders = ref.read(ordersStreamProvider).valueOrNull ?? [];
    final activeRange = _activeDateRange();
    final candidates = allOrders.where((o) {
      final matchStatus = o.zrSubmitted && !o.paymentConfirmed;
      final matchDate = activeRange == null ||
          (!o.createdAt.isBefore(activeRange.start) &&
              o.createdAt.isBefore(activeRange.end));
      return matchStatus && matchDate;
    }).toList();

    setState(() => _multiCpMode = false);

    if (candidates.isEmpty) {
      await AppConfirmDialog.showAlert(
        context,
        icon: Icons.info_outline,
        iconColor: AppColors.textHint,
        title: 'No Orders to Check',
        message:
            'No ZR-submitted orders awaiting payment confirmation match this date range.',
      );
      return;
    }

    final service = ref.read(ordersServiceProvider);
    final result =
        await MultiCpDialog.show(context, orders: candidates, service: service);
    if (!mounted || result == null) return;

    await AppConfirmDialog.showAlert(
      context,
      icon: result.failed > 0
          ? Icons.error_outline
          : Icons.check_circle_outline,
      iconColor: result.failed > 0 ? AppColors.error : AppColors.success,
      title: 'Multi-CP Complete',
      message: 'Checked ${result.checked} order(s), ${result.eligible} were '
          'delivered, ${result.confirmed} payment(s) confirmed'
          '${result.failed > 0 ? ', ${result.failed} failed' : ''}.',
    );
  }

  Future<void> _startCreatePl() async {
    final allOrders = ref.read(ordersStreamProvider).valueOrNull ?? [];
    final selected =
        allOrders.where((o) => _selectedForPl.contains(o.id)).toList();
    if (selected.isEmpty) return;

    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.checklist_rtl,
      iconColor: AppColors.primary,
      confirmColor: AppColors.primary,
      title: 'Create Purchase List',
      message:
          'This will build a Purchase List from ${selected.length} order(s), '
          'netted against current stock. This cannot be undone.',
      confirmLabel: 'Create',
    );
    if (ok != true || !mounted) return;

    setState(() => _creatingPl = true);
    try {
      final products = ref.read(productsStreamProvider).valueOrNull ?? [];
      final stockByProductId = {
        for (final p in products) p.id: p.stockQuantity,
      };
      final list = await ref.read(purchaseListsServiceProvider).generateFromOrders(
            orders: selected,
            stockByProductId: stockByProductId,
          );
      if (!mounted) return;
      setState(() {
        _multiPlMode = false;
        _selectedForPl.clear();
        _creatingPl = false;
      });
      context.push('/purchase-lists/${list.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _creatingPl = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create Purchase List: $e')),
      );
    }
  }

  void _startCreateCpo() {
    final allOrders = ref.read(ordersStreamProvider).valueOrNull ?? [];
    final selected =
        allOrders.where((o) => _selectedForCpo.contains(o.id)).toList();
    if (selected.isEmpty) return;

    setState(() {
      _multiCpoMode = false;
      _selectedForCpo.clear();
    });
    context.push(
      '/orders/create-purchase-multi',
      extra: selected.map((o) => o.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;
    final orderIdsWithPurchase = ref
        .watch(purchasesStreamProvider)
        .valueOrNull
        ?.expand((p) => p.sourceOrderIds.isNotEmpty
            ? p.sourceOrderIds
            : [if (p.sourceOrderId != null) p.sourceOrderId!])
        .toSet() ??
        const <String>{};

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
      floatingActionButton: _multiCpMode
          ? FloatingActionButton.extended(
              onPressed: _startMultiCp,
              icon: const Icon(Icons.price_check),
              label: const Text('Check ZR Status'),
            )
          : (_multiPlMode
              ? (_selectedForPl.isEmpty || _creatingPl
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: _startCreatePl,
                      icon: const Icon(Icons.checklist_rtl),
                      label: Text('Create PL (${_selectedForPl.length})'),
                    ))
              : (_multiCpoMode
                  ? (_selectedForCpo.isEmpty
                      ? null
                      : FloatingActionButton.extended(
                          onPressed: _startCreateCpo,
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label:
                              Text('Create Purchase (${_selectedForCpo.length})'),
                        ))
                  : (!_multiZrMode
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
                              label:
                                  Text('Start Sending (${_selectedForZr.length})'),
                            ))))),
      body: Column(
        children: [
          _SearchBar(onChanged: (v) => setState(() => _search = v)),
          if (_multiZrMode)
            _MultiZrHeader(
              allSelected: () {
                final eligible =
                    _filteredForMultiZr(ordersAsync.valueOrNull ?? []);
                return eligible.isNotEmpty &&
                    eligible.every((o) => _selectedForZr.contains(o.id));
              }(),
              onSelectAll: () => _toggleSelectAll(
                  _filteredForMultiZr(ordersAsync.valueOrNull ?? [])),
              onCancel: () => setState(() {
                _multiZrMode = false;
                _selectedForZr.clear();
              }),
            )
          else if (_multiCpMode)
            _MultiCpHeader(
              onCancel: () => setState(() => _multiCpMode = false),
            )
          else if (_multiPlMode)
            _MultiPlHeader(
              allSelected: () {
                final eligible = _filteredForMultiPl(
                    ordersAsync.valueOrNull ?? [], orderIdsWithPurchase);
                return eligible.isNotEmpty &&
                    eligible.every((o) => _selectedForPl.contains(o.id));
              }(),
              onSelectAll: () => _togglePlSelectAll(_filteredForMultiPl(
                  ordersAsync.valueOrNull ?? [], orderIdsWithPurchase)),
              onCancel: () => setState(() {
                _multiPlMode = false;
                _selectedForPl.clear();
              }),
            )
          else if (_multiCpoMode)
            _MultiCpoHeader(
              allSelected: () {
                final eligible = _filteredForMultiPl(
                    ordersAsync.valueOrNull ?? [], orderIdsWithPurchase);
                return eligible.isNotEmpty &&
                    eligible.every((o) => _selectedForCpo.contains(o.id));
              }(),
              onSelectAll: () => _toggleCpoSelectAll(_filteredForMultiPl(
                  ordersAsync.valueOrNull ?? [], orderIdsWithPurchase)),
              onCancel: () => setState(() {
                _multiCpoMode = false;
                _selectedForCpo.clear();
              }),
            )
          else
            _FilterChips(
              selected: _filter,
              onSelected: (s) => setState(() => _filter = s),
              showMultiZr: isAdmin,
              onMultiZr: () => setState(() => _multiZrMode = true),
              showMultiCp: isAdmin,
              onMultiCp: () => setState(() => _multiCpMode = true),
              showMultiPl: isAdmin,
              onMultiPl: () => setState(() => _multiPlMode = true),
              showMultiCpo: isAdmin,
              onMultiCpo: () => setState(() => _multiCpoMode = true),
            ),
          _DateFilterChips(
            selected: _dateFilter,
            onSelected: (v) => setState(() => _dateFilter = v),
            onCustom: _pickCustomRange,
          ),
          if (isAdmin &&
              !_multiZrMode &&
              !_multiCpMode &&
              !_multiPlMode &&
              !_multiCpoMode)
            _EmployeeFilterChips(
              selected: _employeeFilter,
              onSelected: (e) => setState(() => _employeeFilter = e),
            ),
          Expanded(
            child: ordersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) {
                final activeRange = _activeDateRange();
                final filtered = _multiZrMode
                    ? _filteredForMultiZr(orders)
                    : (_multiPlMode || _multiCpoMode)
                        ? _filteredForMultiPl(orders, orderIdsWithPurchase)
                        : orders.where((o) {
                        final matchStatus =
                            _filter == null || o.status == _filter;
                        final matchSearch = _search.isEmpty ||
                            o.customerName
                                .toLowerCase()
                                .contains(_search.toLowerCase());
                        final matchDate = activeRange == null ||
                            (!o.createdAt.isBefore(activeRange.start) &&
                                o.createdAt.isBefore(activeRange.end));
                        final matchEmployee = _employeeFilter == null ||
                            o.creatorId == _employeeFilter!.id;
                        return matchStatus &&
                            matchSearch &&
                            matchDate &&
                            matchEmployee;
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
                                      'No pending or confirmed orders with ZR shipping info match this date range.',
                                )
                              : (_multiPlMode || _multiCpoMode)
                                  ? const EmptyState(
                                      icon: Icons.checklist_rtl,
                                      title: 'No orders to use',
                                      subtitle:
                                          'No orders without a Purchase List or Purchase match this date range.',
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
                      if (_multiPlMode) {
                        return OrderCard(
                          order: order,
                          selectionMode: true,
                          isSelected: _selectedForPl.contains(order.id),
                          onTap: () => setState(() {
                            if (!_selectedForPl.remove(order.id)) {
                              _selectedForPl.add(order.id);
                            }
                          }),
                        );
                      }
                      if (_multiCpoMode) {
                        return OrderCard(
                          order: order,
                          selectionMode: true,
                          isSelected: _selectedForCpo.contains(order.id),
                          onTap: () => setState(() {
                            if (!_selectedForCpo.remove(order.id)) {
                              _selectedForCpo.add(order.id);
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
    this.showMultiCp = false,
    this.onMultiCp,
    this.showMultiPl = false,
    this.onMultiPl,
    this.showMultiCpo = false,
    this.onMultiCpo,
  });
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelected;
  final bool showMultiZr;
  final VoidCallback? onMultiZr;
  final bool showMultiCp;
  final VoidCallback? onMultiCp;
  final bool showMultiPl;
  final VoidCallback? onMultiPl;
  final bool showMultiCpo;
  final VoidCallback? onMultiCpo;

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
          if (showMultiCp) ...[
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMultiCp,
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
                      Icon(Icons.price_check,
                          size: 15, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Multi-CP',
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
          if (showMultiPl) ...[
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMultiPl,
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
                      Icon(Icons.checklist_rtl,
                          size: 15, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Multi-PL',
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
          if (showMultiCpo) ...[
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMultiCpo,
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
                      Icon(Icons.shopping_cart_checkout,
                          size: 15, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Multi-CPO',
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

class _MultiCpHeader extends StatelessWidget {
  const _MultiCpHeader({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Pick a date range below, then check ZR delivery status',
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

class _MultiZrHeader extends StatelessWidget {
  const _MultiZrHeader({
    required this.allSelected,
    required this.onSelectAll,
    required this.onCancel,
  });
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Select pending or confirmed orders not yet sent to ZR',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onSelectAll,
            child: Text(allSelected ? 'Deselect All' : 'Select All'),
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

class _MultiPlHeader extends StatelessWidget {
  const _MultiPlHeader({
    required this.allSelected,
    required this.onSelectAll,
    required this.onCancel,
  });
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Select orders to build a Purchase List from',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onSelectAll,
            child: Text(allSelected ? 'Deselect All' : 'Select All'),
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

class _MultiCpoHeader extends StatelessWidget {
  const _MultiCpoHeader({
    required this.allSelected,
    required this.onSelectAll,
    required this.onCancel,
  });
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Select orders to create a Purchase from',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onSelectAll,
            child: Text(allSelected ? 'Deselect All' : 'Select All'),
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

class _EmployeeFilterChips extends ConsumerWidget {
  const _EmployeeFilterChips({
    required this.selected,
    required this.onSelected,
  });
  final Employee? selected;
  final ValueChanged<Employee?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final employees = employeesAsync.valueOrNull ?? [];
    if (employees.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          _TabButton(
            label: 'All Employees',
            isSelected: selected == null,
            onPressed: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...employees.map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabButton(
                label: e.name,
                isSelected: selected?.id == e.id,
                onPressed: () => onSelected(selected?.id == e.id ? null : e),
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
