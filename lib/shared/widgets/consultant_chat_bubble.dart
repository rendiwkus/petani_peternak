import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Balon percakapan ala WhatsApp untuk AI Agent / penyuluh.
class ConsultantChatBubble extends StatelessWidget {
  const ConsultantChatBubble({
    super.key,
    required this.isUser,
    required this.timeLabel,
    this.messageText,
    this.imageUrl,
    this.audioDurationLabel,
    this.onPlayAudio,
    this.imageBytes,
    this.recommendedProductCards = const [],
  });

  final bool isUser;
  final String timeLabel;
  final String? messageText;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? audioDurationLabel;
  final VoidCallback? onPlayAudio;
  final List<Widget> recommendedProductCards;

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isUser ? AppTheme.chatUserBubble : AppTheme.cardSurface;
    final borderColor =
        isUser ? AppTheme.chatUserBorder : AppTheme.cardBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 17,
                    color: AppTheme.secondaryGreen,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Asisten Tani & Ternak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.84,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                border: Border.all(color: borderColor, width: 1.2),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((imageUrl != null && imageUrl!.isNotEmpty) ||
                      imageBytes != null) ...[
                    GestureDetector(
                      onTap: () {
                        if (imageUrl != null && imageUrl!.isNotEmpty) {
                          _openImage(context, imageUrl!);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: imageBytes != null
                              ? Image.memory(imageBytes!, fit: BoxFit.cover)
                              : Image.network(
                                  imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: AppTheme.surfaceTintGreen,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      color: AppTheme.secondaryGreen,
                                      size: 40,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (messageText != null && messageText!.trim().isNotEmpty)
                    SelectableText(
                      messageText!,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  if (audioDurationLabel != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onPlayAudio,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceTintGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppTheme.secondaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pesan suara $audioDurationLabel',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (recommendedProductCards.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...recommendedProductCards.map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: card,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton.filled(
                  tooltip: 'Tutup foto',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
