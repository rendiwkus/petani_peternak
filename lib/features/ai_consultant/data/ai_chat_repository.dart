import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/formatters.dart';
import '../../knowledge_search/data/knowledge_repository.dart';
import '../../marketplace/data/models/product_model.dart';
import 'models/chat_message_model.dart';

class QuotaExceededException implements Exception {
  const QuotaExceededException([
    this.message =
        'Kuota tanya AI hari ini sudah habis. Upgrade ke Pro untuk tanpa batas.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Repository konsultasi AI. Pemanggilan Gemini dilakukan di Edge Function
/// agar API key tidak pernah ikut terpasang di APK.
class AiChatRepository {
  AiChatRepository({
    SupabaseService? supabase,
    KnowledgeRepository? knowledge,
    OfflineCacheService? cache,
  })  : _supabase = supabase ?? SupabaseService.instance,
        _knowledge = knowledge ?? KnowledgeRepository(),
        _cache = cache ?? OfflineCacheService.instance;

  final SupabaseService _supabase;
  final KnowledgeRepository _knowledge;
  final OfflineCacheService _cache;

  /// System prompt dikunci di Edge Function server; klien tidak boleh
  /// mengirim prompt sistem sendiri.
  SupabaseClient get _client => _supabase.client;

  String get _requireUserId {
    final id = _supabase.currentUserId;
    if (id == null) throw const AuthException('Silakan masuk terlebih dahulu');
    return id;
  }

  Future<String> createSession({
    required String title,
    String? commodityId,
  }) async {
    final userId = _requireUserId;
    final cleanTitle = title.trim().isEmpty
        ? 'Konsultasi Tani & Ternak'
        : AppFormatters.truncate(title.trim(), 70);
    final row = await _client
        .from(AppConstants.tableAiSessions)
        .insert({
          'user_id': userId,
          'title': cleanTitle,
          'commodity_id': commodityId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<ChatMessageModel>> fetchMessages(String sessionId) async {
    final rows = await _client
        .from(AppConstants.tableAiMessages)
        .select()
        .eq('session_id', sessionId)
        .order('created_at');
    final messages = (rows as List)
        .whereType<Map>()
        .map((row) =>
            ChatMessageModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    for (final message in messages) {
      if (message.hasImage) {
        message.signedImageUrl =
            await _supabase.createSignedUrl(message.imageUrl!);
      }
      if (message.recommendedProductIds.isNotEmpty) {
        message.resolvedProducts =
            await resolveProducts(message.recommendedProductIds);
      }
    }
    return messages;
  }

  Future<List<ProductModel>> resolveProducts(List<String> ids) async {
    final clean = ids.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (clean.isEmpty) return const [];
    try {
      final rows = await _client
          .from(AppConstants.tableProducts)
          .select('*,stores(store_name,district,village,phone_whatsapp)')
          .inFilter('id', clean)
          .eq('is_active', true);
      return (rows as List)
          .whereType<Map>()
          .map((row) => ProductModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ChatMessageModel> sendMessage({
    required String sessionId,
    required String text,
    Uint8List? imageBytes,
    String? imageMimeType,
    String? imageExtension,
    List<ChatMessageModel> history = const [],
    bool isPro = false,
  }) async {
    final userId = _requireUserId;
    final cleanText = text.trim();
    if (cleanText.isEmpty && imageBytes == null) {
      throw const AuthException('Tulis pertanyaan atau lampirkan foto dulu');
    }

    String? imagePath;
    if (imageBytes != null) {
      imagePath = await _supabase.uploadConsultationImage(
        userId: userId,
        sessionId: sessionId,
        bytes: imageBytes,
        extension: imageExtension ?? 'jpg',
        contentType: imageMimeType ?? 'image/jpeg',
      );
    }

    await _client.from(AppConstants.tableAiMessages).insert({
      'session_id': sessionId,
      'sender': 'user',
      'message_text': cleanText.isEmpty
          ? 'Tolong periksa foto tanaman/ternak ini.'
          : cleanText,
      'image_url': imagePath,
    });

    String answer;
    List<String> recommendedIds = const [];
    var isFallback = false;

    try {
      final response = await _supabase.invokeAiFunction({
        'session_id': sessionId,
        'message': cleanText,
        'image_base64': imageBytes == null ? null : base64Encode(imageBytes),
        'image_mime_type': imageMimeType,
        'history': _historyPayload(history),
      });
      final data = _decodeData(response.data);
      answer = (data['answer'] ?? data['text'] ?? '').toString().trim();
      final rawIds = data['recommended_product_ids'] ?? data['product_ids'];
      if (rawIds is List) {
        recommendedIds = rawIds.map((id) => id.toString()).toList();
      }
      if (answer.isEmpty) {
        throw const AuthException('Jawaban AI kosong');
      }
    } on QuotaExceededException {
      rethrow;
    } on FunctionException catch (error) {
      if (error.status == 429) throw const QuotaExceededException();
      if (error.status == 401 || error.status == 403) {
        throw const AuthException('Sesi Anda berakhir. Silakan masuk lagi.');
      }
      // Layanan AI belum tersedia/offline: pakai panduan lokal yang tersimpan.
      final fallback = await _localFallback(cleanText);
      answer = fallback.$1;
      recommendedIds = fallback.$2;
      isFallback = true;
    } catch (error) {
      if (!_isNetworkError(error)) {
        // Error non-jaringan tetap dicoba dengan panduan lokal agar petani
        // tidak kehilangan akses saat layanan AI sedang bermasalah.
      }
      final fallback = await _localFallback(cleanText);
      answer = fallback.$1;
      recommendedIds = fallback.$2;
      isFallback = true;
    }

    final aiRow = await _client
        .from(AppConstants.tableAiMessages)
        .insert({
          'session_id': sessionId,
          'sender': 'ai',
          'message_text': answer,
          'recommended_product_ids':
              recommendedIds.isEmpty ? null : recommendedIds,
        })
        .select()
        .single();
    final aiMessage = ChatMessageModel.fromJson(aiRow)
      ..isLocalFallback = isFallback
      ..resolvedProducts = await resolveProducts(recommendedIds);

    await _saveLastQuotaHint(isPro);
    return aiMessage;
  }

  Future<(String, List<String>)> _localFallback(String text) async {
    final query = text.trim();
    try {
      final articles = await _knowledge.searchArticles(
        query: query.isEmpty ? null : query,
      );
      if (articles.isNotEmpty) {
        final article = articles.first;
        final buffer = StringBuffer()
          ..writeln('Panduan tersimpan untuk: ${article.title}')
          ..writeln()
          ..writeln('Kemungkinan penyebab:')
          ..writeln(article.mainCause)
          ..writeln()
          ..writeln('Langkah penanganan cepat:')
          ..writeln(article.quickSolution);
        if ((article.preventionTips ?? '').trim().isNotEmpty) {
          buffer
            ..writeln()
            ..writeln('Cara mencegah agar tidak terulang:')
            ..writeln(article.preventionTips);
        }
        buffer
          ..writeln()
          ..writeln('Catatan: ini jawaban dari panduan yang tersimpan di HP. '
              'Saat sinyal kembali, tanyakan lagi untuk analisis AI dan foto.');
        return (
          buffer.toString().trim(),
          article.recommendedProducts.map((p) => p.productId).toList(),
        );
      }
    } catch (_) {
      // Lanjut ke jawaban umum di bawah.
    }
    return (
      'Saya belum menemukan panduan yang persis untuk pertanyaan ini di '
          'penyimpanan HP.\n\nLangkah aman yang bisa dilakukan sekarang:\n'
          '1. Pisahkan tanaman/ternak yang sakit agar tidak menular.\n'
          '2. Catat gejala yang terlihat dan kapan mulai muncul.\n'
          '3. Saat sinyal kembali, kirim foto dari jarak dekat dengan cahaya '
          'terang agar Asisten Tani & Ternak bisa memeriksa lebih tepat.',
      const <String>[],
    );
  }

  Future<void> _saveLastQuotaHint(bool isPro) async {
    if (isPro) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final cachedDate = _cache.getMap(
      AppConstants.boxUserProfile,
      'offline_ai_usage',
    );
    if (cachedDate != null && cachedDate['date'] == today) {
      final count = (cachedDate['count'] as num?)?.toInt() ?? 0;
      await _cache.saveMap(
        AppConstants.boxUserProfile,
        'offline_ai_usage',
        {'date': today, 'count': count + 1},
      );
    } else {
      await _cache.saveMap(
        AppConstants.boxUserProfile,
        'offline_ai_usage',
        {'date': today, 'count': 1},
      );
    }
  }

  List<Map<String, String>> _historyPayload(List<ChatMessageModel> history) {
    final recent = history.length > 8
        ? history.sublist(history.length - 8)
        : history;
    return recent
        .where((message) => (message.messageText ?? '').trim().isNotEmpty)
        .map((message) => {
              'sender': message.sender,
              'text': message.messageText!.trim(),
            })
        .toList();
  }

  static Map<String, dynamic> _decodeData(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return const {};
  }

  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is FunctionsFetchException ||
      error.toString().toLowerCase().contains('socket') ||
      error.toString().toLowerCase().contains('network');
}
