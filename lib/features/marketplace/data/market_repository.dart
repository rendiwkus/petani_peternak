import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import 'models/product_model.dart';

class CheckoutResult {
  const CheckoutResult({
    required this.orderId,
    required this.orderNumber,
    required this.grandTotal,
  });

  final String orderId;
  final String orderNumber;
  final double grandTotal;
}

/// Repository katalog, keranjang, dan pesanan marketplace.
class MarketRepository {
  MarketRepository({SupabaseService? supabase, OfflineCacheService? cache})
      : _supabase = supabase ?? SupabaseService.instance,
        _cache = cache ?? OfflineCacheService.instance;

  final SupabaseService _supabase;
  final OfflineCacheService _cache;
  static const _productsCacheKey = 'products_all';

  SupabaseClient get _client => _supabase.client;

  String get _requireUserId {
    final id = _supabase.currentUserId;
    if (id == null) throw const AuthException('Silakan masuk terlebih dahulu');
    return id;
  }

  Future<List<ProductModel>> fetchProducts({
    String? query,
    String? category,
    String? storeId,
    bool forceRefresh = false,
  }) async {
    final safeQuery = _safeQuery(query ?? '');
    final hasFilter = safeQuery.isNotEmpty ||
        (category != null && category.isNotEmpty) ||
        (storeId != null && storeId.isNotEmpty);

    if (!hasFilter && !forceRefresh) {
      final cached = _cache.getList(
        AppConstants.boxProducts,
        _productsCacheKey,
      );
      if (cached.isNotEmpty) {
        // Tetap segarkan katalog di latar belakang.
        unawaited(_refreshProductsCache());
        return cached.map(ProductModel.fromJson).toList();
      }
    }

    try {
      var request = _client
          .from(AppConstants.tableProducts)
          .select('*,stores(store_name,district,village,phone_whatsapp)')
          .eq('is_active', true);
      if (category != null && category.isNotEmpty) {
        request = request.eq('category', category);
      }
      if (storeId != null && storeId.isNotEmpty) {
        request = request.eq('store_id', storeId);
      }
      if (safeQuery.isNotEmpty) {
        request = request.or(
          'name.ilike.%$safeQuery%,description.ilike.%$safeQuery%',
        );
      }
      final rows = await request.order('sold_count', ascending: false).limit(100);
      final products = (rows as List)
          .whereType<Map>()
          .map((row) => ProductModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      if (!hasFilter) {
        await _cache.saveList(
          AppConstants.boxProducts,
          _productsCacheKey,
          products.map((item) => item.toJson()).toList(),
        );
      }
      return products;
    } catch (error) {
      if (_isNetworkError(error)) {
        final cached = _cache.getList(
          AppConstants.boxProducts,
          _productsCacheKey,
        );
        return cached
            .map(ProductModel.fromJson)
            .where((product) {
              if (category != null &&
                  category.isNotEmpty &&
                  product.category != category) {
                return false;
              }
              if (safeQuery.isEmpty) return true;
              final needle = safeQuery.toLowerCase();
              return product.name.toLowerCase().contains(needle) ||
                  (product.description ?? '').toLowerCase().contains(needle);
            })
            .toList();
      }
      rethrow;
    }
  }

  Future<void> _refreshProductsCache() async {
    try {
      final rows = await _client
          .from(AppConstants.tableProducts)
          .select('*,stores(store_name,district,village,phone_whatsapp)')
          .eq('is_active', true)
          .order('sold_count', ascending: false)
          .limit(100);
      final products = (rows as List)
          .whereType<Map>()
          .map((row) => ProductModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      await _cache.saveList(
        AppConstants.boxProducts,
        _productsCacheKey,
        products.map((item) => item.toJson()).toList(),
      );
    } catch (_) {
      // Cache lama tetap dipakai bila penyegaran gagal.
    }
  }

  Future<ProductModel?> fetchProduct(String id) async {
    final row = await _client
        .from(AppConstants.tableProducts)
        .select('*,stores(store_name,district,village,phone_whatsapp)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ProductModel.fromJson(row);
  }

  Future<List<CartItemModel>> fetchCart() async {
    final userId = _requireUserId;
    final rows = await _client
        .from(AppConstants.tableCart)
        .select('*,products(*,stores(store_name,district,village,phone_whatsapp))')
        .eq('user_id', userId)
        .order('created_at');
    return (rows as List)
        .whereType<Map>()
        .map((row) => CartItemModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> cartCount() async {
    try {
      return (await fetchCart()).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> addToCart({
    required String productId,
    int quantity = 1,
  }) async {
    final userId = _requireUserId;
    if (quantity < 1) throw const AuthException('Jumlah tidak valid');

    final product = await fetchProduct(productId);
    if (product == null || !product.isActive) {
      throw const AuthException('Produk tidak tersedia');
    }
    if (product.stock < 1) {
      throw const AuthException('Stok produk sedang habis');
    }

    final existing = await _client
        .from(AppConstants.tableCart)
        .select('id,quantity')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();

    if (existing == null) {
      await _client.from(AppConstants.tableCart).insert({
        'user_id': userId,
        'product_id': productId,
        'quantity': quantity.clamp(1, product.stock),
      });
    } else {
      final current = (existing['quantity'] as num?)?.toInt() ?? 0;
      final next = (current + quantity).clamp(1, product.stock);
      await _client
          .from(AppConstants.tableCart)
          .update({'quantity': next}).eq('id', existing['id'] as String);
    }
  }

  Future<void> updateCartQuantity(String cartItemId, int quantity) async {
    final userId = _requireUserId;
    if (quantity <= 0) {
      await removeCartItem(cartItemId);
      return;
    }
    await _client
        .from(AppConstants.tableCart)
        .update({'quantity': quantity})
        .eq('id', cartItemId)
        .eq('user_id', userId);
  }

  Future<void> removeCartItem(String cartItemId) async {
    final userId = _requireUserId;
    await _client
        .from(AppConstants.tableCart)
        .delete()
        .eq('id', cartItemId)
        .eq('user_id', userId);
  }

  Future<CheckoutResult> checkout({
    required List<CartItemModel> items,
    required String shippingAddress,
  }) async {
    _requireUserId;
    if (items.isEmpty) throw const AuthException('Keranjang masih kosong');
    final address = shippingAddress.trim();
    if (address.length < 10) {
      throw const AuthException('Alamat pengiriman terlalu singkat');
    }
    final storeIds = items.map((item) => item.product.storeId).toSet();
    if (storeIds.length != 1) {
      throw const AuthException(
        'Satu pesanan hanya bisa dari satu kios. Pisahkan pesanan Anda.',
      );
    }

    // Perhitungan total, validasi stok, dan pemotongan stok dilakukan di
    // fungsi database `create_market_order` agar harga tidak bisa diubah
    // dari aplikasi klien.
    final raw = await _client.rpc(
      'create_market_order',
      params: {
        'p_store_id': storeIds.first,
        'p_items': items
            .map((item) => {
                  'product_id': item.productId,
                  'quantity': item.quantity,
                })
            .toList(),
        'p_shipping_address': address,
      },
    );

    Map<String, dynamic> result = const {};
    if (raw is Map) {
      result = Map<String, dynamic>.from(raw);
    } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
      result = Map<String, dynamic>.from(raw.first as Map);
    }

    final orderId = result['order_id']?.toString() ?? '';
    final orderNumber = result['order_number']?.toString() ?? '';
    final total = (result['grand_total'] as num?)?.toDouble() ?? 0;
    if (orderId.isEmpty || orderNumber.isEmpty) {
      throw const AuthException('Pesanan gagal dibuat. Coba lagi.');
    }

    // Keranjang dibersihkan setelah transaksi server berhasil.
    final cartIds = items.map((item) => item.id).where((id) => id.isNotEmpty);
    if (cartIds.isNotEmpty) {
      try {
        await _client
            .from(AppConstants.tableCart)
            .delete()
            .eq('user_id', _requireUserId)
            .inFilter('id', cartIds.toList());
      } catch (_) {
        // Pesanan sudah aman; kegagalan bersihkan keranjang tidak fatal.
      }
    }

    return CheckoutResult(
      orderId: orderId,
      orderNumber: orderNumber,
      grandTotal: total,
    );
  }

  Future<List<MarketOrderModel>> fetchOrders() async {
    final userId = _requireUserId;
    final rows = await _client
        .from(AppConstants.tableOrders)
        .select('*,market_order_items(product_id,quantity,'
            'products(name,price,unit,image_url))')
        .eq('buyer_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .whereType<Map>()
        .map((row) => MarketOrderModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> cancelOrder(String orderId) async {
    final userId = _requireUserId;
    await _client
        .from(AppConstants.tableOrders)
        .update({
          'order_status': AppConstants.orderDibatalkan,
          'cancel_reason': 'Dibatalkan oleh pembeli',
        })
        .eq('id', orderId)
        .eq('buyer_id', userId)
        .eq('order_status', AppConstants.orderPending);
  }

  static String _safeQuery(String value) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'[,()%*\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return clean.length > 80 ? clean.substring(0, 80) : clean;
  }

  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error.toString().toLowerCase().contains('socket') ||
      error.toString().toLowerCase().contains('network') ||
      error.toString().toLowerCase().contains('failed host lookup');
}
