import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/product_recommend_card.dart';
import '../data/knowledge_repository.dart';
import '../data/models/article_model.dart';

/// Halaman baca solusi dengan tombol "Dengarkan Panduan Suara".
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({
    super.key,
    required this.article,
    this.onOpenProduct,
    this.repository,
  });

  final ArticleModel article;
  final ValueChanged<String>? onOpenProduct;
  final KnowledgeRepository? repository;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late final KnowledgeRepository _repository =
      widget.repository ?? KnowledgeRepository();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeaking = false;
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _repository.incrementViewCount(widget.article.id);
  }

  Future<void> _setupTts() async {
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _isSpeaking = false);
      });
      if (mounted) setState(() => _ttsReady = true);
    } catch (_) {
      if (mounted) setState(() => _ttsReady = false);
    }
  }

  Future<void> _toggleSpeech() async {
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    if (!_ttsReady) {
      _showMessage('Suara belum siap di perangkat ini.');
      return;
    }
    final article = widget.article;
    final buffer = StringBuffer()
      ..writeln('Panduan untuk ${article.title}.')
      ..writeln()
      ..writeln('Penyebab utama.')
      ..writeln(article.mainCause)
      ..writeln()
      ..writeln('Langkah penanganan cepat.');
    final steps = AppFormatters.splitSteps(article.quickSolution);
    for (var i = 0; i < steps.length; i++) {
      buffer.writeln('Langkah ${i + 1}. ${steps[i]}');
    }
    if ((article.preventionTips ?? '').trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Cara mencegah.')
        ..writeln(article.preventionTips);
    }
    setState(() => _isSpeaking = true);
    try {
      await _tts.speak(buffer.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _showMessage('Gagal memutar suara. Coba lagi.');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final steps = AppFormatters.splitSteps(article.quickSolution);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan Solusi'),
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _badge(
                        icon: Icons.local_florist_rounded,
                        label: article.commodityName,
                        color: AppTheme.secondaryGreen,
                      ),
                      _badge(
                        icon: Icons.category_rounded,
                        label: article.categoryLabel,
                        color: AppTheme.textSecondary,
                      ),
                      _badge(
                        icon: Icons.visibility_rounded,
                        label: '${article.viewCount}x dibaca',
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BigActionButton(
                    label: _isSpeaking
                        ? 'Hentikan Suara'
                        : 'Dengarkan Panduan Suara',
                    icon: _isSpeaking
                        ? Icons.stop_circle_rounded
                        : Icons.volume_up_rounded,
                    backgroundColor: AppTheme.accentOrange,
                    onPressed: _toggleSpeech,
                  ),
                  const SizedBox(height: 20),
                  _sectionCard(
                    icon: Icons.help_outline_rounded,
                    title: 'Penyebab Utama',
                    child: Text(
                      article.mainCause,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.healing_rounded,
                                color: AppTheme.primaryGreen,
                                size: 26,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Langkah Penanganan Cepat',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (steps.isEmpty)
                            Text(
                              article.quickSolution,
                              style: Theme.of(context).textTheme.bodyLarge,
                            )
                          else
                            ...List.generate(
                              steps.length,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          steps[index],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if ((article.preventionTips ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceTintGreen,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: AppTheme.secondaryGreen.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.shield_rounded,
                                color: AppTheme.secondaryGreen,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Cara Mencegah Agar Tidak Terulang',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            article.preventionTips!,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (article.recommendedProducts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Rekomendasi Produk Terkait',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...article.recommendedProducts.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ProductRecommendCard(
                          productId: item.productId,
                          name: item.productName,
                          formattedPrice: AppFormatters.rupiah(item.price),
                          unit: item.unit,
                          storeName: item.storeName,
                          imageUrl: item.imageUrl,
                          usageNote: item.usageNote,
                          onBuyTap: () =>
                              widget.onOpenProduct?.call(item.productId),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Penting: selalu baca label kemasan sebelum memakai obat atau '
                    'pupuk. Jangan menambah dosis melebihi anjuran.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryGreen, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
