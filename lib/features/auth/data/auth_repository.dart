import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/formatters.dart';
import 'models/user_profile_model.dart';

/// Repository autentikasi + profil pengguna.
class AuthRepository {
  AuthRepository({SupabaseService? supabase, OfflineCacheService? cache})
      : _supabase = supabase ?? SupabaseService.instance,
        _cache = cache ?? OfflineCacheService.instance;

  final SupabaseService _supabase;
  final OfflineCacheService _cache;
  static const _profileKey = 'current_user';

  SupabaseClient get _client => _supabase.client;

  Future<void> requestPhoneOtp(String rawPhone) async {
    final phone = AppFormatters.normalizePhone(rawPhone);
    if (AppFormatters.validatePhone(rawPhone) != null) {
      throw const AuthException('Nomor HP tidak valid');
    }
    await _supabase.sendPhoneOtp(phone);
  }

  Future<UserProfileModel> verifyPhoneOtp({
    required String rawPhone,
    required String otpCode,
  }) async {
    final phone = AppFormatters.normalizePhone(rawPhone);
    await _supabase.verifyPhoneOtp(e164Phone: phone, token: otpCode.trim());
    return _requireProfile();
  }

  Future<UserProfileModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    await _supabase.signInWithEmail(
      email: email.trim().toLowerCase(),
      password: password,
    );
    return _requireProfile();
  }

  Future<UserProfileModel> _requireProfile() async {
    final profile = await fetchCurrentProfile(forceRemote: true);
    if (profile != null) return profile;
    return _createProfileFromAuthUser();
  }

  Future<UserProfileModel?> fetchCurrentProfile({bool forceRemote = false}) async {    final userId = _supabase.currentUserId;
    if (userId == null) return null;

    if (!forceRemote) {
      final cached = _cache.getMap(AppConstants.boxUserProfile, _profileKey);
      if (cached != null) {
        // Tetap coba sinkronisasi di latar belakang, cache dipakai saat offline.
        unawaited(_refreshFromServer(userId));
        return UserProfileModel.fromJson(cached);
      }
    }

    try {
      final data = await _client
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      await _cache.saveMap(AppConstants.boxUserProfile, _profileKey, data);
      return UserProfileModel.fromJson(data);
    } catch (error) {
      if (_isNetworkError(error)) {
        final cached = _cache.getMap(AppConstants.boxUserProfile, _profileKey);
        if (cached != null) return UserProfileModel.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Memastikan profil ada setelah sesi dipulihkan (mis. trigger DB telat).
  Future<UserProfileModel> ensureProfile() async {
    final profile = await fetchCurrentProfile(forceRemote: true);
    return profile ?? _createProfileFromAuthUser();
  }

  Future<void> _refreshFromServer(String userId) async {
    try {
      final data = await _client
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        await _cache.saveMap(AppConstants.boxUserProfile, _profileKey, data);
      }
    } catch (_) {
      // Cache tetap menjadi sumber data saat offline.
    }
  }

  Future<UserProfileModel> _createProfileFromAuthUser() async {
    final user = _supabase.currentUser;
    if (user == null) {
      throw const AuthException('Sesi login tidak ditemukan');
    }
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final payload = <String, dynamic>{
      'id': user.id,
      'full_name': (metadata['full_name'] as String?)?.trim().isNotEmpty == true
          ? (metadata['full_name'] as String).trim()
          : (user.email?.split('@').first ?? 'Pengguna TaniTernak'),
      'phone_number': (metadata['phone_number'] as String?) ??
          user.phone?.replaceFirst(RegExp(r'^\+'), ''),
      'role': AppConstants.rolePetani,
    };
    await _client
        .from(AppConstants.tableProfiles)
        .upsert(payload, onConflict: 'id', ignoreDuplicates: true);
    final data = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) {
      throw const AuthException('Profil pengguna belum tersedia');
    }
    await _cache.saveMap(AppConstants.boxUserProfile, _profileKey, data);
    return UserProfileModel.fromJson(data);
  }

  Future<UserProfileModel> updateProfile({
    required String fullName,
    String? village,
    String? district,
    String? regency,
    String? province,
    String? fullAddress,
  }) async {
    final userId = _supabase.currentUserId;
    if (userId == null) {
      throw const AuthException('Sesi login tidak ditemukan');
    }
    final cleanName = fullName.trim();
    if (cleanName.length < 2) {
      throw const AuthException('Nama minimal 2 huruf');
    }
    final payload = <String, dynamic>{
      'full_name': cleanName,
      'village': _nullable(village),
      'district': _nullable(district),
      'regency': _nullable(regency),
      'province': _nullable(province),
      'full_address': _nullable(fullAddress),
    };
    await _client
        .from(AppConstants.tableProfiles)
        .update(payload)
        .eq('id', userId);
    final refreshed = await fetchCurrentProfile(forceRemote: true);
    if (refreshed == null) {
      throw const AuthException('Gagal memuat profil terbaru');
    }
    return refreshed;
  }

  Future<void> logout() async {
    try {
      await _supabase.signOut();
    } finally {
      await _cache.clearUserCache();
    }
  }

  static String? _nullable(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error.toString().toLowerCase().contains('socket') ||
      error.toString().toLowerCase().contains('network');
}
