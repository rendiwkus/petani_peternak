import 'package:flutter_test/flutter_test.dart';
import 'package:petani_peternak/core/utils/formatters.dart';

void main() {
  group('normalizePhone', () {
    test('mengubah 08xx menjadi +62', () {
      expect(AppFormatters.normalizePhone('0812 3456 7890'), '+6281234567890');
    });

    test('menerima format 62 dan +62 tanpa duplikasi', () {
      expect(AppFormatters.normalizePhone('62812-3456-7890'), '+6281234567890');
      expect(AppFormatters.normalizePhone('+62 812 3456 7890'),
          '+6281234567890');
    });

    test('menerima nomor tanpa awalan', () {
      expect(AppFormatters.normalizePhone('81234567890'), '+6281234567890');
    });

    test('string kosong tetap kosong', () {
      expect(AppFormatters.normalizePhone('   '), '');
    });
  });

  group('displayPhone', () {
    test('menampilkan nomor lokal dengan tanda hubung', () {
      expect(AppFormatters.displayPhone('+6281234567890'), '0812-3456-7890');
    });

    test('null menjadi tanda hubung', () {
      expect(AppFormatters.displayPhone(null), '-');
    });
  });

  group('validasi input', () {
    test('nomor HP terlalu pendek ditolak', () {
      expect(AppFormatters.validatePhone('0812'), isNotNull);
    });

    test('nomor HP wajar diterima', () {
      expect(AppFormatters.validatePhone('081234567890'), isNull);
    });

    test('OTP wajib 6 angka', () {
      expect(AppFormatters.validateOtp('12345'), isNotNull);
      expect(AppFormatters.validateOtp('12a456'), isNotNull);
      expect(AppFormatters.validateOtp('123456'), isNull);
    });

    test('email tanpa domain ditolak', () {
      expect(AppFormatters.validateEmail('petani@desa'), isNotNull);
      expect(AppFormatters.validateEmail('petani@desa.id'), isNull);
    });
  });

  group('splitSteps', () {
    test('memisahkan langkah bernomor dari teks solusi', () {
      const raw = '1. Buang daun keriting\n2. Semprot abamectin sore hari\n'
          '3. Beri pupuk NPK';
      final steps = AppFormatters.splitSteps(raw);
      expect(steps, hasLength(3));
      expect(steps.first, 'Buang daun keriting');
    });

    test('memakai titik koma saat teks satu baris', () {
      expect(
        AppFormatters.splitSteps('Cabut gulma; semprot jamur; kurangi air'),
        hasLength(3),
      );
    });
  });

  test('truncate tidak memotong teks pendek', () {
    expect(AppFormatters.truncate('padi', 10), 'padi');
    expect(AppFormatters.truncate('padi sawah', 4), 'padi...');
  });
}
