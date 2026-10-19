/// أدوات تحليل آمنة للحقول الاختيارية.
///
/// النماذج تقرأ من SQLite حيث قد تكون الحقول ناقصة (بيانات قديمة،
/// migration جزئي، أو خطأ مزامنة). الدوال هنا **لا ترمي استثناءات**؛
/// ترجع قيماً افتراضية معقولة بدل انهيار التطبيق.
class SafeParse {
  SafeParse._();

  /// `null` عند الفشل (يُستخدم للحقول الاختيارية).
  static DateTime? dateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// `DateTime.now()` عند الفشل (للحقول الإلزامية).
  static DateTime dateTimeOrNow(Object? value) =>
      dateTime(value) ?? DateTime.now();

  static String string(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  static String? stringOrNull(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static double? doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static double doubleOr(Object? value, [double fallback = 0.0]) =>
      doubleOrNull(value) ?? fallback;

  static bool boolOr(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final l = value.toLowerCase();
      return l == 'true' || l == '1';
    }
    return fallback;
  }
}
