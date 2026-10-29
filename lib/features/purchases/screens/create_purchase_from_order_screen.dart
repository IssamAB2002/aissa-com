import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../orders/models/order.dart';
import '../../orders/providers/orders_provider.dart';
import '../../suppliers/models/supplier.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../../suppliers/widgets/supplier_picker_field.dart';
import '../models/purchase.dart';
import '../providers/purchases_provider.dart';

/// Builds one `Purchase` per distinct supplier chosen across an order's
/// items — Purchase/PurchaseItem stay one-supplier-per-purchase, so items
/// assigned to different suppliers become separate purchase records, all
/// tagged with [Order.id] as their `sourceOrderId`.
class CreatePurchaseFromOrderScreen extends ConsumerWidget {
  const CreatePurchaseFromOrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    return ordersAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (orders) {
        final idx = orders.indexWhere((o) => o.id == orderId);
        if (idx == -1) {
          return const Scaffold(body: Center(child: Text('Order not found')));
        }
        return _CreatePurchaseFromOrderView(
          items: orders[idx].items,
          sourceOrderIds: [orders[idx].id],
        );
      },
    );
  }
}

/// Merges items from several orders (summed by product) and opens the same
/// supplier-assignment view used by the single-order CPO flow — Multi-CPO's
/// entry point.
class CreatePurchaseFromOrdersScreen extends ConsumerWidget {
  const CreatePurchaseFromOrdersScreen({super.key, required this.orderIds});
  final List<String> orderIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    return ordersAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (orders) {
        final selected =
            orders.where((o) => orderIds.contains(o.id)).toList();
        if (selected.isEmpty) {
          return const Scaffold(body: Center(child: Text('Orders not found')));
        }

        final mergedByProduct = <String, OrderItem>{};
        for (final o in selected) {
          for (final item in o.items) {
            final existing = mergedByProduct[item.productId];
            if (existing == null) {
              mergedByProduct[item.productId] = item;
            } else {
              mergedByProduct[item.productId] = OrderItem(
                productId: item.productId,
                productName: item.productName,
                unitPrice: existing.unitPrice,
                quantity: existing.quantity + item.quantity,
                unitCostPrice: existing.unitCostPrice > 0
                    ? existing.unitCostPrice
                    : item.unitCostPrice,
              );
            }
          }
        }

        return _CreatePurchaseFromOrderView(
          items: mergedByProduct.values.toList(),
          sourceOrderIds: selected.map((o) => o.id).toList(),
          title: 'Create Purchase from Orders',
        );
      },
    );
  }
}

class _CreatePurchaseFromOrderView extends ConsumerStatefulWidget {
  const _CreatePurchaseFromOrderView({
    required this.items,
    required this.sourceOrderIds,
    this.title = 'Create Purchase from Order',
  });
  final List<OrderItem> items;
  final List<String> sourceOrderIds;
  final String title;

  @override
  ConsumerState<_CreatePurchaseFromOrderView> createState() =>
      _CreatePurchaseFromOrderViewState();
}

class _CreatePurchaseFromOrderViewState
    extends ConsumerState<_CreatePurchaseFromOrderView> {
  late final List<TextEditingController> _costCtrls = [
    for (final item in widget.items)
      TextEditingController(
        text: item.unitCostPrice > 0
            ? item.unitCostPrice.toStringAsFixed(2)
            : '',
      ),
  ];
  final Map<int, Supplier> _selectedSuppliers = {};
  final Map<String, bool> _receivedBySupplier = {};
  final Map<String, bool> _confirmPaymentBySupplier = {};

  /// Item indices excluded from the purchase entirely — e.g. already
  /// available in stock, so there's nothing to buy for them.
  final Set<int> _excludedIndices = {};

  /// Shared across every drag handle/target on this screen: true while the
  /// currently dragged item is over a valid drop target (or isn't hovering
  /// any target at all), false while it's over a target that can't accept
  /// it. The floating drag feedback chip listens to this to flip red.
  final ValueNotifier<bool> _dragValid = ValueNotifier<bool>(true);

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _costCtrls) {
      c.dispose();
    }
    _dragValid.dispose();
    super.dispose();
  }

  /// Supplier id -> item indices, in ascending item order.
  Map<String, List<int>> get _groups {
    final groups = <String, List<int>>{};
    for (var i = 0; i < widget.items.length; i++) {
      final supplier = _selectedSuppliers[i];
      if (supplier == null) continue;
      groups.putIfAbsent(supplier.id, () => []).add(i);
    }
    return groups;
  }

  /// A drop is valid whenever dropping onto a different item, and at least
  /// one of the two sides (dragged item or drop target) already has a
  /// supplier to copy. If neither has one yet, there's nothing to share.
  bool _canAcceptItemDrop(int fromIndex, int targetIndex) {
    if (fromIndex == targetIndex) return false;
    return _selectedSuppliers[fromIndex] != null ||
        _selectedSuppliers[targetIndex] != null;
  }

  /// Copies whichever side already has a supplier onto the other side.
  /// If the dragged item has one, it wins (matches dragging a known
  /// supplier onto an unassigned item); otherwise the target's supplier is
  /// copied back onto the dragged (unassigned) item.
  void _handleItemDrop(int fromIndex, int targetIndex) {
    final source = _selectedSuppliers[fromIndex];
    final target = _selectedSuppliers[targetIndex];
    if (source == null && target == null) return;
    setState(() {
      if (source != null) {
        _selectedSuppliers[targetIndex] = source;
      } else {
        _selectedSuppliers[fromIndex] = target!;
      }
    });
  }

  void _assignSupplierToIndex(int index, Supplier supplier) {
    setState(() => _selectedSuppliers[index] = supplier);
  }

  /// Excludes/re-includes an item from the purchase (e.g. already in
  /// stock). Excluding clears any supplier assignment it had.
  void _toggleExcluded(int index) {
    setState(() {
      if (!_excludedIndices.add(index)) {
        _excludedIndices.remove(index);
      } else {
        _selectedSuppliers.remove(index);
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_excludedIndices.length == widget.items.length) {
      setState(() => _error =
          'At least one product must be included in the purchase.');
      return;
    }

    for (var i = 0; i < widget.items.length; i++) {
      if (_excludedIndices.contains(i)) continue;
      if (_selectedSuppliers[i] == null) {
        setState(() => _error =
            'Choose a supplier for every included product before continuing.');
        return;
      }
      final cost = double.tryParse(_costCtrls[i].text.trim());
      if (cost == null || cost <= 0) {
        setState(() => _error =
            'Enter a valid cost price for every included product before continuing.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final purchasesService = ref.read(purchasesServiceProvider);
      final groups = _groups;

      for (final entry in groups.entries) {
        final supplierId = entry.key;
        final indices = entry.value;
        final supplier = _selectedSuppliers[indices.first]!;

        final items = indices.map((i) {
          final orderItem = widget.items[i];
          return PurchaseItem(
            productId: orderItem.productId,
            productName: orderItem.productName,
            unitCost: double.parse(_costCtrls[i].text.trim()),
            quantity: orderItem.quantity,
          );
        }).toList();

        final purchase = Purchase(
          id: const Uuid().v4(),
          supplierId: supplierId,
          supplierName: supplier.name,
          items: items,
          total: items.fold(0.0, (s, i) => s + i.subtotal),
          status: PurchaseStatus.pending,
          createdAt: DateTime.now(),
          sourceOrderId: widget.sourceOrderIds.length == 1
              ? widget.sourceOrderIds.first
              : null,
          sourceOrderIds: widget.sourceOrderIds,
        );
        await purchasesService.createPurchase(purchase);

        final confirmPayment = _confirmPaymentBySupplier[supplierId] ?? false;
        final received = _receivedBySupplier[supplierId] ?? false;
        if (confirmPayment) {
          await purchasesService.confirmPayment(purchase);
        } else if (received) {
          await purchasesService.updateStatus(
              purchase, PurchaseStatus.received);
        }
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to create purchase(s): $e';
          _saving = false;
        });
      }
    }
  }

  /// Builds the "Assign Suppliers" cards: items sharing a supplier with
  /// at least one other item collapse into a single [_GroupedSupplierCard];
  /// everything else (unassigned, or the only item on its supplier) keeps
  /// its own full [_OrderItemCard].
  List<Widget> _buildAssignmentCards(List<Supplier> suppliers) {
    final groups = _groups;
    final renderedSupplierIds = <String>{};
    final widgets = <Widget>[];

    for (var i = 0; i < widget.items.length; i++) {
      if (_excludedIndices.contains(i)) {
        widgets.add(_ExcludedItemCard(
          item: widget.items[i],
          onInclude: () => _toggleExcluded(i),
        ));
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      final supplier = _selectedSuppliers[i];
      final members = supplier != null ? groups[supplier.id] : null;

      if (supplier != null && members != null && members.length >= 2) {
        if (renderedSupplierIds.contains(supplier.id)) continue;
        renderedSupplierIds.add(supplier.id);
        widgets.add(_GroupedSupplierCard(
          supplier: supplier,
          memberIndices: members,
          items: widget.items,
          suppliers: suppliers,
          costCtrls: _costCtrls,
          dragValid: _dragValid,
          onSupplierChangedForGroup: (s) => setState(() {
            for (final idx in members) {
              if (s == null) {
                _selectedSuppliers.remove(idx);
              } else {
                _selectedSuppliers[idx] = s;
              }
            }
          }),
          onUngroupItem: (idx) =>
              setState(() => _selectedSuppliers.remove(idx)),
          onExcludeItem: (idx) => _toggleExcluded(idx),
          canAcceptDrag: _canAcceptItemDrop,
          onDropAccepted: _handleItemDrop,
        ));
      } else {
        widgets.add(_OrderItemCard(
          index: i,
          item: widget.items[i],
          suppliers: suppliers,
          selectedSupplier: supplier,
          costCtrl: _costCtrls[i],
          dragValid: _dragValid,
          onSupplierSelected: (s) => setState(() {
            if (s == null) {
              _selectedSuppliers.remove(i);
            } else {
              _selectedSuppliers[i] = s;
            }
          }),
          onExclude: () => _toggleExcluded(i),
          canAcceptDrag: (fromIndex) => _canAcceptItemDrop(fromIndex, i),
          onDropAccepted: (fromIndex) => _handleItemDrop(fromIndex, i),
        ));
      }
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading suppliers: $e')),
        data: (suppliers) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Assign Suppliers',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Choose who each product will be bought from, and confirm its cost price. '
              'Drag the handle on a product onto another to copy its supplier. '
              'Already have some in stock? Exclude them from the purchase.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ..._buildAssignmentCards(suppliers),
            if (_groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Purchases to Create',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final entry in _groups.entries)
                _SupplierPurchaseGroupCard(
                  supplierName: _selectedSuppliers[entry.value.first]!.name,
                  itemCount: entry.value.length,
                  subtotal: entry.value.fold(
                      0.0,
                      (s, i) =>
                          s +
                          (double.tryParse(_costCtrls[i].text.trim()) ?? 0) *
                              widget.items[i].quantity),
                  received: _receivedBySupplier[entry.key] ?? false,
                  confirmPayment:
                      _confirmPaymentBySupplier[entry.key] ?? false,
                  onReceivedChanged: (v) => setState(() {
                    _receivedBySupplier[entry.key] = v;
                    if (!v) _confirmPaymentBySupplier[entry.key] = false;
                  }),
                  onConfirmPaymentChanged: (v) => setState(() {
                    _confirmPaymentBySupplier[entry.key] = v;
                    if (v) _receivedBySupplier[entry.key] = true;
                  }),
                  dragValid: _dragValid,
                  onDropAccepted: (fromIndex) => _assignSupplierToIndex(
                      fromIndex, _selectedSuppliers[entry.value.first]!),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Create Purchase(s)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single unassigned-or-standalone order item: its own supplier
/// picker and cost field, plus a drag handle/target so a supplier can be
/// copied to or from another item by dragging.
class _OrderItemCard extends StatelessWidget {
  const _OrderItemCard({
    required this.index,
    required this.item,
    required this.suppliers,
    required this.selectedSupplier,
    required this.costCtrl,
    required this.onSupplierSelected,
    required this.onExclude,
    required this.canAcceptDrag,
    required this.onDropAccepted,
    required this.dragValid,
  });

  final int index;
  final OrderItem item;
  final List<Supplier> suppliers;
  final Supplier? selectedSupplier;
  final TextEditingController costCtrl;
  final ValueChanged<Supplier?> onSupplierSelected;
  final VoidCallback onExclude;

  /// Whether the item at [fromIndex] (being dragged) may be dropped here.
  final bool Function(int fromIndex) canAcceptDrag;
  /// Called with the dragged item's index once accepted.
  final ValueChanged<int> onDropAccepted;
  final ValueNotifier<bool> dragValid;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final accept = canAcceptDrag(details.data);
        dragValid.value = accept;
        return accept;
      },
      onLeave: (_) => dragValid.value = true,
      onAcceptWithDetails: (details) => onDropAccepted(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty || rejectedData.isNotEmpty;
        final isValidHover = candidateData.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !isHovering
                  ? AppColors.cardBorder
                  : (isValidHover ? AppColors.primary : AppColors.error),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(item.productName,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text('Qty ${item.quantity}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_shopping_cart_outlined,
                        size: 18),
                    tooltip: 'Already in stock — exclude from purchase',
                    color: AppColors.textSecondary,
                    onPressed: onExclude,
                  ),
                  _ItemDragHandle(
                    index: index,
                    supplier: selectedSupplier,
                    dragValid: dragValid,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SupplierPickerField(
                suppliers: suppliers,
                selectedSupplier: selectedSupplier,
                onSelected: onSupplierSelected,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: costCtrl,
                decoration:
                    const InputDecoration(labelText: 'Cost Price (DZD) *'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// An order item excluded from the purchase (already available in stock).
/// Shown collapsed with no supplier/cost fields, since nothing will be
/// bought for it — just a way to bring it back in.
class _ExcludedItemCard extends StatelessWidget {
  const _ExcludedItemCard({required this.item, required this.onInclude});

  final OrderItem item;
  final VoidCallback onInclude;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
                Text(
                  'Qty ${item.quantity} · already in stock, excluded',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onInclude,
            child: const Text('Include'),
          ),
        ],
      ),
    );
  }
}

/// Drag handle shown on every item card, assigned or not. Dragging it onto
/// another item (or a supplier card/group) copies a supplier from
/// whichever side already has one onto the other side. While hovering an
/// invalid target (neither side has a supplier yet), the floating chip
/// turns red and reads "Assign Supplier".
class _ItemDragHandle extends StatelessWidget {
  const _ItemDragHandle({
    required this.index,
    required this.supplier,
    required this.dragValid,
  });

  final int index;
  final Supplier? supplier;
  final ValueNotifier<bool> dragValid;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<int>(
      data: index,
      onDragStarted: () => dragValid.value = true,
      onDragEnd: (_) => dragValid.value = true,
      feedback: Material(
        color: Colors.transparent,
        child: ValueListenableBuilder<bool>(
          valueListenable: dragValid,
          builder: (context, valid, _) {
            if (!valid) {
              return const Chip(
                avatar: Icon(Icons.block, size: 16, color: Colors.white),
                label: Text('Assign Supplier'),
                backgroundColor: AppColors.error,
                labelStyle: TextStyle(color: Colors.white),
              );
            }
            return Chip(
              avatar: const Icon(Icons.local_shipping,
                  size: 16, color: Colors.white),
              label: Text(supplier?.name ?? 'Move item'),
              backgroundColor: AppColors.primary,
              labelStyle: const TextStyle(color: Colors.white),
            );
          },
        ),
      ),
      childWhenDragging:
          Icon(Icons.drag_indicator, color: AppColors.textSecondary.withOpacity(0.3)),
      child: Icon(Icons.drag_indicator, color: AppColors.textSecondary),
    );
  }
}

/// Collapses every order item that shares [supplier] (2+ of them) into one
/// card: a single supplier picker for the whole group, and one compact
/// row per item (still its own drag source/target) — instead of repeating
/// the full item card per product.
class _GroupedSupplierCard extends StatelessWidget {
  const _GroupedSupplierCard({
    required this.supplier,
    required this.memberIndices,
    required this.items,
    required this.suppliers,
    required this.costCtrls,
    required this.onSupplierChangedForGroup,
    required this.onUngroupItem,
    required this.onExcludeItem,
    required this.canAcceptDrag,
    required this.onDropAccepted,
    required this.dragValid,
  });

  final Supplier supplier;
  final List<int> memberIndices;
  final List<OrderItem> items;
  final List<Supplier> suppliers;
  final List<TextEditingController> costCtrls;
  final ValueChanged<Supplier?> onSupplierChangedForGroup;
  final ValueChanged<int> onUngroupItem;
  final ValueChanged<int> onExcludeItem;
  final bool Function(int fromIndex, int targetIndex) canAcceptDrag;
  final void Function(int fromIndex, int targetIndex) onDropAccepted;
  final ValueNotifier<bool> dragValid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${supplier.name} · ${memberIndices.length} products',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SupplierPickerField(
            suppliers: suppliers,
            selectedSupplier: supplier,
            onSelected: onSupplierChangedForGroup,
          ),
          const SizedBox(height: 4),
          for (final idx in memberIndices) ...[
            const Divider(height: 20),
            _GroupedItemRow(
              index: idx,
              item: items[idx],
              supplier: supplier,
              costCtrl: costCtrls[idx],
              onUngroup: () => onUngroupItem(idx),
              onExclude: () => onExcludeItem(idx),
              canAcceptDrag: (fromIndex) => canAcceptDrag(fromIndex, idx),
              onDropAccepted: (fromIndex) => onDropAccepted(fromIndex, idx),
              dragValid: dragValid,
            ),
          ],
        ],
      ),
    );
  }
}

/// One product's row inside a [_GroupedSupplierCard]: name, qty, its own
/// cost price, an "ungroup" action, and its own drag handle/target so
/// per-item drag behavior (copy to/from another item) still works at this
/// granularity.
class _GroupedItemRow extends StatelessWidget {
  const _GroupedItemRow({
    required this.index,
    required this.item,
    required this.supplier,
    required this.costCtrl,
    required this.onUngroup,
    required this.onExclude,
    required this.canAcceptDrag,
    required this.onDropAccepted,
    required this.dragValid,
  });

  final int index;
  final OrderItem item;
  final Supplier supplier;
  final TextEditingController costCtrl;
  final VoidCallback onUngroup;
  final VoidCallback onExclude;
  final bool Function(int fromIndex) canAcceptDrag;
  final ValueChanged<int> onDropAccepted;
  final ValueNotifier<bool> dragValid;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final accept = canAcceptDrag(details.data);
        dragValid.value = accept;
        return accept;
      },
      onLeave: (_) => dragValid.value = true,
      onAcceptWithDetails: (details) => onDropAccepted(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty || rejectedData.isNotEmpty;
        final isValidHover = candidateData.isNotEmpty;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: !isHovering
                  ? Colors.transparent
                  : (isValidHover ? AppColors.primary : AppColors.error),
              width: isHovering ? 2 : 0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName,
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      'Qty ${item.quantity}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: costCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cost (DZD)',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.link_off, size: 18),
                tooltip: 'Remove from group',
                color: AppColors.textSecondary,
                onPressed: onUngroup,
              ),
              IconButton(
                icon:
                    const Icon(Icons.remove_shopping_cart_outlined, size: 18),
                tooltip: 'Already in stock — exclude from purchase',
                color: AppColors.textSecondary,
                onPressed: onExclude,
              ),
              _ItemDragHandle(
                index: index,
                supplier: supplier,
                dragValid: dragValid,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SupplierPurchaseGroupCard extends StatelessWidget {
  const _SupplierPurchaseGroupCard({
    required this.supplierName,
    required this.itemCount,
    required this.subtotal,
    required this.received,
    required this.confirmPayment,
    required this.onReceivedChanged,
    required this.onConfirmPaymentChanged,
    required this.onDropAccepted,
    required this.dragValid,
  });

  final String supplierName;
  final int itemCount;
  final double subtotal;
  final bool received;
  final bool confirmPayment;
  final ValueChanged<bool> onReceivedChanged;
  final ValueChanged<bool> onConfirmPaymentChanged;

  /// Called with the dragged item's index once accepted — the parent then
  /// assigns this group's supplier to that item.
  final ValueChanged<int> onDropAccepted;
  final ValueNotifier<bool> dragValid;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      // This group already has a supplier, so any dragged item can always
      // be accepted here.
      onWillAcceptWithDetails: (details) {
        dragValid.value = true;
        return true;
      },
      onLeave: (_) => dragValid.value = true,
      onAcceptWithDetails: (details) => onDropAccepted(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering ? AppColors.primary : AppColors.cardBorder,
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(supplierName,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '$itemCount item${itemCount != 1 ? 's' : ''}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'DZD ${subtotal.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                value: received,
                onChanged: confirmPayment
                    ? null
                    : (v) => onReceivedChanged(v ?? false),
                title: const Text('Mark as Received'),
                subtitle: const Text('Adds these items to stock immediately'),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              CheckboxListTile(
                value: confirmPayment,
                onChanged: (v) => onConfirmPaymentChanged(v ?? false),
                title: const Text('Confirm Payment'),
                subtitle: const Text('Also records the expense in Finance'),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
        );
      },
    );
  }
}
