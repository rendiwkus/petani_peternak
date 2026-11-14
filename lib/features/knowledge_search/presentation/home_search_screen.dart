import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/category_tile_card.dart';
import '../../../shared/widgets/offline_status_banner.dart';
import '../../../shared/widgets/voice_search_bar.dart';
import '../../auth/data/models/user_profile_model.dart';
import '../data/knowledge_repository.dart';
import '../data/models/article_model.dart';
import 'article_detail_screen.dart';

/// Beranda pencarian gejala penyakit dengan dukungan suara dan cache offline.
class HomeSearchScreen extends StatefulWidget {
  const HomeSearchScreen({
    super.key,
    required this.profile,
    required this.cartCount,
    required this.onOpenCart,
    required this.onAskAi,
    required this.onOpenProduct,
    this.onOpenProfile,
    this.onRefreshProfile,
    this.repository,
  });

  final UserProfileModel profile;
  final int cartCount;
  final VoidCallback onOpenCart;
  final ValueChanged<String> onAskAi;
  final ValueChanged<String> onOpenProduct;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onRefreshProfile;
  final KnowledgeRepository? repository;

  @override
  State<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends State<HomeSearchScreen> {
  late final KnowledgeRepository _repository =
      widget.repository ?? KnowledgeRepository();
  final _searchController = TextEditingController();
  final SpeechToText _speech = SpeechToText();

  List<ArticleModel> _articles = const [];
  String? _selectedCategory;
  String? _error;
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  Timer? _debounce;
  StreamSubscription<bool>? _offlineSubscription;

  @override
  void initState() {
    super.initState();
    _isOffline = ConnectivityService.instance.isOffline;
    _offlineSubscription =
        ConnectivityService.instance.changes.listen((offline) {
      if (!mounted) return;
      setState(() => _isOffline = offline);
      if (!offline) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _offlineSubscription?.cancel();
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _load({bool showSkeleton = false}) async {
    if (showSkeleton) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
    try {
      final articles = await _repository.searchArticles(
        query: _searchController.text,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = SupabaseService.friendlyError(error);
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () => _load());
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    try {
      if (!_speechInitialized) {
        final available = await _speech.initialize(
          onStatus: (status) {
            if (!mounted) return;
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _isListening = false);
            _showMessage(
              'Suara tidak terdengar jelas. Coba lagi di tempat yang lebih tenang.',
            );
          },
        );
        _speechInitialized = available;
        if (!available) {
          _showMessage(
            'Pengenal suara belum tersedia di perangkat ini. '
            'Silakan ketik pertanyaan Anda.',
          );
          return;
        }
      }

      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          _searchController.text = words;
          _searchController.selection =
              TextSelection.collapsed(offset: words.length);
          setState(() {});
          if (result.finalResult) {
            _speech.stop();
            setState(() => _isListening = false);
            _load();
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: 'id_ID',
          listenMode: ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isListening = false);
      _showMessage(
        'Mikrofon tidak dapat digunakan. Periksa izin mikrofon di pengaturan HP.',
      );
    }
  }

  Future<void> _selectCategory(String category) async {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
    await _load();
  }

  void _openArticle(ArticleModel article) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailScreen(
          article: article,
          onOpenProduct: widget.onOpenProduct,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final firstName = profile.fullName.trim().split(RegExp(r'\s+')).first;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _load(showSkeleton: false),
              if (widget.onRefreshProfile != null)
                widget.onRefreshProfile!.call(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              OfflineStatusBanner(isOffline: _isOffline),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(firstName, profile),
                        const SizedBox(height: 16),
                        VoiceSearchBar(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onMicTap: _toggleVoice,
                          isListening: _isListening,
                          onSubmitted: (_) => _load(),
                        ),
                        const SizedBox(height: 16),
                        _buildAiShortcut(),
                        const SizedBox(height: 20),
                        ...AppConstantsCategories.values.map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CategoryTileCard(
                              title: category.label,
                              subtitle: category.subtitle,
                              icon: category.icon,
                              accentColor: category.color,
                              isSelected: _selectedCategory == category.value,
                              onTap: () => _selectCategory(category.value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Masalah yang Sering Dicari',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (_articles.isNotEmpty)
                              Text(
                                '${_articles.length} panduan',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          _buildSkeleton()
                        else if (_error != null)
                          _buildError()
                        else if (_articles.isEmpty)
                          _buildEmpty()
                        else
                          ..._articles.map(
                            (article) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ArticleCard(
                                article: article,
                                onTap: () => _openArticle(article),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String firstName, UserProfileModel profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            onTap: widget.onOpenProfile,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppFormatters.greeting()}, $firstName',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: profile.isProActive
                              ? AppTheme.accentOrange
                              : AppTheme.surfaceTintGreen,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusBadge),
                        ),
                        child: Text(
                          profile.isProActive ? 'Juragan Pro' : 'Akun Gratis',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: profile.isProActive
                                ? Colors.white
                                : AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      Text(
                        profile.shortLocation,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Buka keranjang belanja, ${widget.cartCount} barang',
          child: InkWell(
            onTap: widget.onOpenCart,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder, width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_rounded,
                    color: AppTheme.primaryGreen,
                    size: 27,
                  ),
                  if (widget.cartCount > 0)
                    Positioned(
                      top: 5,
                      right: 4,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: const BoxDecoration(
                          color: AppTheme.dangerRed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.cartCount > 99 ? '99+' : '${widget.cartCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiShortcut() {
    return Material(
      color: const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: () => widget.onAskAi(_searchController.text.trim()),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: AppTheme.accentOrange.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punya foto daun/ternak sakit?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tanya AI Sekarang — kirim foto atau suara',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.accentOrange,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.cardBorder, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonLine(width: 120, height: 18),
              const SizedBox(height: 12),
              _skeletonLine(width: double.infinity, height: 20),
              const SizedBox(height: 8),
              _skeletonLine(width: double.infinity, height: 16),
              const SizedBox(height: 8),
              _skeletonLine(width: 220, height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.cardBorder.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildError() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppTheme.dangerRed,
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Gagal memuat panduan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            BigActionButton(
              label: 'Coba Lagi',
              icon: Icons.refresh_rounded,
              isOutlined: true,
              onPressed: () => _load(showSkeleton: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceTintGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppTheme.secondaryGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum ada panduan yang cocok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba kata lain, pilih kategori, atau tanyakan langsung ke AI Agent.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Tanyakan Gejala Ini ke AI Agent',
              icon: Icons.chat_bubble_rounded,
              backgroundColor: AppTheme.accentOrange,
              onPressed: () => widget.onAskAi(_searchController.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTap});

  final ArticleModel article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceTintGreen,
                      borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
                    ),
                    child: Text(
                      article.categoryLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      article.commodityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.secondaryGreen,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppFormatters.truncate(article.mainCause, 140),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              if (article.recommendedProducts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_rounded,
                      size: 17,
                      color: AppTheme.accentOrange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${article.recommendedProducts.length} produk disarankan',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryInfo {
  const _CategoryInfo({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class AppConstantsCategories {
  AppConstantsCategories._();

  static const values = [
    _CategoryInfo(
      value: 'pertanian',
      label: 'Tanaman Pangan',
      subtitle: 'Padi, Jagung, Cabai, Sayur',
      icon: Icons.grass_rounded,
      color: AppTheme.primaryGreen,
    ),
    _CategoryInfo(
      value: 'perkebunan',
      label: 'Perkebunan',
      subtitle: 'Kopi, Kakao, Kelapa, Buah',
      icon: Icons.park_rounded,
      color: Color(0xFF00695C),
    ),
    _CategoryInfo(
      value: 'peternakan',
      label: 'Peternakan',
      subtitle: 'Ayam, Sapi, Kambing, Ikan',
      icon: Icons.pets_rounded,
      color: AppTheme.accentOrange,
    ),
  ];
}
