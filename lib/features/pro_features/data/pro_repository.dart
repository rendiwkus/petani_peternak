import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/services/supabase_service.dart';

class CareScheduleModel {
  const CareScheduleModel({
    required this.id,
    required this.activityType,
    required this.scheduledDate,
    this.commodityId,
    this.commodityName,
    this.notes,
    this.isCompleted = false,
    this.completedAt,
  });

  final String id;
  final String activityType;
  final DateTime scheduledDate;
  final String? commodityId;
  final String? commodityName;
  final String? notes;
  final bool isCompleted;
  final DateTime? completedAt;

  bool get isOverdue =>
      !isCompleted && scheduledDate.isBefore(DateTime.now());

  String get activityLabel {
    switch (activityType) {
      case 'pemupukan':
        return 'Pemupukan';
      case 'penyemprotan':
        return 'Penyemprotan';
      case 'vaksinasi':
        return 'Vaksinasi';
      case 'pemberian_pakan':
        return 'Pemberian Pakan';
      case 'pemeriksaan':
        return 'Pemeriksaan Kesehatan';
      case 'panen':
        return 'Panen';
      default:
        return activityType;
    }
  }

  factory CareScheduleModel.fromJson(Map<String, dynamic> json) {
    final commodity = json['commodities'] is Map
        ? Map<String, dynamic>.from(json['commodities'] as Map)
        : null;
    return CareScheduleModel(
      id: json['id'] as String? ?? '',
      activityType: json['activity_type'] as String? ?? 'perawatan',
      scheduledDate: DateTime.tryParse(
            json['scheduled_date']?.toString() ?? '',
          ) ??
          DateTime.now(),
      commodityId: json['commodity_id'] as String?,
      commodityName: commodity?['name'] as String?,
      notes: json['notes'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'activity_type': activityType,
        'scheduled_date': scheduledDate.toIso8601String(),
        'commodity_id': commodityId,
        'commodities': commodityName == null ? null : {'name': commodityName},
        'notes': notes,
        'is_completed': isCompleted,
        'completed_at': completedAt?.toIso8601String(),
      };
}

class FarmFinanceModel {
  const FarmFinanceModel({
    required this.id,
    required this.category,
    required this.amount,
    required this.transactionDate,
    this.notes,
  });

  final String id;
  final String category;
  final double amount;
  final DateTime transactionDate;
  final String? notes;

  bool get isIncome => category == AppConstants.financeIncome;

  factory FarmFinanceModel.fromJson(Map<String, dynamic> json) {
    return FarmFinanceModel(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? AppConstants.financeExpense,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      transactionDate: DateTime.tryParse(
            json['transaction_date']?.toString() ?? '',
          ) ??
          DateTime.now(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'amount': amount,
        'transaction_date': transactionDate.toIso8601String(),
        'notes': notes,
      };
}

class FinanceSummary {
  const FinanceSummary({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;
  double get balance => income - expense;
}

class ProPlan {
  const ProPlan({
    required this.name,
    required this.days,
    required this.price,
  });

  final String name;
  final int days;
  final double price;

  static const plans = [
    ProPlan(name: 'Pro 1 Bulan', days: 30, price: 25000),
    ProPlan(name: 'Pro 3 Bulan', days: 90, price: 65000),
    ProPlan(name: 'Pro 1 Tahun', days: 365, price: 200000),
  ];
}

/// Repository fitur Pro: jadwal perawatan, pembukuan, dan langganan.
class ProRepository {
  ProRepository({SupabaseService? supabase, OfflineCacheService? cache})
      : _supabase = supabase ?? SupabaseService.instance,
        _cache = cache ?? OfflineCacheService.instance;

  final SupabaseService _supabase;
  final OfflineCacheService _cache;

  SupabaseClient get _client => _supabase.client;

  String get _requireUserId {
    final id = _supabase.currentUserId;
    if (id == null) throw const AuthException('Silakan masuk terlebih dahulu');
    return id;
  }

  String get _scheduleKey => 'schedules_$_requireUserId';
  String get _financeKey => 'finance_$_requireUserId';

  Future<List<CareScheduleModel>> fetchSchedules({
    bool forceRefresh = false,
  }) async {
    final userId = _requireUserId;
    if (!forceRefresh) {
      final cached = _cache.getList(
        AppConstants.boxCareSchedules,
        _scheduleKey,
      );
      if (cached.isNotEmpty) {
        unawaited(_refreshSchedules(userId));
        return cached.map(CareScheduleModel.fromJson).toList();
      }
    }
    try {
      final rows = await _client
          .from(AppConstants.tableCareSchedules)
          .select('*,commodities(name)')
          .eq('user_id', userId)
          .order('scheduled_date');
      final data = (rows as List)
          .whereType<Map>()
          .map((row) =>
              CareScheduleModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      await _cache.saveList(
        AppConstants.boxCareSchedules,
        _scheduleKey,
        data.map((item) => item.toJson()).toList(),
      );
      return data;
    } catch (error) {
      if (_isNetworkError(error)) {
        final cached = _cache.getList(
          AppConstants.boxCareSchedules,
          _scheduleKey,
        );
        return cached.map(CareScheduleModel.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<void> _refreshSchedules(String userId) async {
    try {
      final rows = await _client
          .from(AppConstants.tableCareSchedules)
          .select('*,commodities(name)')
          .eq('user_id', userId)
          .order('scheduled_date');
      final data = (rows as List)
          .whereType<Map>()
          .map((row) =>
              CareScheduleModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      await _cache.saveList(
        AppConstants.boxCareSchedules,
        _scheduleKey,
        data.map((item) => item.toJson()).toList(),
      );
    } catch (_) {
      // Cache tetap dipakai.
    }
  }

  Future<void> addSchedule({
    required String activityType,
    required DateTime scheduledDate,
    String? commodityId,
    String? notes,
  }) async {
    final userId = _requireUserId;
    if (activityType.trim().isEmpty) {
      throw const AuthException('Jenis perawatan wajib dipilih');
    }
    await _client.from(AppConstants.tableCareSchedules).insert({
      'user_id': userId,
      'activity_type': activityType.trim(),
      'scheduled_date': _dateOnly(scheduledDate),
      'commodity_id': commodityId,
      'notes': _nullable(notes),
      'is_completed': false,
    });
  }

  Future<void> setScheduleCompleted(
    String scheduleId, {
    required bool isCompleted,
  }) async {
    await _client
        .from(AppConstants.tableCareSchedules)
        .update({
          'is_completed': isCompleted,
          'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
        })
        .eq('id', scheduleId)
        .eq('user_id', _requireUserId);
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _client
        .from(AppConstants.tableCareSchedules)
        .delete()
        .eq('id', scheduleId)
        .eq('user_id', _requireUserId);
  }

  Future<List<FarmFinanceModel>> fetchFinance({
    bool forceRefresh = false,
  }) async {
    final userId = _requireUserId;
    if (!forceRefresh) {
      final cached = _cache.getList(AppConstants.boxFinance, _financeKey);
      if (cached.isNotEmpty) {
        unawaited(_refreshFinance(userId));
        return cached.map(FarmFinanceModel.fromJson).toList();
      }
    }
    try {
      final rows = await _client
          .from(AppConstants.tableFinance)
          .select()
          .eq('user_id', userId)
          .order('transaction_date', ascending: false)
          .limit(200);
      final data = (rows as List)
          .whereType<Map>()
          .map((row) =>
              FarmFinanceModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      await _cache.saveList(
        AppConstants.boxFinance,
        _financeKey,
        data.map((item) => item.toJson()).toList(),
      );
      return data;
    } catch (error) {
      if (_isNetworkError(error)) {
        final cached = _cache.getList(AppConstants.boxFinance, _financeKey);
        return cached.map(FarmFinanceModel.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<void> _refreshFinance(String userId) async {
    try {
      final rows = await _client
          .from(AppConstants.tableFinance)
          .select()
          .eq('user_id', userId)
          .order('transaction_date', ascending: false)
          .limit(200);
      final data = (rows as List)
          .whereType<Map>()
          .map((row) =>
              FarmFinanceModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      await _cache.saveList(
        AppConstants.boxFinance,
        _financeKey,
        data.map((item) => item.toJson()).toList(),
      );
    } catch (_) {
      // Cache tetap dipakai.
    }
  }

  Future<void> addFinance({
    required String category,
    required double amount,
    required DateTime transactionDate,
    String? notes,
  }) async {
    final userId = _requireUserId;
    if (category != AppConstants.financeIncome &&
        category != AppConstants.financeExpense) {
      throw const AuthException('Jenis catatan tidak valid');
    }
    if (!amount.isFinite || amount <= 0) {
      throw const AuthException('Nominal harus lebih dari 0');
    }
    if (amount > 1000000000) {
      throw const AuthException('Nominal terlalu besar');
    }
    await _client.from(AppConstants.tableFinance).insert({
      'user_id': userId,
      'category': category,
      'amount': amount,
      'transaction_date': _dateOnly(transactionDate),
      'notes': _nullable(notes),
    });
  }

  Future<void> deleteFinance(String id) async {
    await _client
        .from(AppConstants.tableFinance)
        .delete()
        .eq('id', id)
        .eq('user_id', _requireUserId);
  }

  static FinanceSummary summarize(List<FarmFinanceModel> logs) {
    var income = 0.0;
    var expense = 0.0;
    for (final log in logs) {
      if (log.isIncome) {
        income += log.amount;
      } else {
        expense += log.amount;
      }
    }
    return FinanceSummary(income: income, expense: expense);
  }

  /// Membuat tagihan langganan Pro. Status tetap `pending` sampai admin
  /// memverifikasi pembayaran; aplikasi tidak pernah menaikkan is_pro sendiri.
  Future<String> requestProSubscription(ProPlan plan) async {
    final userId = _requireUserId;
    final invoice = 'PRO-${DateTime.now().millisecondsSinceEpoch}';
    try {
      final raw = await _client.rpc(
        'request_pro_subscription',
        params: {
          'p_plan_days': plan.days,
          'p_amount': plan.price,
          'p_invoice_number': invoice,
        },
      );
      if (raw is Map && raw['invoice_number'] != null) {
        return raw['invoice_number'].toString();
      }
      if (raw is String && raw.isNotEmpty) return raw;
    } catch (_) {
      // RPC belum dipasang: simpan tagihan pending secara langsung.
      // Tidak ada kolom privilese yang ditulis dari klien.
    }
    await _client.from(AppConstants.tableSubscriptions).insert({
      'user_id': userId,
      'amount': plan.price,
      'payment_method': 'transfer',
      'payment_status': 'pending',
      'invoice_number': invoice,
    });
    return invoice;
  }

  static String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String? _nullable(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error.toString().toLowerCase().contains('socket') ||
      error.toString().toLowerCase().contains('network');
}
