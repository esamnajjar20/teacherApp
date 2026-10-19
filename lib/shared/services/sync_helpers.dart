import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_message.dart';
import '../local/local_database.dart';

/// سجل تعذّر رفعه للسيرفر (مثل قيد CHECK أو رقم طالب مكرر).
class SyncFailure {
  final String table;
  final String rowId;

  /// وصف مفهوم للمعلم، مثل: «طالب: أحمد علي»
  final String label;
  final String message;
  final int attempts;

  /// قيمة updated_at للسجل وقت الفشل؛ إن تغيّرت (عدّله المعلم) نعيد المحاولة فوراً
  final String? updatedAt;

  /// لا نعيد المحاولة قبل هذا الوقت (تأخير تصاعدي)
  final DateTime nextAttempt;

  const SyncFailure({
    required this.table,
    required this.rowId,
    required this.label,
    required this.message,
    required this.attempts,
    required this.updatedAt,
    required this.nextAttempt,
  });
}

/// مدة الانتظار قبل إعادة محاولة سجل فشل رفعه [attempts] مرة:
/// دقيقة، دقيقتان، 4، 8، 16، ثم 30 دقيقة كحد أقصى.
Duration retryDelay(int attempts) {
  final n = attempts < 1 ? 1 : attempts;
  final shift = n - 1 > 5 ? 5 : n - 1;
  final seconds = 60 * (1 << shift);
  return Duration(seconds: seconds > 1800 ? 1800 : seconds);
}

/// يسحب الصفحات واحدة بعد أخرى حتى تصل صفحة فارغة.
///
/// لا نعتمد على "الصفحة أقل من حجم الطلب" لأن السيرفر قد يقتطع النتيجة عند
/// Max Rows أصغر من حجم الصفحة، وعندها كان السحب يتوقف بصمت وتضيع الصفوف.
/// يرجع مجموع الصفوف المسحوبة.
Future<int> fetchAllPages<T>({
  required Future<List<T>> Function(int offset) fetch,
  required Future<void> Function(List<T> page) onPage,
}) async {
  var offset = 0;
  while (true) {
    final page = await fetch(offset);
    if (page.isEmpty) break;
    await onPage(page);
    offset += page.length;
  }
  return offset;
}

/// رسالة عربية مفهومة لسبب فشل رفع سجل.
String pushErrorMessage(Object e) {
  if (e is PostgrestException) {
    final text = '${e.message} ${e.details ?? ''}';
    switch (e.code) {
      case '23505':
        if (text.contains('uq_students_teacher_code')) {
          return 'رقم الطالب مستخدم لطالب آخر على الخادم، عدّل الرقم';
        }
        if (text.contains('uq_daily_attendance') ||
            text.contains('uq_period_attendance')) {
          return 'توجد جلسة حضور لنفس اليوم على الخادم';
        }
        return 'السجل مكرر على الخادم';
      case '23514':
        return 'قيمة رفضها الخادم (خارج المسموح)';
      case '23503':
        return 'مرتبط بسجل غير موجود على الخادم';
      case '42501':
        return 'ليس لديك صلاحية لرفع هذا السجل';
    }
  }
  return friendlyError(e);
}

/// تحويل الصفوف بين شكل SQLite المحلي وشكل السيرفر.
class SyncCodec {
  SyncCodec._();

  /// صف محلي → صف للرفع. أوقات created_at/updated_at يضعها السيرفر.
  static Map<String, dynamic> toServer(TableDef t, Map<String, Object?> row) {
    final m = <String, dynamic>{};
    for (final e in t.cols.entries) {
      if (e.key == 'created_at' || e.key == 'updated_at') continue;
      Object? v = row[e.key];
      if (v != null) {
        if (e.value == ColType.boolean) {
          v = v == 1;
        } else if (e.value == ColType.json) {
          v = jsonDecode(v as String);
        }
      }
      m[e.key] = v;
    }
    return m;
  }

  /// صف من السيرفر → صف محلي (dirty = 0).
  static Map<String, Object?> fromServer(TableDef t, Map<String, dynamic> r) {
    final m = <String, Object?>{};
    for (final e in t.cols.entries) {
      Object? v = r[e.key];
      if (v != null) {
        if (e.value == ColType.boolean) {
          v = (v == true) ? 1 : 0;
        } else if (e.value == ColType.json) {
          v = jsonEncode(v);
        }
      }
      m[e.key] = v;
    }
    m['dirty'] = 0;
    return m;
  }
}
