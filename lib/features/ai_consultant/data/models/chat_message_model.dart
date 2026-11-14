import '../../../../core/constants/app_constants.dart';
import '../../../marketplace/data/models/product_model.dart';

class ChatMessageModel {
  ChatMessageModel({
    required this.id,
    required this.sessionId,
    required this.sender,
    required this.createdAt,
    this.messageText,
    this.imageUrl,
    this.audioUrl,
    this.audioTranscript,
    this.recommendedProductIds = const [],
    this.signedImageUrl,
    this.resolvedProducts = const [],
    this.isLocalFallback = false,
  });

  final String id;
  final String sessionId;
  final String sender; // 'user' atau 'ai'
  final String? messageText;

  /// Path privat di bucket `consultations`, bukan URL publik.
  final String? imageUrl;
  final String? audioUrl;
  final String? audioTranscript;
  final List<String> recommendedProductIds;
  final DateTime createdAt;

  /// Runtime only: signed URL sementara untuk menampilkan foto.
  String? signedImageUrl;

  /// Runtime only: produk hasil resolve dari rekomendasi AI.
  List<ProductModel> resolvedProducts;

  /// Runtime only: true bila jawaban berasal dari cache panduan lokal.
  bool isLocalFallback;

  bool get isUser => sender == 'user';
  bool get hasImage => (imageUrl ?? '').isNotEmpty;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final rawIds = json['recommended_product_ids'];
    final ids = <String>[];
    if (rawIds is List) {
      ids.addAll(rawIds.map((id) => id.toString()));
    } else if (rawIds is String && rawIds.isNotEmpty) {
      ids.addAll(rawIds
          .replaceAll(RegExp(r'[\[\]"]'), '')
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty));
    }
    return ChatMessageModel(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      sender: json['sender'] as String? ?? 'ai',
      messageText: json['message_text'] as String?,
      imageUrl: json['image_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      audioTranscript: json['audio_transcript'] as String?,
      recommendedProductIds: ids,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'sender': sender,
        'message_text': messageText,
        'image_url': imageUrl,
        'audio_url': audioUrl,
        'audio_transcript': audioTranscript,
        'recommended_product_ids': recommendedProductIds,
        'created_at': createdAt.toIso8601String(),
      };

  static const table = AppConstants.tableAiMessages;
}
