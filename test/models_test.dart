import 'package:flutter_test/flutter_test.dart';
import 'package:petani_peternak/features/knowledge_search/data/models/article_model.dart';
import 'package:petani_peternak/features/marketplace/data/models/product_model.dart';

void main() {
  group('ProductModel', () {
    test('memakai harga diskon bila lebih murah', () {
      final product = ProductModel.fromJson({
        'id': 'p1',
        'store_id': 's1',
        'category': 'pupuk',
        'name': 'NPK Mutiara',
        'price': 22000,
        'discount_price': 19000,
        'stock': 4,
        'unit': 'bungkus 1 kg',
        'stores': {'store_name': 'Kios Tani', 'district': 'Sukasada'},
      });

      expect(product.effectivePrice, 19000);
      expect(product.hasDiscount, isTrue);
      expect(product.inStock, isTrue);
      expect(product.storeName, 'Kios Tani');
    });

    test('diskon tidak valid diabaikan', () {
      final product = ProductModel.fromJson({
        'id': 'p1',
        'store_id': 's1',
        'category': 'pakan',
        'name': 'Pakan Ayam',
        'price': 10000,
        'discount_price': 12000,
        'stock': 0,
        'unit': 'karung',
      });

      expect(product.hasDiscount, isFalse);
      expect(product.effectivePrice, 10000);
      expect(product.inStock, isFalse);
      expect(product.storeName, 'Kios Mitra');
    });

    test('subtotal keranjang mengikuti jumlah', () {
      final cart = CartItemModel.fromJson({
        'id': 'c1',
        'product_id': 'p1',
        'quantity': 3,
        'products': {
          'id': 'p1',
          'store_id': 's1',
          'name': 'Pupuk',
          'price': 5000,
          'unit': 'kg',
          'stock': 10,
        },
      });

      expect(cart.subtotal, 15000);
      expect(cart.product.storeName, 'Kios Mitra');
    });
  });

  group('MarketOrderModel', () {
    test('hanya pesanan pending yang bisa dibatalkan', () {
      MarketOrderModel order({required String status}) => MarketOrderModel(
            id: 'o1',
            orderNumber: 'TT-1',
            orderStatus: status,
            grandTotal: 50000,
            createdAt: DateTime(2026, 11, 15),
          );

      expect(order(status: 'pending').canCancel, isTrue);
      expect(order(status: 'diproses').canCancel, isFalse);
      expect(order(status: 'pending').statusLabel, 'Menunggu Diproses');
      expect(order(status: 'dibatalkan').statusLabel, 'Dibatalkan');
    });

    test('item pesanan menampilkan nama produk dari join', () {
      final order = MarketOrderModel.fromJson({
        'id': 'o1',
        'order_number': 'TT-2',
        'order_status': 'selesai',
        'grand_total': 38000,
        'created_at': '2026-11-14T10:00:00Z',
        'market_order_items': [
          {
            'product_id': 'p1',
            'quantity': 1,
            'products': {
              'name': 'Insektisida Abamectin',
              'price': 38000,
              'unit': 'botol 100 ml',
            },
          },
        ],
      });

      expect(order.items.single.productName, 'Insektisida Abamectin');
      expect(order.items.single.subtotal, 38000);
      expect(order.createdAt?.year, 2026);
    });
  });

  group('ArticleModel', () {
    final article = ArticleModel.fromJson({
      'id': 'a1',
      'commodity_id': 'c1',
      'category': 'pertanian',
      'title': 'Daun Cabai Keriting',
      'symptoms_keywords': 'keriting kuning kutu kebul',
      'main_cause': 'Serangan kutu kebul',
      'quick_solution': '1. Buang daun\n2. Semprot abamectin',
      'prevention_tips': 'Pasang perangkap kuning',
      'view_count': 12,
      'commodities': {'id': 'c1', 'name': 'Cabai Rawit'},
      'article_recommended_products': [
        {
          'usage_note': 'Semprot sore hari',
          'products': {
            'id': 'p1',
            'name': 'Abamectin',
            'price': 38000,
            'unit': 'botol',
            'stores': {'store_name': 'Kios Tani', 'district': 'Sukasada'},
          },
        },
      ],
    });

    test('memetakan relasi komoditas dan produk rekomendasi', () {
      expect(article.commodityName, 'Cabai Rawit');
      expect(article.recommendedProducts.single.productId, 'p1');
      expect(article.recommendedProducts.single.usageNote, 'Semprot sore hari');
      expect(article.categoryLabel, 'Tanaman Pangan');
    });

    test('pencarian lokal mencocokkan gejala dan judul', () {
      expect(article.matches('kutu kebul'), isTrue);
      expect(article.matches('CABAI'), isTrue);
      expect(article.matches('sapi'), isFalse);
      expect(article.matches(''), isTrue);
    });

    test('bertahan setelah cache bolak-balik JSON', () {
      final restored = ArticleModel.fromJson(article.toJson());
      expect(restored.title, article.title);
      expect(restored.recommendedProducts.single.productName, 'Abamectin');
      expect(restored.viewCount, 12);
    });
  });
}
