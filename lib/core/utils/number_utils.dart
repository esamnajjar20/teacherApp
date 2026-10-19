/// أدوات التعامل مع الأرقام المُدخلة من لوحة المفاتيح العربية.

/// يحوّل الأرقام العربية الهندية (٠-٩) والفارسية (۰-۹) إلى أرقام لاتينية.
String normalizeDigits(String input) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var s = input;
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(arabicIndic[i], '$i').replaceAll(persian[i], '$i');
  }
  return s;
}

/// يحوّل نصاً يحتوي أرقاماً عربية/فارسية وفاصلة عربية إلى [double].
/// يرجع null إذا كان النص غير صالح (بما فيه NaN و Infinity).
double? parseNumber(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;

  s = normalizeDigits(s);
  s = s.replaceAll('٫', '.').replaceAll('،', '.').replaceAll(',', '.');

  final value = double.tryParse(s);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// يعرض الرقم بشكل مختصر وآمن:
/// - 20.0 → "20"
/// - 17.5 → "17.5"
/// - 17.333333333 → "17.33"   (بحد أقصى منزلتين عشريتين)
/// - 0.1 + 0.2 → "0.3"        (يتجنب floating point artifacts)
String formatNumber(num value) {
  final d = value.toDouble();
  if (!d.isFinite) return d.toString();
  if (d == d.roundToDouble()) return d.toInt().toString();

  // نقرّب لخانتين عشريتين ثم نزيل الأصفار الزائدة
  var s = d.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
