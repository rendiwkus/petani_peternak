import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Banner otomatis saat perangkat kehilangan koneksi.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key, required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: isOffline
          ? Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 40),
              color: AppTheme.offlineBar,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mode Tanpa Sinyal — Menampilkan panduan tersimpan di HP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
