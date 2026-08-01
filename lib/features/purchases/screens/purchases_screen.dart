import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/purchase.dart';
import '../providers/purchases_provider.dart';
import '../widgets/purchase_card.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  PurchaseStatus? _filter;
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
    ref.invalidate(purchasesStreamProvider);
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
    final purchasesAsync = ref.watch(purchasesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/purchases/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
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
            child: purchasesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (purchases) {
                final activeRange = _activeDateRange();
                final filtered = purchases.where((p) {
                  final matchStatus =
                      _filter == null || p.status == _filter;
                  final matchSearch = _search.isEmpty ||
                      (p.supplierName ?? '')
                          .toLowerCase()
                          .contains(_search.toLowerCase());
                  final matchDate = activeRange == null ||
                      (!p.createdAt.isBefore(activeRange.start) &&
                          p.createdAt.isBefore(activeRange.end));
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
                            icon: Icons.shopping_cart_outlined,
                            title: 'No purchases found',
                            subtitle: 'Create a purchase to restock products.',
                            action: () => context.push('/purchases/new'),
                            actionLabel: 'Create Purchase',
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => PurchaseCard(
                      purchase: filtered[i],
                      onTap: () =>
                          context.push('/purchases/${filtered[i].id}'),
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
          hintText: 'Search by supplier name...',
          prefixIcon: Icon(Icons.search, color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});
  final PurchaseStatus? selected;
  final ValueChanged<PurchaseStatus?> onSelected;

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
          ...PurchaseStatus.values.map(
            (s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabButton(
                label: s.label,
                isSelected: selected == s,
                onPressed: () => onSelected(selected == s ? null : s),
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
