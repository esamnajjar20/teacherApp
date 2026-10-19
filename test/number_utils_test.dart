import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/core/utils/number_utils.dart';

void main() {
  group('normalizeDigits', () {
    test('يحوّل الأرقام العربية والفارسية', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(normalizeDigits('A-١٢'), 'A-12');
    });
  });

  group('parseNumber', () {
    test('أرقام لاتينية وعربية', () {
      expect(parseNumber('20'), 20);
      expect(parseNumber('٢٠'), 20);
      expect(parseNumber(' 17.5 '), 17.5);
    });

    test('فاصلة عشرية عربية وعادية', () {
      expect(parseNumber('٢٠٫٥'), 20.5);
      expect(parseNumber('١٫٥'), 1.5);
      expect(parseNumber('1,5'), 1.5);
      expect(parseNumber('1،5'), 1.5);
    });

    test('قيم غير صالحة ترجع null', () {
      expect(parseNumber(''), isNull);
      expect(parseNumber('   '), isNull);
      expect(parseNumber('abc'), isNull);
      expect(parseNumber('NaN'), isNull);
      expect(parseNumber('Infinity'), isNull);
    });
  });

  group('formatNumber', () {
    test('يحذف .0 الزائدة', () {
      expect(formatNumber(20.0), '20');
      expect(formatNumber(20), '20');
      expect(formatNumber(17.5), '17.5');
    });
  });
}
