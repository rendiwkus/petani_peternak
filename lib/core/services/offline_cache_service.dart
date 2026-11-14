import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Cache lokal Hive untuk mode offline-first saat sinyal desa hilang.
///
/// Semua nilai disimpan sebagai Map/List JSON-compatible agar aman
/// dipakai lintas isolate dan tidak bergantung pada adapter generator.
class OfflineCacheService {
  OfflineCacheService._();

  static final OfflineCacheService instance = OfflineCacheService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    for (final name in const [
      AppConstants.boxUserProfile,
      AppConstants.boxArticles,
      AppConstants.boxCommodities,
      AppConstants.boxProducts,
      AppConstants.boxCareSchedules,
      AppConstants.boxFinance,
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<dynamic>(name);
      }
    }
    _initialized = true;
  }

  Box<dynamic> _box(String name) => Hive.box<dynamic>(name);

  Future<void> saveMap(
    String boxName,
    String key,
    Map<String, dynamic> data,
  ) async {
    await _box(boxName).put(key, data);
    await _box(boxName).put('${key}_cached_at', DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? getMap(String boxName, String key) {
    final value = _box(boxName).get(key);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? getCachedAt(String boxName, String key) {
    final value = _box(boxName).get('${key}_cached_at');
    return value is String ? value : null;
  }

  Future<void> saveList(
    String boxName,
    String key,
    List<Map<String, dynamic>> data,
  ) async {
    await _box(boxName).put(key, data);
    await _box(boxName).put('${key}_cached_at', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>> getList(String boxName, String key) {
    final value = _box(boxName).get(key);
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  Future<void> delete(String boxName, String key) async {
    await _box(boxName).delete(key);
    await _box(boxName).delete('${key}_cached_at');
  }

  /// Menghapus data milik pengguna saat logout, bukan cache panduan publik.
  Future<void> clearUserCache() async {
    await _box(AppConstants.boxUserProfile).clear();
    await _box(AppConstants.boxCareSchedules).clear();
    await _box(AppConstants.boxFinance).clear();
  }
}
