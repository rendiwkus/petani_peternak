import '../../../../core/constants/app_constants.dart';

/// Profil pengguna dari tabel `public.profiles`.
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.role = AppConstants.rolePetani,
    this.village,
    this.district,
    this.regency,
    this.province,
    this.fullAddress,
    this.isPro = false,
    this.proExpiresAt,
    this.dailyAiQuotaUsed = 0,
    this.lastQuotaReset,
  });

  final String id;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final String? village;
  final String? district;
  final String? regency;
  final String? province;
  final String? fullAddress;
  final bool isPro;
  final DateTime? proExpiresAt;
  final int dailyAiQuotaUsed;
  final DateTime? lastQuotaReset;

  bool get isProActive =>
      isPro && (proExpiresAt == null || proExpiresAt!.isAfter(DateTime.now()));

  int get aiQuotaLeft {
    if (isProActive) return 999999;
    final left = AppConstants.freeDailyAiQuota - dailyAiQuotaUsed;
    return left < 0 ? 0 : left;
  }

  String get displayRole {
    switch (role) {
      case AppConstants.roleMitraKios:
        return 'Mitra Kios';
      case AppConstants.rolePenyuluh:
        return 'Penyuluh';
      case AppConstants.roleAdmin:
        return 'Admin';
      default:
        return 'Petani / Peternak';
    }
  }

  String get shortLocation {
    final parts = [village, district, regency]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? 'Lokasi belum diisi' : parts.join(', ');
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      fullName: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? (json['full_name'] as String).trim()
          : 'Pengguna TaniTernak',
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? AppConstants.rolePetani,
      village: json['village'] as String?,
      district: json['district'] as String?,
      regency: json['regency'] as String?,
      province: json['province'] as String?,
      fullAddress: json['full_address'] as String?,
      isPro: json['is_pro'] as bool? ?? false,
      proExpiresAt: _dateTime(json['pro_expires_at']),
      dailyAiQuotaUsed: (json['daily_ai_quota_used'] as num?)?.toInt() ?? 0,
      lastQuotaReset: _dateTime(json['last_quota_reset']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'avatar_url': avatarUrl,
        'role': role,
        'village': village,
        'district': district,
        'regency': regency,
        'province': province,
        'full_address': fullAddress,
        'is_pro': isPro,
        'pro_expires_at': proExpiresAt?.toIso8601String(),
        'daily_ai_quota_used': dailyAiQuotaUsed,
        'last_quota_reset': lastQuotaReset?.toIso8601String(),
      };

  UserProfileModel copyWith({
    String? fullName,
    String? phoneNumber,
    String? village,
    String? district,
    String? regency,
    String? province,
    String? fullAddress,
    bool? isPro,
    DateTime? proExpiresAt,
    int? dailyAiQuotaUsed,
    DateTime? lastQuotaReset,
  }) {
    return UserProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl,
      role: role,
      village: village ?? this.village,
      district: district ?? this.district,
      regency: regency ?? this.regency,
      province: province ?? this.province,
      fullAddress: fullAddress ?? this.fullAddress,
      isPro: isPro ?? this.isPro,
      proExpiresAt: proExpiresAt ?? this.proExpiresAt,
      dailyAiQuotaUsed: dailyAiQuotaUsed ?? this.dailyAiQuotaUsed,
      lastQuotaReset: lastQuotaReset ?? this.lastQuotaReset,
    );
  }

  static DateTime? _dateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
