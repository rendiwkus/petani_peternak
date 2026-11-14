import '../../../../core/constants/app_constants.dart';

class CommodityModel {
  const CommodityModel({
    required this.id,
    required this.name,
    required this.category,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String category;
  final String? iconUrl;

  factory CommodityModel.fromJson(Map<String, dynamic> json) {
    return CommodityModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? AppConstants.categoryPertanian,
      iconUrl: json['icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'icon_url': iconUrl,
      };
}

/// Rekomendasi produk yang menempel pada satu artikel solusi.
class ArticleProductRecommendation {
  const ArticleProductRecommendation({
    required this.productId,
    required this.productName,
    required this.price,
    required this.unit,
    required this.storeName,
    this.usageNote,
    this.imageUrl,
    this.storeDistrict,
  });

  final String productId;
  final String productName;
  final double price;
  final String unit;
  final String storeName;
  final String? usageNote;
  final String? imageUrl;
  final String? storeDistrict;

  factory ArticleProductRecommendation.fromJson(Map<String, dynamic> json) {
    final product = _map(json['products']);
    final store = _map(product?['stores']);
    return ArticleProductRecommendation(
      productId: product?['id'] as String? ?? '',
      productName: product?['name'] as String? ?? '',
      price: (product?['price'] as num?)?.toDouble() ?? 0,
      unit: product?['unit'] as String? ?? 'unit',
      imageUrl: product?['image_url'] as String?,
      usageNote: json['usage_note'] as String?,
      storeName: store?['store_name'] as String? ?? 'Kios Mitra',
      storeDistrict: store?['district'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'usage_note': usageNote,
        'products': {
          'id': productId,
          'name': productName,
          'price': price,
          'unit': unit,
          'image_url': imageUrl,
          'stores': {
            'store_name': storeName,
            'district': storeDistrict,
          },
        },
      };

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

/// Artikel panduan penyakit / masalah tani & ternak.
class ArticleModel {
  const ArticleModel({
    required this.id,
    required this.commodityId,
    required this.commodityName,
    required this.category,
    required this.title,
    required this.symptomsKeywords,
    required this.mainCause,
    required this.quickSolution,
    this.preventionTips,
    this.imageUrl,
    this.viewCount = 0,
    this.recommendedProducts = const [],
  });

  final String id;
  final String commodityId;
  final String commodityName;
  final String category;
  final String title;
  final String symptomsKeywords;
  final String mainCause;
  final String quickSolution;
  final String? preventionTips;
  final String? imageUrl;
  final int viewCount;
  final List<ArticleProductRecommendation> recommendedProducts;

  String get categoryLabel =>
      AppConstants.categoryLabels[category] ?? 'Panduan';

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    final commodity = _map(json['commodities']);
    final recommendations =
        (json['article_recommended_products'] as List<dynamic>?) ?? const [];
    return ArticleModel(
      id: json['id'] as String? ?? '',
      commodityId: (json['commodity_id'] as String?) ??
          (commodity?['id'] as String?) ??
          '',
      commodityName: (commodity?['name'] as String?) ??
          (json['commodity_name'] as String?) ??
          'Umum',
      category: json['category'] as String? ?? AppConstants.categoryPertanian,
      title: json['title'] as String? ?? 'Panduan Tani & Ternak',
      symptomsKeywords: json['symptoms_keywords'] as String? ?? '',
      mainCause: json['main_cause'] as String? ?? '',
      quickSolution: json['quick_solution'] as String? ?? '',
      preventionTips: json['prevention_tips'] as String?,
      imageUrl: json['image_url'] as String?,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      recommendedProducts: recommendations
          .whereType<Map>()
          .map((item) => ArticleProductRecommendation.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.productId.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'commodity_id': commodityId,
        'commodities': {
          'id': commodityId,
          'name': commodityName,
        },
        'category': category,
        'title': title,
        'symptoms_keywords': symptomsKeywords,
        'main_cause': mainCause,
        'quick_solution': quickSolution,
        'prevention_tips': preventionTips,
        'image_url': imageUrl,
        'view_count': viewCount,
        'article_recommended_products':
            recommendedProducts.map((item) => item.toJson()).toList(),
      };

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return title.toLowerCase().contains(needle) ||
        symptomsKeywords.toLowerCase().contains(needle) ||
        mainCause.toLowerCase().contains(needle) ||
        commodityName.toLowerCase().contains(needle);
  }

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
