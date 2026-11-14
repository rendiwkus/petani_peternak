import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_config.dart';
import '../constants/app_constants.dart';

/// Client tunggal Supabase (Auth, PostgREST, Storage, Edge Functions).
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUri: true,
      ),
    );
    _initialized = true;
  }

  SupabaseClient get client => Supabase.instance.client;

  Session? get currentSession => client.auth.currentSession;
  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentSession != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> sendPhoneOtp(String e164Phone) =>
      client.auth.signInWithOtp(phone: e164Phone);

  Future<AuthResponse> verifyPhoneOtp({
    required String e164Phone,
    required String token,
  }) =>
      client.auth.verifyOTP(
        phone: e164Phone,
        token: token,
        type: OtpType.sms,
      );

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) =>
      client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => client.auth.signOut();

  Future<String> uploadConsultationImage({
    required String userId,
    required String sessionId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final safeExtension = extension.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
    final path = '$userId/$sessionId/'
        '${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    await client.storage.from(AppConstants.bucketConsultations).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  Future<String?> createSignedUrl(String path, {int seconds = 3600}) async {
    if (path.trim().isEmpty) return null;
    try {
      return await client.storage
          .from(AppConstants.bucketConsultations)
          .createSignedUrl(path, seconds);
    } catch (_) {
      return null;
    }
  }

  Future<FunctionResponse> invokeAiFunction(
    Map<String, dynamic> payload,
  ) =>
      client.functions.invoke(
        EnvConfig.aiFunctionName,
        body: payload,
      );

  /// Pesan error ramah pengguna, tanpa membocorkan detail internal server.
  static String friendlyError(Object error) {
    if (error is AuthException) {
      final code = error.statusCode?.toString() ?? '';
      final message = error.message.toLowerCase();
      if (message.contains('phone') &&
          (message.contains('disabled') || message.contains('not enabled'))) {
        return 'Masuk dengan nomor HP belum diaktifkan. '
            'Silakan gunakan menu "Masuk dengan Email" atau hubungi admin.';
      }
      if (message.contains('invalid login') ||
          message.contains('invalid credentials')) {
        return 'Email atau password salah. Silakan periksa kembali.';
      }
      if (message.contains('email not confirmed')) {
        return 'Email belum dikonfirmasi. Silakan cek kotak masuk email Anda.';
      }
      if (message.contains('rate limit') || code == '429') {
        return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
      }
      if (message.contains('token') &&
          (message.contains('expired') || message.contains('invalid'))) {
        return 'Kode OTP salah atau sudah kedaluwarsa, silakan coba lagi.';
      }
      return _sanitize(error.message);
    }
    if (error is SocketException || error is TimeoutException) {
      return 'Tidak ada koneksi internet. Periksa sinyal lalu coba lagi.';
    }
    if (error is PostgrestException) {
      switch (error.code) {
        case '42501':
          return 'Anda tidak memiliki izin untuk tindakan ini.';
        case '23505':
          return 'Data ini sudah ada.';
        case '23503':
          return 'Data terkait tidak ditemukan.';
        case 'PGRST202':
        case '42883':
          return 'Fitur server belum disiapkan. Hubungi admin aplikasi.';
        default:
          return _sanitize(error.message);
      }
    }
    if (error is FunctionException) {
      if (error.status == 429) {
        return 'Kuota tanya AI hari ini sudah habis. '
            'Upgrade ke Pro untuk tanya tanpa batas.';
      }
      if (error.status == 401 || error.status == 403) {
        return 'Sesi Anda berakhir. Silakan masuk kembali.';
      }
      if (error.status == 404) {
        return 'Layanan AI belum aktif. '
            'Aplikasi menampilkan panduan yang tersimpan di HP.';
      }
      return 'Layanan AI sedang sibuk. Coba lagi beberapa saat.';
    }
    return _sanitize(error.toString());
  }

  static String _sanitize(String message) {
    final clean = message
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return 'Terjadi kesalahan. Silakan coba lagi.';
    return clean.length > 180 ? '${clean.substring(0, 180)}...' : clean;
  }
}
