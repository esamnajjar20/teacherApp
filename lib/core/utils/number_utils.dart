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

/// يعرض الرقم بدون ".0" الزائدة (20.0 → 20 ، 17.5 → 17.5).
String formatNumber(num value) {
  final d = value.toDouble();
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toString();
}
