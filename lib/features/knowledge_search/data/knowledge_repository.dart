import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import 'models/article_model.dart';

/// Repository panduan solusi + fallback cache Hive saat offline.
class KnowledgeRepository {
  KnowledgeRepository({SupabaseService? supabase, OfflineCacheService? cache})
      : _supabase = supabase ?? SupabaseService.instance,
        _cache = cache ?? OfflineCacheService.instance;

  final SupabaseService _supabase;
  final OfflineCacheService _cache;
  static const _articlesCacheKey = 'articles_all';
  static const _select = '''
id,commodity_id,category,title,symptoms_keywords,main_cause,quick_solution,
prevention_tips,image_url,view_count,commodities(id,name),
article_recommended_products(usage_note,products(id,name,price,unit,image_url,
stores(store_name,district)))''';

  SupabaseClient get _client => _supabase.client;

  Future<List<CommodityModel>> fetchCommodities({String? category}) async {
    final cacheKey = 'commodities_${category ?? 'all'}';
    try {
      var request = _client.from(AppConstants.tableCommodities).select();
      if (category != null && category.isNotEmpty) {
        request = request.eq('category', category);
      }
      final rows = await request.order('name');
      final data = (rows as List)
          .whereType<Map>()
          .map((row) => CommodityModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      await _cache.saveList(
        AppConstants.boxCommodities,
        cacheKey,
        data.map((item) => item.toJson()).toList(),
      );
      return data;
    } catch (error) {
      if (_isNetworkError(error)) {
        final cached = _cache.getList(AppConstants.boxCommodities, cacheKey);
        return cached.map(CommodityModel.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<ArticleModel>> searchArticles({
    String? query,
    String? category,
    String? commodityId,
  }) async {
    final safeQuery = _safeQuery(query ?? '');
    try {
      var request = _client
          .from(AppConstants.tableArticles)
          .select(_select)
          .eq('is_published', true);

      if (category != null && category.isNotEmpty) {
        request = request.eq('category', category);
      }
      if (commodityId != null && commodityId.isNotEmpty) {
        request = request.eq('commodity_id', commodityId);
      }
      if (safeQuery.isNotEmpty) {
        request = request.or(
          'title.ilike.%$safeQuery%,symptoms_keywords.ilike.%$safeQuery%',
        );
      }

      final rows = await request.order('view_count', ascending: false).limit(100);
      final articles = (rows as List)
          .whereType<Map>()
          .map((row) => ArticleModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      final isBrowsingAll = safeQuery.isEmpty &&
          (category == null || category.isEmpty) &&
          (commodityId == null || commodityId.isEmpty);
      if (isBrowsingAll) {
        await _cache.saveList(
          AppConstants.boxArticles,
          _articlesCacheKey,
          articles.map((item) => item.toJson()).toList(),
        );
      }
      return articles;
    } catch (error) {
      if (_isNetworkError(error)) {
        final cached = _cache.getList(
          AppConstants.boxArticles,
          _articlesCacheKey,
        );
        return cached
            .map(ArticleModel.fromJson)
            .where((article) {
              if (category != null &&
                  category.isNotEmpty &&
                  article.category != category) {
                return false;
              }
              if (commodityId != null &&
                  commodityId.isNotEmpty &&
                  article.commodityId != commodityId) {
                return false;
              }
              return article.matches(safeQuery);
            })
            .toList();
      }
      rethrow;
    }
  }

  Future<void> incrementViewCount(String articleId) async {
    if (articleId.isEmpty) return;
    try {
      await _client.rpc(
        'increment_article_view',
        params: {'p_article_id': articleId},
      );
    } catch (_) {
      // Statistik kunjungan tidak boleh menghalangi pengguna membaca solusi.
    }
  }

  /// Membersihkan karakter yang bisa merusak filter PostgREST.
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
