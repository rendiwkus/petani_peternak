import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Kolom pencarian besar dengan tombol mikrofon (voice-first).
class VoiceSearchBar extends StatelessWidget {
  const VoiceSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onMicTap,
    required this.isListening,
    this.hintText =
        'Ketik atau ucapkan masalah, misal: daun cabai keriting',
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onMicTap;
  final bool isListening;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isListening ? AppTheme.dangerRed : AppTheme.primaryGreen,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.search_rounded,
                  color: AppTheme.primaryGreen, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintMaxLines: 1,
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () {
                              controller.clear();
                              onChanged('');
                            },
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Semantics(
                  button: true,
                  label: isListening
                      ? 'Hentikan pencarian suara'
                      : 'Cari dengan suara',
                  child: InkWell(
                    onTap: onMicTap,
                    borderRadius: BorderRadius.circular(23),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isListening
                            ? AppTheme.dangerRed
                            : AppTheme.accentOrange,
                        shape: BoxShape.circle,
                        boxShadow: isListening
                            ? [
                                BoxShadow(
                                  color: AppTheme.dangerRed.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 14,
                                  spreadRadius: 3,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isListening
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isListening)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Sedang mendengarkan suara Anda... Silakan bicara',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.dangerRed,
              ),
            ),
          ),
      ],
    );
  }
}
