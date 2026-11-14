import '../../../../core/utils/formatters.dart';

class ProductModel {
  const ProductModel({
    required this.id,
    required this.storeId,
    required this.category,
    required this.name,
    required this.price,
    required this.unit,
    this.sku,
    this.discountPrice,
    this.stock = 0,
    this.weightGrams,
    this.description,
    this.dosageGuide,
    this.activeIngredients,
    this.imageUrl,
    this.soldCount = 0,
    this.isActive = true,
    this.storeName = 'Kios Mitra',
    this.storeDistrict,
    this.storeVillage,
    this.storePhone,
  });

  final String id;
  final String storeId;
  final String category;
  final String name;
  final String? sku;
  final double price;
  final double? discountPrice;
  final int stock;
  final String unit;
  final int? weightGrams;
  final String? description;
  final String? dosageGuide;
  final String? activeIngredients;
  final String? imageUrl;
  final int soldCount;
  final bool isActive;
  final String storeName;
  final String? storeDistrict;
  final String? storeVillage;
  final String? storePhone;

  double get effectivePrice => hasDiscount ? discountPrice! : price;
  bool get hasDiscount =>
      discountPrice != null && discountPrice! > 0 && discountPrice! < price;
  bool get inStock => stock > 0;
  String get formattedPrice => AppFormatters.rupiah(effectivePrice);
  String get formattedOriginalPrice => AppFormatters.rupiah(price);

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final store = json['stores'] is Map
        ? Map<String, dynamic>.from(json['stores'] as Map)
        : const <String, dynamic>{};
    return ProductModel(
      id: json['id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      category: json['category'] as String? ?? 'lainnya',
      name: json['name'] as String? ?? 'Produk',
      sku: json['sku'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      discountPrice: (json['discount_price'] as num?)?.toDouble(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? 'unit',
      weightGrams: (json['weight_grams'] as num?)?.toInt(),
      description: json['description'] as String?,
      dosageGuide: json['dosage_guide'] as String?,
      activeIngredients: json['active_ingredients'] as String?,
      imageUrl: json['image_url'] as String?,
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      storeName: (store['store_name'] as String?) ??
          (json['store_name'] as String?) ??
          'Kios Mitra',
      storeDistrict: (store['district'] as String?) ??
          (json['store_district'] as String?),
      storeVillage:
          (store['village'] as String?) ?? (json['store_village'] as String?),
      storePhone: (store['phone_whatsapp'] as String?) ??
          (json['store_phone'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'category': category,
        'name': name,
        'sku': sku,
        'price': price,
        'discount_price': discountPrice,
        'stock': stock,
        'unit': unit,
        'weight_grams': weightGrams,
        'description': description,
        'dosage_guide': dosageGuide,
        'active_ingredients': activeIngredients,
        'image_url': imageUrl,
        'sold_count': soldCount,
        'is_active': isActive,
        'stores': {
          'store_name': storeName,
          'district': storeDistrict,
          'village': storeVillage,
          'phone_whatsapp': storePhone,
        },
      };
}

class CartItemModel {
  const CartItemModel({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.product,
  });

  final String id;
  final String productId;
  final int quantity;
  final ProductModel product;

  double get subtotal => product.effectivePrice * quantity;
  String get formattedSubtotal => AppFormatters.rupiah(subtotal);

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['products'] is Map
        ? Map<String, dynamic>.from(json['products'] as Map)
        : const <String, dynamic>{};
    return CartItemModel(
      id: json['id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      product: ProductModel.fromJson(product),
    );
  }
}

class OrderItemModel {
  const OrderItemModel({
    required this.productId,
    required this.quantity,
    required this.productName,
    required this.price,
    required this.unit,
    this.imageUrl,
  });

  final String productId;
  final int quantity;
  final String productName;
  final double price;
  final String unit;
  final String? imageUrl;

  double get subtotal => price * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['products'] is Map
        ? Map<String, dynamic>.from(json['products'] as Map)
        : const <String, dynamic>{};
    return OrderItemModel(
      productId: json['product_id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      productName: product['name'] as String? ?? 'Produk',
      price: (product['price'] as num?)?.toDouble() ?? 0,
      unit: product['unit'] as String? ?? 'unit',
      imageUrl: product['image_url'] as String?,
    );
  }
}

class MarketOrderModel {
  const MarketOrderModel({
    required this.id,
    required this.orderNumber,
    required this.orderStatus,
    required this.grandTotal,
    required this.createdAt,
    this.storeId,
    this.shippingAddress,
    this.cancelReason,
    this.items = const [],
  });

  final String id;
  final String orderNumber;
  final String orderStatus;
  final double grandTotal;
  final DateTime? createdAt;
  final String? storeId;
  final String? shippingAddress;
  final String? cancelReason;
  final List<OrderItemModel> items;

  bool get canCancel =>
      orderStatus == 'pending' || orderStatus == 'menunggu';
  String get formattedTotal => AppFormatters.rupiah(grandTotal);
  String get statusLabel {
    switch (orderStatus) {
      case 'pending':
      case 'menunggu':
        return 'Menunggu Diproses';
      case 'diproses':
        return 'Sedang Dikemas';
      case 'dikirim':
        return 'Sedang Dikirim';
      case 'selesai':
        return 'Selesai';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return orderStatus;
    }
  }

  factory MarketOrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['market_order_items'] as List<dynamic>?) ?? const [];
    return MarketOrderModel(
      id: json['id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '-',
      orderStatus: json['order_status'] as String? ?? 'pending',
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      storeId: json['store_id'] as String?,
      shippingAddress: json['shipping_address'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      items: rawItems
          .whereType<Map>()
          .map((item) =>
              OrderItemModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
