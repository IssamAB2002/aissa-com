import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  final String id;
  final DateTime createdAt;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool isAllTime;
  final List<PurchaseListGroup> groups;
  final List<String> sourcePurchaseIds;

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
    );
  }
}
