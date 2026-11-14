import 'package:intl/intl.dart';

/// Helper format data yang dipakai lintas fitur.
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _rupiah =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static final DateFormat _date = DateFormat('d MMM yyyy', 'id_ID');
  static final DateFormat _dateLong = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
  static final DateFormat _time = DateFormat('HH:mm', 'id_ID');

  /// Normalisasi nomor HP Indonesia ke format E.164 (+62...).
  static String normalizePhone(String rawPhone) {
    var digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('620')) {
      digits = '62${digits.substring(3)}';
    } else if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      digits = '62$digits';
    } else if (digits.startsWith('62')) {
      // sudah benar
    }
    return digits.isEmpty ? '' : '+$digits';
  }

  /// Nomor untuk tampilan ramah: 0812-3456-7890.
  static String displayPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62')) digits = '0${digits.substring(2)}';
    if (digits.length < 8) return digits;
    final middleStart = digits.length > 8 ? 4 : 3;
    final middleEnd = digits.length - 4;
    return '${digits.substring(0, middleStart)}-'
        '${digits.substring(middleStart, middleEnd)}-'
        '${digits.substring(middleEnd)}';
  }

  static String rupiah(num value) => _rupiah.format(value);

  static String date(DateTime? value) =>
      value == null ? '-' : _date.format(value.toLocal());

  static String dateLong(DateTime? value) =>
      value == null ? '-' : _dateLong.format(value.toLocal());

  static String time(DateTime? value) =>
      value == null ? '' : _time.format(value.toLocal());

  static String relative(DateTime? value) {
    if (value == null) return '';
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return date(value);
  }

  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  static String? validatePhone(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 'Nomor HP wajib diisi';
    if (digits.length < 9 || digits.length > 15) {
      return 'Nomor HP tidak valid (9-15 angka)';
    }
    return null;
  }

  static String? validateOtp(String? value) {
    final code = (value ?? '').trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      return 'Kode harus 6 angka';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  static String? validateRequired(String? value, {String label = 'Kolom'}) {
    if ((value ?? '').trim().isEmpty) return '$label wajib diisi';
    return null;
  }

  static String emptyToDash(String? value) =>
      (value == null || value.trim().isEmpty) ? '-' : value.trim();

  static List<String> splitSteps(String text) {
    final parts = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'^\s*\d+[\.\)]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (parts.length > 1) return parts;
    return text
        .split(RegExp(r'\s*;\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Membatasi teks panjang agar tidak membanjiri UI/DB.
  static String truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}...';
}
