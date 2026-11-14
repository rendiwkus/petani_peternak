import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Pembacaan konfigurasi publik dari `.env`.
///
/// Hanya URL dan publishable/anon key yang boleh berada di aplikasi klien.
/// Kunci rahasia (service role, Gemini API key) wajib disimpan di Supabase.
class EnvConfig {
  EnvConfig._();

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    await dotenv.load(fileName: '.env');
    _loaded = true;
  }

  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabasePublishableKey =>
      _required('SUPABASE_ANON_KEY');
  static String get aiFunctionName =>
      dotenv.env['AI_FUNCTION_NAME']?.trim().isNotEmpty == true
          ? dotenv.env['AI_FUNCTION_NAME']!.trim()
          : 'ai-consultant';

  static String _required(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Konfigurasi $key belum diisi di file .env');
    }
    return value;
  }

  static bool get isConfigured {
    try {
      final uri = Uri.parse(supabaseUrl);
      return uri.isScheme('https') &&
          uri.host.isNotEmpty &&
          supabasePublishableKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
