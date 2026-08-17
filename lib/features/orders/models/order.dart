import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { pending, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };
}

enum DeliveryType { pickupPoint, homeDelivery }

extension DeliveryTypeX on DeliveryType {
  String get label => switch (this) {
        DeliveryType.pickupPoint => 'Pickup Point',
        DeliveryType.homeDelivery => 'Home Delivery',
      };
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.unitCostPrice = 0.0,
  });

  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double unitCostPrice;

  double get subtotal => unitPrice * quantity;
  double get profit => (unitPrice - unitCostPrice) * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'unitCostPrice': unitCostPrice,
      };

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: m['productId'] as String,
        productName: m['productName'] as String,
        unitPrice: (m['unitPrice'] as num).toDouble(),
        quantity: m['quantity'] as int,
        unitCostPrice: (m['unitCostPrice'] as num? ?? 0.0).toDouble(),
      );
}

class Order {
  const Order({
    required this.id,
    required this.customerName,
    this.customerPhone,
    this.address,
    this.city,
    required this.items,
    required this.status,
    required this.total,
    this.discountAmount = 0.0,
    this.deliveryType = DeliveryType.homeDelivery,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.paymentConfirmed = false,
    this.stockApplied = false,
    this.creatorId,
    this.creatorName,
    this.wilayaId,
    this.wilayaName,
    this.wilayaZrTerritoryId,
    this.baladiaId,
    this.baladiaName,
    this.baladiaZrTerritoryId,
    this.hubId,
    this.hubZrId,
    this.hubName,
    this.zrSubmitted = false,
    this.zrCustomerId,
    this.zrParcelId,
    this.zrTrackingNumber,
    this.zrPostedAt,
    this.zrDeliveryFee = 0.0,
    this.fees = 0.0,
  });

  final String id;
  final String customerName;
  final String? customerPhone;
  final String? address;
  final String? city;
  final List<OrderItem> items;
  final OrderStatus status;
  final double total;
  final double discountAmount;
  final DeliveryType deliveryType;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool paymentConfirmed;
  final bool stockApplied;
  final String? creatorId;
  final String? creatorName;

  // ZR Express shipping refs
  final String? wilayaId;
  final String? wilayaName;
  final String? wilayaZrTerritoryId;
  final String? baladiaId;
  final String? baladiaName;
  final String? baladiaZrTerritoryId;
  final String? hubId;
  final String? hubZrId;
  final String? hubName;
  final bool zrSubmitted;
  final String? zrCustomerId;
  final String? zrParcelId;
  final String? zrTrackingNumber;
  final DateTime? zrPostedAt;
  final double zrDeliveryFee;
  final double fees;

  bool get hasZrShippingData => deliveryType == DeliveryType.homeDelivery
      ? (wilayaZrTerritoryId != null && baladiaZrTerritoryId != null)
      : (wilayaZrTerritoryId != null && hubZrId != null);

  double get itemsSubtotal => items.fold(0.0, (s, i) => s + i.subtotal);
  double get netProfit =>
      items.fold(0.0, (s, i) => s + i.profit) - zrDeliveryFee + fees;

  /// Net income used as the basis for employee reward calculations.
  /// `total` already has the discount netted out. The ZR delivery fee is
  /// only subtracted when the order was actually pushed to ZR Express —
  /// otherwise there's no ZR fee to account for, so `fees` is just added
  /// on top.
  double get rewardBasis =>
      zrSubmitted ? total - zrDeliveryFee + fees : total + fees;

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'city': city,
        'items': items.map((e) => e.toMap()).toList(),
        'status': status.name,
        'total': total,
        'discountAmount': discountAmount,
        'deliveryType': deliveryType.name,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt':
            updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'paymentConfirmed': paymentConfirmed,
        'stockApplied': stockApplied,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'wilayaId': wilayaId,
        'wilayaName': wilayaName,
        'wilayaZrTerritoryId': wilayaZrTerritoryId,
        'baladiaId': baladiaId,
        'baladiaName': baladiaName,
        'baladiaZrTerritoryId': baladiaZrTerritoryId,
        'hubId': hubId,
        'hubZrId': hubZrId,
        'hubName': hubName,
        'zrSubmitted': zrSubmitted,
        'zrCustomerId': zrCustomerId,
        'zrParcelId': zrParcelId,
        'zrTrackingNumber': zrTrackingNumber,
        'zrPostedAt':
            zrPostedAt != null ? Timestamp.fromDate(zrPostedAt!) : null,
        'zrDeliveryFee': zrDeliveryFee,
        'fees': fees,
      };

  factory Order.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      customerName: m['customerName'] as String,
      customerPhone: m['customerPhone'] as String?,
      address: m['address'] as String?,
      city: m['city'] as String?,
      items: (m['items'] as List)
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => OrderStatus.pending,
      ),
      total: (m['total'] as num).toDouble(),
      discountAmount: (m['discountAmount'] as num? ?? 0.0).toDouble(),
      deliveryType: DeliveryType.values.firstWhere(
        (t) => t.name == m['deliveryType'],
        orElse: () => DeliveryType.homeDelivery,
      ),
      notes: m['notes'] as String?,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      paymentConfirmed: m['paymentConfirmed'] as bool? ?? false,
      // Legacy docs lack this field: stock was only ever applied by
      // confirmPayment, so treat confirmed docs as already applied.
      stockApplied: m['stockApplied'] as bool? ??
          (m['paymentConfirmed'] as bool? ?? false),
      creatorId: m['creatorId'] as String?,
      creatorName: m['creatorName'] as String?,
      wilayaId: m['wilayaId'] as String?,
      wilayaName: m['wilayaName'] as String?,
      wilayaZrTerritoryId: m['wilayaZrTerritoryId'] as String?,
      baladiaId: m['baladiaId'] as String?,
      baladiaName: m['baladiaName'] as String?,
      baladiaZrTerritoryId: m['baladiaZrTerritoryId'] as String?,
      hubId: m['hubId'] as String?,
      hubZrId: m['hubZrId'] as String?,
      hubName: m['hubName'] as String?,
      zrSubmitted: m['zrSubmitted'] as bool? ?? false,
      zrCustomerId: m['zrCustomerId'] as String?,
      zrParcelId: m['zrParcelId'] as String?,
      zrTrackingNumber: m['zrTrackingNumber'] as String?,
      zrPostedAt: (m['zrPostedAt'] as Timestamp?)?.toDate(),
      zrDeliveryFee: (m['zrDeliveryFee'] as num? ?? 0.0).toDouble(),
      fees: (m['fees'] as num? ?? 0.0).toDouble(),
    );
  }

  Order copyWith({
    OrderStatus? status,
    String? notes,
    DateTime? updatedAt,
    double? discountAmount,
    double? total,
    double? zrDeliveryFee,
    double? fees,
  }) => Order(
        id: id,
        customerName: customerName,
        customerPhone: customerPhone,
        address: address,
        city: city,
        items: items,
        status: status ?? this.status,
        total: total ?? this.total,
        discountAmount: discountAmount ?? this.discountAmount,
        deliveryType: deliveryType,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        paymentConfirmed: paymentConfirmed,
        stockApplied: stockApplied,
        creatorId: creatorId,
        creatorName: creatorName,
        zrDeliveryFee: zrDeliveryFee ?? this.zrDeliveryFee,
        fees: fees ?? this.fees,
      );
}
