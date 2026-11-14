import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/consultant_chat_bubble.dart';
import '../../../shared/widgets/offline_status_banner.dart';
import '../../../shared/widgets/product_recommend_card.dart';
import '../../auth/data/models/user_profile_model.dart';
import '../data/ai_chat_repository.dart';
import '../data/models/chat_message_model.dart';

/// Ruang konsultasi AI ala WhatsApp dengan input teks, foto, dan suara.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.profile,
    required this.onOpenProduct,
    required this.onUpgradeTap,
    this.onQuotaUsed,
    this.initialPrompt,
    this.onPromptConsumed,
    this.repository,
  });

  final UserProfileModel profile;
  final ValueChanged<String> onOpenProduct;
  final VoidCallback onUpgradeTap;
  final Future<void> Function()? onQuotaUsed;
  final String? initialPrompt;
  final VoidCallback? onPromptConsumed;
  final AiChatRepository? repository;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  late final AiChatRepository _repository =
      widget.repository ?? AiChatRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();
  final _picker = ImagePicker();

  final List<ChatMessageModel> _messages = [];
  String? _sessionId;
  String? _error;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _isOffline = false;
  Uint8List? _pendingImageBytes;
  String? _pendingImageMime;
  String? _pendingImageName;
  StreamSubscription<bool>? _offlineSubscription;
  bool _initialPromptHandled = false;

  bool get _quotaExhausted =>
      !widget.profile.isProActive && widget.profile.aiQuotaLeft <= 0;

  @override
  void initState() {
    super.initState();
    _isOffline = ConnectivityService.instance.isOffline;
    _offlineSubscription =
        ConnectivityService.instance.changes.listen((offline) {
      if (mounted) setState(() => _isOffline = offline);
    });
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant AiChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prompt = widget.initialPrompt?.trim() ?? '';
    if (prompt.isNotEmpty &&
        prompt != (oldWidget.initialPrompt?.trim() ?? '')) {
      _initialPromptHandled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePrompt());
    }
  }

  Future<void> _bootstrap() async {
    _sessionId = _repository.lastSessionId;
    try {
      if (_sessionId != null) {
        final history = await _repository.fetchLatestMessages();
        if (!mounted) return;
        setState(() {
          _messages
            ..clear()
            ..addAll(history);
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = SupabaseService.friendlyError(error);
      });
    }
    _consumePrompt();
  }

  void _consumePrompt() {
    if (_initialPromptHandled) return;
    final prompt = widget.initialPrompt?.trim() ?? '';
    if (prompt.isEmpty) return;
    _initialPromptHandled = true;
    _send(text: prompt);
    widget.onPromptConsumed?.call();
  }

  @override
  void dispose() {
    _offlineSubscription?.cancel();
    _speech.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send({String? text}) async {
    if (_isSending) return;
    final cleanText = (text ?? _messageController.text).trim();
    final imageBytes = _pendingImageBytes;
    final imageMime = _pendingImageMime;
    final imageName = _pendingImageName;
    if (cleanText.isEmpty && imageBytes == null) {
      _showMessage('Tulis pertanyaan atau lampirkan foto dulu.');
      return;
    }
    if (_quotaExhausted) {
      _showUpgradeMessage();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      _sessionId ??= await _repository.createSession(
        title: cleanText.isEmpty ? 'Konsultasi Foto Tanaman/Ternak' : cleanText,
      );

      final optimistic = ChatMessageModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        sessionId: _sessionId!,
        sender: 'user',
        messageText: cleanText,
        createdAt: DateTime.now(),
      )..localImageBytes = imageBytes;
      setState(() {
        _messages.add(optimistic);
        _messageController.clear();
        _pendingImageBytes = null;
        _pendingImageMime = null;
        _pendingImageName = null;
      });
      _scrollToBottom();

      final history =
          _messages.where((message) => !message.id.startsWith('local-')).toList();
      final reply = await _repository.sendMessage(
        sessionId: _sessionId!,
        text: cleanText,
        imageBytes: imageBytes,
        imageMimeType: imageMime,
        imageExtension: _extensionOf(imageName),
        history: history,
        isPro: widget.profile.isProActive,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(reply);
        _isSending = false;
      });
      try {
        final fresh = await _repository.fetchMessages(_sessionId!);
        if (mounted && fresh.isNotEmpty) {
          setState(() {
            _messages
              ..clear()
              ..addAll(fresh);
          });
        }
      } catch (_) {
        await _repository.saveMessagesCache(_sessionId!, _messages);
      }
      _scrollToBottom();
      await widget.onQuotaUsed?.call();
    } on QuotaExceededException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.removeWhere((message) => message.id.startsWith('local-'));
      });
      _showUpgradeMessage(message: error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.removeWhere((message) => message.id.startsWith('local-'));
      });
      final message = SupabaseService.friendlyError(error);
      setState(() => _error = message);
      _showMessage(message);
      if (cleanText.isNotEmpty) {
        _messageController.text = cleanText;
      }
      if (imageBytes != null) {
        setState(() {
          _pendingImageBytes = imageBytes;
          _pendingImageMime = imageMime;
          _pendingImageName = imageName;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _showMessage('Ukuran foto maksimal 5 MB. Pilih foto lain.');
        return;
      }
      final extension = _extensionOf(file.name);
      final mime = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
      if (!mounted) return;
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageMime = mime;
        _pendingImageName = file.name;
      });
    } catch (_) {
      _showMessage(
        'Foto tidak dapat diambil. Periksa izin kamera/galeri di pengaturan HP.',
      );
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Ambil Foto dari Kamera'),
              subtitle: const Text('Foto daun atau ternak dari jarak dekat'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Pilih Foto dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    try {
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onStatus: (status) {
            if (!mounted) return;
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _isListening = false);
            _showMessage(
              'Suara belum terdengar jelas. Coba lagi di tempat lebih tenang.',
            );
          },
        );
      }
      if (!_speechInitialized) {
        _showMessage('Mikrofon tidak tersedia. Silakan ketik pertanyaan.');
        return;
      }
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          _messageController.text = words;
          _messageController.selection =
              TextSelection.collapsed(offset: words.length);
          setState(() {});
          if (result.finalResult) {
            _speech.stop();
            setState(() => _isListening = false);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: 'id_ID',
          listenMode: ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isListening = false);
      _showMessage('Mikrofon tidak dapat digunakan. Periksa izin mikrofon.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showUpgradeMessage({String? message}) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kuota AI Habis'),
        content: Text(
          message ??
              'Kuota tanya AI gratis 5 pertanyaan per hari sudah habis. '
                  'Upgrade ke Pro untuk tanya tanpa batas.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onUpgradeTap();
            },
            child: const Text('Lihat Paket Pro'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  static String _extensionOf(String? name) {
    if (name == null || !name.contains('.')) return 'jpg';
    return name.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tanya AI'),
            Text(
              widget.profile.isProActive
                  ? 'Pro • Tanya tanpa batas'
                  : 'Gratis • Sisa ${widget.profile.aiQuotaLeft} tanya hari ini',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            OfflineStatusBanner(isOffline: _isOffline),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          children: [
                            if (_messages.isEmpty) _buildWelcome(),
                            ..._messages.map(_buildBubble),
                            if (_isSending) _buildTypingIndicator(),
                            if (_error != null) _buildErrorBanner(),
                          ],
                        ),
                ),
              ),
            ),
            if (_quotaExhausted) _buildQuotaBanner(),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    const prompts = [
      'Daun cabai saya keriting dan menguning',
      'Ayam saya lemas dan tidak mau makan',
      'Padi saya ada bercak cokelat',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTintGreen,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.secondaryGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: AppTheme.secondaryGreen,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Asisten Tani & Ternak',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Halo! Tanyakan masalah tanaman atau ternak Anda. '
            'Bisa dengan ketikan, rekaman suara, atau foto daun/ternak yang sakit.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prompts
                .map(
                  (prompt) => ActionChip(
                    label: Text(prompt),
                    labelStyle: const TextStyle(fontSize: 14),
                    onPressed: () => _send(text: prompt),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessageModel message) {
    final cards = message.resolvedProducts
        .map(
          (product) => ProductRecommendCard(
            productId: product.id,
            name: product.name,
            formattedPrice: product.formattedPrice,
            unit: product.unit,
            storeName: product.storeName,
            imageUrl: product.imageUrl,
            onBuyTap: () => widget.onOpenProduct(product.id),
          ),
        )
        .toList();
    return ConsultantChatBubble(
      isUser: message.isUser,
      messageText: message.messageText,
      imageUrl: message.signedImageUrl ??
          (message.hasImage ? message.imageUrl : null),
      imageBytes: message.localImageBytes,
      timeLabel: AppFormatters.time(message.createdAt),
      recommendedProductCards: cards,
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 10),
          Text(
            'Asisten sedang memeriksa...',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.dangerRed, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppTheme.warningAmberBg,
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded,
              color: AppTheme.warningAmberBorder, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Kuota tanya gratis hari ini habis. Upgrade Pro untuk lanjut.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onUpgradeTap,
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _pendingImageBytes!,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Foto siap dikirim. Tambahkan keterangan bila perlu.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus foto',
                    onPressed: () => setState(() {
                      _pendingImageBytes = null;
                      _pendingImageMime = null;
                      _pendingImageName = null;
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          if (_isListening)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Sedang mendengarkan suara Anda... Silakan bicara',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dangerRed,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filledTonal(
                tooltip: 'Lampirkan foto',
                onPressed: _isSending ? null : _showImageSourceSheet,
                icon: const Icon(Icons.camera_alt_rounded),
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: _isListening ? 'Hentikan suara' : 'Bicara',
                onPressed: _isSending ? null : _toggleVoice,
                icon: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: _isListening ? AppTheme.dangerRed : null,
                ),
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  enabled: !_isSending && !_quotaExhausted,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Tulis pertanyaan Anda...',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                height: 52,
                child: IconButton.filled(
                  tooltip: 'Kirim',
                  onPressed: _isSending || _quotaExhausted ? null : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.disabledBg,
                  ),
                  icon: _isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
