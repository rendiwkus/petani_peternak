import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await EnvConfig.load();
    if (!EnvConfig.isConfigured) {
      throw StateError('Konfigurasi Supabase belum lengkap di file .env');
    }
    await initializeDateFormatting('id_ID');
    await OfflineCacheService.instance.init();
    await SupabaseService.instance.initialize();
    unawaited(ConnectivityService.instance.start());
    runApp(const TaniTernakApp());
  } catch (error) {
    runApp(_SetupErrorApp(message: error.toString()));
  }
}

/// Layar darurat bila `.env` belum diisi, agar pengguna melihat sebabnya
/// alih-alih layar putih.
class _SetupErrorApp extends StatelessWidget {
  const _SetupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings_rounded, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Aplikasi belum siap dijalankan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Periksa file .env lalu jalankan ulang aplikasi.\n\n$message',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
