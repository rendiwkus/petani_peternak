import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Kotak sorotan takaran pupuk/pakan/obat.
class DosageHighlightBox extends StatelessWidget {
  const DosageHighlightBox({
    super.key,
    required this.dosageText,
    this.activeIngredients,
  });

  final String dosageText;
  final String? activeIngredients;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.warningAmberBg,
        border: Border(
          left: BorderSide(color: AppTheme.warningAmberBorder, width: 5),
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.science_rounded,
                color: Color(0xFF8D6E00),
                size: 26,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Takaran & Cara Pakai',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dosageText,
            style: const TextStyle(
              fontSize: 16,
              height: 1.55,
              color: AppTheme.textPrimary,
            ),
          ),
          if (activeIngredients != null &&
              activeIngredients!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Bahan aktif: ${activeIngredients!}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6D4C00),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
