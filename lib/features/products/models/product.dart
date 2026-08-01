import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    this.category,
    required this.price,
    this.costPrice,
    required this.stockQuantity,
    this.lowStockThreshold = 5,
    this.isActive = true,
    required this.createdAt,
    this.stockUpdatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? category;
  final double price;
  final double? costPrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? stockUpdatedAt;

  bool get isLowStock =>
      stockQuantity <= lowStockThreshold && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;

  double? get marginPercent => costPrice != null && costPrice! > 0
      ? ((price - costPrice!) / costPrice!) * 100
      : null;

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'costPrice': costPrice,
        'stockQuantity': stockQuantity,
        'lowStockThreshold': lowStockThreshold,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'stockUpdatedAt': Timestamp.fromDate(stockUpdatedAt ?? createdAt),
      };

  factory Product.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: m['name'] as String,
      description: m['description'] as String?,
      category: m['category'] as String?,
      price: (m['price'] as num).toDouble(),
      costPrice: m['costPrice'] != null
          ? (m['costPrice'] as num).toDouble()
          : null,
      stockQuantity: m['stockQuantity'] as int,
      lowStockThreshold: m['lowStockThreshold'] as int? ?? 5,
      isActive: m['isActive'] as bool? ?? true,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      stockUpdatedAt: (m['stockUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Product copyWith({
    String? name,
    String? description,
    String? category,
    double? price,
    double? costPrice,
    int? stockQuantity,
    int? lowStockThreshold,
    bool? isActive,
    DateTime? stockUpdatedAt,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        price: price ?? this.price,
        costPrice: costPrice ?? this.costPrice,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        stockUpdatedAt: stockUpdatedAt ?? this.stockUpdatedAt,
      );
}
