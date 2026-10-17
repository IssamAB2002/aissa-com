import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../purchase_lists/widgets/generate_pl_dialog.dart';
import '../models/purchase.dart';
import '../providers/purchases_provider.dart';
import '../widgets/multi_status_dialog.dart';
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
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

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

  /// Purchases eligible for bulk status actions (pending only), narrowed by
  /// the active search + date filter.
  List<Purchase> _eligibleForSelect(List<Purchase> purchases) {
    final activeRange = _activeDateRange();
    return purchases.where((p) {
      final matchStatus = p.status == PurchaseStatus.pending;
      final matchSearch = _search.isEmpty ||
          (p.supplierName ?? '').toLowerCase().contains(_search.toLowerCase());
      final matchDate = activeRange == null ||
          (!p.createdAt.isBefore(activeRange.start) &&
              p.createdAt.isBefore(activeRange.end));
      return matchStatus && matchSearch && matchDate;
    }).toList();
  }

  void _toggleSelectAll(List<Purchase> eligible) {
    final allSelected = eligible.isNotEmpty &&
        eligible.every((p) => _selectedIds.contains(p.id));
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(eligible.map((p) => p.id));
      } else {
        _selectedIds.addAll(eligible.map((p) => p.id));
      }
    });
  }

  Future<void> _runBulkAction(MultiPurchaseAction action) async {
    final allPurchases = ref.read(purchasesStreamProvider).valueOrNull ?? [];
    final selected =
        allPurchases.where((p) => _selectedIds.contains(p.id)).toList();
    if (selected.isEmpty) return;

    final actionLabel = action == MultiPurchaseAction.markReceived
        ? 'Mark as Received'
        : 'Confirm Payment';
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.price_check,
      iconColor: AppColors.primary,
      confirmColor: AppColors.primary,
      title: actionLabel,
      message: 'This will update ${selected.length} purchase(s). Continue?',
      confirmLabel: 'Continue',
    );
    if (ok != true || !mounted) return;

    final service = ref.read(purchasesServiceProvider);
    final result = await MultiStatusDialog.show(
      context,
      purchases: selected,
      action: action,
      service: service,
    );
    if (!mounted) return;

    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });

    await AppConfirmDialog.showAlert(
      context,
      icon: result.failed > 0
          ? Icons.error_outline
          : Icons.check_circle_outline,
      iconColor: result.failed > 0 ? AppColors.error : AppColors.success,
      title: 'Update Complete',
      message: '${result.succeeded} purchase(s) updated'
          '${result.failed > 0 ? ', ${result.failed} failed' : ''}.',
    );
  }

  Future<void> _startGeneratePl() async {
    final allPurchases = ref.read(purchasesStreamProvider).valueOrNull ?? [];
    final eligible = allPurchases
        .where((p) => p.status == PurchaseStatus.pending && !p.plGenerated)
        .toList();

    if (eligible.isEmpty) {
      await AppConfirmDialog.showAlert(
        context,
        icon: Icons.info_outline,
        iconColor: AppColors.textHint,
        title: 'Nothing to Generate',
        message: 'No pending purchases are available to add to a Purchase '
            'List right now.',
      );
      return;
    }

    final list =
        await GeneratePlDialog.show(context, eligiblePurchases: eligible);
    if (list == null || !mounted) return;

    final viewIt = await AppConfirmDialog.show(
      context,
      icon: Icons.checklist_outlined,
      iconColor: AppColors.success,
      confirmColor: AppColors.primary,
      title: 'Purchase List Generated',
      message: '${list.totalProducts} product(s) across ${list.supplierCount} '
          'supplier(s). View it now?',
      confirmLabel: 'View',
      cancelLabel: 'Later',
    );
    if (viewIt == true && mounted) {
      context.push('/purchase-lists/${list.id}');
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
      floatingActionButton: _selectMode
          ? (_selectedIds.isEmpty
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'bulk-received',
                      onPressed: () =>
                          _runBulkAction(MultiPurchaseAction.markReceived),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text('Mark Received (${_selectedIds.length})'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'bulk-confirm-payment',
                      onPressed: () =>
                          _runBulkAction(MultiPurchaseAction.confirmPayment),
                      icon: const Icon(Icons.price_check),
                      label: Text('Confirm Payment (${_selectedIds.length})'),
                    ),
                  ],
                ))
          : FloatingActionButton.extended(
              onPressed: () => context.push('/purchases/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Purchase'),
            ),
      body: Column(
        children: [
          _SearchBar(onChanged: (v) => setState(() => _search = v)),
          if (_selectMode)
            _SelectModeHeader(
              allSelected: () {
                final eligible =
                    _eligibleForSelect(purchasesAsync.valueOrNull ?? []);
                return eligible.isNotEmpty &&
                    eligible.every((p) => _selectedIds.contains(p.id));
              }(),
              onSelectAll: () => _toggleSelectAll(
                  _eligibleForSelect(purchasesAsync.valueOrNull ?? [])),
              onCancel: () => setState(() {
                _selectMode = false;
                _selectedIds.clear();
              }),
            )
          else
            _FilterChips(
              selected: _filter,
              onSelected: (s) => setState(() => _filter = s),
              onSelectMode: () => setState(() => _selectMode = true),
              onGeneratePl: _startGeneratePl,
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
                final filtered = _selectMode
                    ? _eligibleForSelect(purchases)
                    : purchases.where((p) {
                        final activeRange = _activeDateRange();
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
                          child: _selectMode
                              ? const EmptyState(
                                  icon: Icons.price_check,
                                  title: 'No purchases to select',
                                  subtitle:
                                      'No pending purchases match this date range.',
                                )
                              : EmptyState(
                                  icon: Icons.shopping_cart_outlined,
                                  title: 'No purchases found',
                                  subtitle:
                                      'Create a purchase to restock products.',
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
                    itemBuilder: (context, i) {
                      final purchase = filtered[i];
                      if (_selectMode) {
                        return PurchaseCard(
                          purchase: purchase,
                          selectionMode: true,
                          isSelected: _selectedIds.contains(purchase.id),
                          onTap: () => setState(() {
                            if (!_selectedIds.remove(purchase.id)) {
                              _selectedIds.add(purchase.id);
                            }
                          }),
                        );
                      }
                      return PurchaseCard(
                        purchase: purchase,
                        onTap: () =>
                            context.push('/purchases/${purchase.id}'),
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
          hintText: 'Search by supplier name...',
          prefixIcon: Icon(Icons.search, color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _SelectModeHeader extends StatelessWidget {
  const _SelectModeHeader({
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
              'Select pending purchases to update',
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelected,
    required this.onSelectMode,
    required this.onGeneratePl,
  });
  final PurchaseStatus? selected;
  final ValueChanged<PurchaseStatus?> onSelected;
  final VoidCallback onSelectMode;
  final VoidCallback onGeneratePl;

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
          const SizedBox(width: 4),
          _ActionChip(
            label: 'Select',
            icon: Icons.checklist,
            onTap: onSelectMode,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            label: 'Generate PL',
            icon: Icons.receipt_long_outlined,
            onTap: onGeneratePl,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
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
