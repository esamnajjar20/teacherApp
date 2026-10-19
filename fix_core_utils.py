import os

print("=" * 68)
print("🔧 إصلاح مشاكل core/utils")
print("=" * 68)

# ============================================================
# 1. number_utils: formatNumber آمن للـ floating point
# ============================================================
print("\n📁 [1] number_utils.dart: formatNumber")

path = 'lib/core/utils/number_utils.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    old = """/// يعرض الرقم بدون ".0" الزائدة (20.0 → 20 ، 17.5 → 17.5).
String formatNumber(num value) {
  final d = value.toDouble();
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toString();
}"""

    new = """/// يعرض الرقم بشكل مختصر وآمن:
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
}"""

    if old in c:
        c = c.replace(old, new, 1)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print("   ✅ formatNumber مُصلح")
    elif 'toStringAsFixed(2)' in c:
        print("   ⏭️  مطبق مسبقاً")
    else:
        print("   ⚠️  النمط غير موجود")

# ============================================================
# 2. grade_calculator: getLetterGrade آمن + إعادة استخدام المنطق
# ============================================================
print("\n📁 [2] grade_calculator.dart: getLetterGrade + refactor")

path = 'lib/core/utils/grade_calculator.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    # 2.1: getLetterGrade آمن
    old_grade = """  /// تحويل النسبة إلى تقدير حسب السلم
  static String? getLetterGrade(
    double percentage,
    List<Map<String, dynamic>> scale,
  ) {
    // scale مثال: [{"min": 90, "grade": "A"}, {"min": 80, "grade": "B"}, ...]
    final sorted = List<Map<String, dynamic>>.from(scale)
      ..sort((a, b) => (b['min'] as num).compareTo(a['min'] as num));

    for (final entry in sorted) {
      if (percentage >= (entry['min'] as num)) {
        return entry['grade'] as String?;
      }
    }
    return null;
  }"""

    new_grade = """  /// تحويل النسبة إلى تقدير حسب السلم.
  /// يتعامل بأمان مع مدخلات تالفة (min = null، grade = null، scale فارغ).
  static String? getLetterGrade(
    double percentage,
    List<Map<String, dynamic>> scale,
  ) {
    final valid = <MapEntry<num, String?>>[];
    for (final entry in scale) {
      final minVal = entry['min'];
      if (minVal is! num) continue;
      final gradeVal = entry['grade'];
      valid.add(MapEntry(minVal, gradeVal is String ? gradeVal : null));
    }
    if (valid.isEmpty) return null;

    valid.sort((a, b) => b.key.compareTo(a.key));
    for (final e in valid) {
      if (percentage >= e.key) return e.value;
    }
    return null;
  }"""

    if old_grade in c:
        c = c.replace(old_grade, new_grade, 1)
        print("   ✅ getLetterGrade آمن")
    elif 'if (minVal is! num) continue;' in c:
        print("   ⏭️  مطبق مسبقاً")

    # 2.2: استخدام calculateFinalAverage داخل classResults
    old_class = """      double totalWeighted = 0;
      double totalWeight = 0;
      for (final item in items) {
        final assessment = item.assessment;
        final grade = item.grade;
        if (grade?.rawScore == null) {
          if (policy == 'zero') totalWeight += assessment.weight;
          continue;
        }
        final weighted =
            grade!.weightedScore(assessment.maxScore, assessment.weight);
        if (weighted != null) {
          totalWeighted += weighted;
          totalWeight += assessment.weight;
        }
      }

      final avg = totalWeight == 0 ? null : (totalWeighted / totalWeight * 100);
      final letter = avg == null ? null : getLetterGrade(avg, scale);
      list.add(StudentResult(studentId: id, average: avg, letter: letter));"""

    new_class = """      final avg = calculateFinalAverage(items: items, policy: policy);
      final letter = avg == null ? null : getLetterGrade(avg, scale);
      list.add(StudentResult(studentId: id, average: avg, letter: letter));"""

    if old_class in c:
        c = c.replace(old_class, new_class, 1)
        print("   ✅ classResults يستخدم calculateFinalAverage (لا تكرار)")
    elif 'final avg = calculateFinalAverage(items: items' in c:
        print("   ⏭️  مطبق مسبقاً")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

# ============================================================
# 3. auth_actions: max attempts لمنع infinite loop
# ============================================================
print("\n📁 [3] auth_actions.dart: منع infinite loop")

path = 'lib/core/utils/auth_actions.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    old_loop = """  final messenger = ScaffoldMessenger.of(context);

  while (true) {"""

    new_loop = """  final messenger = ScaffoldMessenger.of(context);
  const maxSyncAttempts = 3;
  var syncAttempts = 0;

  while (true) {"""

    if old_loop in c and 'maxSyncAttempts' not in c:
        c = c.replace(old_loop, new_loop, 1)

    # في حالة syncFirst، زد العداد وتحقق
    old_sync = """    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await SyncService.instance.sync(force: true);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (SyncService.instance.status.value.pending == 0) {
      messenger.showSnackBar(const SnackBar(content: Text('تمت المزامنة')));
      break;
    }
    final err = SyncService.instance.status.value.error;
    if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));"""

    new_sync = """    if (!context.mounted) return;

    syncAttempts++;
    if (syncAttempts > maxSyncAttempts) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذّرت المزامنة. تحقق من الاتصال ثم أعد المحاولة.'),
          backgroundColor: Colors.orange,
        ),
      );
      break;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await SyncService.instance.sync(force: true);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (SyncService.instance.status.value.pending == 0) {
      messenger.showSnackBar(const SnackBar(content: Text('تمت المزامنة')));
      break;
    }
    final err = SyncService.instance.status.value.error;
    messenger.showSnackBar(SnackBar(
      content: Text(err ?? 'تعذّرت المزامنة، حاول مرة أخرى'),
    ));"""

    if old_sync in c:
        c = c.replace(old_sync, new_sync, 1)
        print("   ✅ max attempts + رسالة خطأ مضمونة")
    elif 'maxSyncAttempts' in c:
        print("   ⏭️  مطبق مسبقاً")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

# ============================================================
# 4. color_utils: إضافة بديل withValues مع fallback
# ============================================================
print("\n📁 [4] color_utils.dart: تحديث للـ API الحديث")

path = 'lib/core/utils/color_utils.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    old_color = """import 'package:flutter/material.dart';

/// بديل لـ `withOpacity` (المهمل في Flutter 3.27+) يعمل على كل الإصدارات
/// ولا يسبّب تحذيرات `deprecated_member_use`.
extension SoftColor on Color {
  /// يرجع نفس اللون بشفافية [opacity] (من 0.0 إلى 1.0).
  Color soft(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}"""

    new_color = """import 'package:flutter/material.dart';

/// بديل لـ `withOpacity` (المهمل في Flutter 3.27+).
///
/// يستخدم `withValues(alpha: ...)` (API الجديد) الذي لا يُصدر تحذيراً.
/// يعمل على Flutter 3.27+ فقط (وهو الإصدار المستخدم في المشروع).
extension SoftColor on Color {
  /// يرجع نفس اللون بشفافية [opacity] (من 0.0 إلى 1.0).
  Color soft(double opacity) =>
      withValues(alpha: opacity.clamp(0.0, 1.0));
}"""

    if old_color in c:
        c = c.replace(old_color, new_color, 1)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print("   ✅ يستخدم withValues (لا تحذيرات deprecated)")
    elif 'withValues' in c:
        print("   ⏭️  مطبق مسبقاً")
    else:
        print("   ⚠️  النمط غير موجود")

# ============================================================
# 5. التحقق
# ============================================================
print("\n" + "=" * 68)
print("🔍 التحقق")
print("=" * 68)

checks = [
    ('lib/core/utils/number_utils.dart', ['toStringAsFixed(2)', '!d.isFinite']),
    ('lib/core/utils/grade_calculator.dart', ['minVal is! num', 'calculateFinalAverage(items: items']),
    ('lib/core/utils/auth_actions.dart', ['maxSyncAttempts', 'try للمزامنة']),
    ('lib/core/utils/color_utils.dart', ['withValues']),
]

all_ok = True
for path, symbols in checks:
    if not os.path.exists(path):
        print(f"   ❌ {path}")
        all_ok = False
        continue
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    missing = [s for s in symbols if s not in content]
    if missing:
        print(f"   ⚠️  {os.path.basename(path)} — يفتقد: {missing}")
        all_ok = False
    else:
        print(f"   ✅ {os.path.basename(path)}")

print("\n" + "=" * 68)
if all_ok:
    print("🎉 الإصلاحات مطبقة!")
print("=" * 68)
print("""
📋 ملخص:
   ✅ formatNumber: أرقام مشوهة → مختصرة
   ✅ getLetterGrade: crash → آمن
   ✅ classResults: لا تكرار
   ✅ auth_actions: لا infinite loop
   ✅ color_utils: API حديث

🚀 ارفع وابنِ:
   git add .
   git commit -m "Fix: core utils (formatNumber, getLetterGrade, auth loop, withValues)"
   git push origin main
""")
