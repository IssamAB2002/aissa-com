import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/order.dart';
import '../providers/orders_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
      body: Column(
        children: [
          _SearchBar(onChanged: (v) => setState(() => _search = v)),
          _FilterChips(
            selected: _filter,
            onSelected: (s) => setState(() => _filter = s),
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
                final filtered = orders.where((o) {
                  final matchStatus =
                      _filter == null || o.status == _filter;
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
                          child: EmptyState(
                            icon: Icons.shopping_bag_outlined,
                            title: 'No orders found',
                            subtitle: 'Create your first order to get started.',
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
                    itemBuilder: (context, i) => OrderCard(
                      order: filtered[i],
                      onTap: () => context.push('/orders/${filtered[i].id}'),
                    ),
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
  const _FilterChips({required this.selected, required this.onSelected});
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelected;

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
