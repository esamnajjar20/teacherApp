import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// يحوّل أي استثناء إلى رسالة عربية مفهومة للمستخدم.
String friendlyError(Object error) {
  if (error is TimeoutException) {
    return 'انتهت مهلة الاتصال، تحقق من الشبكة';
  }

  if (error is AuthException) {
    final m = error.message;
    // rate limit أولاً — أهم من تفاصيل أخرى
    if (error.statusCode == '429' ||
        m.toLowerCase().contains('rate limit') ||
        m.contains('you can only request this after')) {
      return 'طلبات كثيرة، انتظر دقيقة ثم حاول';
    }
    if (m.contains('Invalid login credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (m.contains('Email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني أولاً';
    }
    if (m.contains('already registered') ||
        m.contains('already exists')) {
      return 'هذا البريد مسجّل مسبقاً';
    }
    if (m.contains('Password should be')) {
      return 'كلمة المرور ضعيفة، اختر واحدة أقوى';
    }
    return m;
  }

  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return 'هذا السجل موجود مسبقاً';
      case '23514':
        return 'القيمة المدخلة غير مسموحة';
      case '23503':
        return 'السجل مرتبط ببيانات أخرى';
      case '42501':
        return 'ليس لديك صلاحية لتنفيذ هذه العملية';
      case 'PGRST301':
        return 'انتهت الجلسة، سجّل الدخول من جديد';
    }
    return 'تعذّر تنفيذ العملية (${error.message})';
  }

  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('TimeoutException')) {
    return 'لا يوجد اتصال بالإنترنت';
  }
  if (error is StateError) return error.message;
  return 'حدث خطأ غير متوقع';
}
