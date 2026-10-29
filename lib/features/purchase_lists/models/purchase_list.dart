import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a [PurchaseList] came from: the usual date-range aggregation over
/// pending [Purchase]s, or the shortcut that builds one directly from
/// selected Orders (skipping supplier assignment entirely).
enum PurchaseListOrigin { purchase, order }

extension PurchaseListOriginX on PurchaseListOrigin {
  String get label => switch (this) {
        PurchaseListOrigin.purchase => 'Purchase',
        PurchaseListOrigin.order => 'Order',
      };
}

class PurchaseListItem {
  const PurchaseListItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.checked = false,
  });

  final String productId;
  final String productName;
  final int quantity;
  final bool checked;

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'quantity': quantity,
        'checked': checked,
      };

  factory PurchaseListItem.fromMap(String productId, Map<String, dynamic> m) =>
      PurchaseListItem(
        productId: productId,
        productName: m['productName'] as String? ?? '',
        quantity: (m['quantity'] as num? ?? 0).toInt(),
        checked: m['checked'] as bool? ?? false,
      );
}

/// One supplier's section within a [PurchaseList]. [key] is the Firestore
/// map key this group is stored under (the supplier id, or `'unassigned'`
/// for purchases without a saved supplier).
class PurchaseListGroup {
  const PurchaseListGroup({
    required this.key,
    this.supplierId,
    required this.supplierName,
    required this.items,
  });

  final String key;
  final String? supplierId;
  final String supplierName;
  final List<PurchaseListItem> items;

  int get checkedCount => items.where((i) => i.checked).length;
}

class PurchaseList {
  const PurchaseList({
    required this.id,
    required this.createdAt,
    this.rangeStart,
    this.rangeEnd,
    required this.isAllTime,
    required this.groups,
    required this.sourcePurchaseIds,
    this.origin = PurchaseListOrigin.purchase,
    this.sourceOrderIds = const [],
  });

  final String id;
  final DateTime createdAt;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool isAllTime;
  final List<PurchaseListGroup> groups;
  final List<String> sourcePurchaseIds;
  /// Where this list came from. Absent on documents written before this
  /// field existed, which were all generated from Purchases.
  final PurchaseListOrigin origin;
  /// The orders this list was generated directly from, if [origin] is
  /// [PurchaseListOrigin.order]. Empty otherwise.
  final List<String> sourceOrderIds;

  int get totalProducts => groups.fold(0, (s, g) => s + g.items.length);
  int get checkedProducts =>
      groups.fold(0, (s, g) => s + g.checkedCount);
  int get supplierCount => groups.length;

  Map<String, dynamic> toMap() => {
        'createdAt': Timestamp.fromDate(createdAt),
        'rangeStart': rangeStart != null ? Timestamp.fromDate(rangeStart!) : null,
        'rangeEnd': rangeEnd != null ? Timestamp.fromDate(rangeEnd!) : null,
        'isAllTime': isAllTime,
        'supplierOrder': groups.map((g) => g.key).toList(),
        'sourcePurchaseIds': sourcePurchaseIds,
        'origin': origin.name,
        'sourceOrderIds': sourceOrderIds,
        'groups': {
          for (final g in groups)
            g.key: {
              'supplierId': g.supplierId,
              'supplierName': g.supplierName,
              'itemOrder': g.items.map((i) => i.productId).toList(),
              'items': {for (final i in g.items) i.productId: i.toMap()},
            },
        },
      };

  factory PurchaseList.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    final supplierOrder =
        (m['supplierOrder'] as List?)?.cast<String>() ?? const [];
    final groupsMap = (m['groups'] as Map?)?.cast<String, dynamic>() ?? {};

    final groups = supplierOrder.map((key) {
      final g = (groupsMap[key] as Map?)?.cast<String, dynamic>() ?? {};
      final itemOrder = (g['itemOrder'] as List?)?.cast<String>() ?? const [];
      final itemsMap = (g['items'] as Map?)?.cast<String, dynamic>() ?? {};
      return PurchaseListGroup(
        key: key,
        supplierId: g['supplierId'] as String?,
        supplierName: g['supplierName'] as String? ?? 'Unknown',
        items: itemOrder
            .map((pid) => PurchaseListItem.fromMap(
                pid, (itemsMap[pid] as Map?)?.cast<String, dynamic>() ?? {}))
            .toList(),
      );
    }).toList();

    return PurchaseList(
      id: doc.id,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      rangeStart: (m['rangeStart'] as Timestamp?)?.toDate(),
      rangeEnd: (m['rangeEnd'] as Timestamp?)?.toDate(),
      isAllTime: m['isAllTime'] as bool? ?? false,
      groups: groups,
      sourcePurchaseIds:
          (m['sourcePurchaseIds'] as List?)?.cast<String>() ?? const [],
      origin: PurchaseListOrigin.values.firstWhere(
        (o) => o.name == m['origin'],
        orElse: () => PurchaseListOrigin.purchase,
      ),
      sourceOrderIds:
          (m['sourceOrderIds'] as List?)?.cast<String>() ?? const [],
    );
  }
}
