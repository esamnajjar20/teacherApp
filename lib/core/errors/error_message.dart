import 'package:supabase_flutter/supabase_flutter.dart';

/// يحوّل أي استثناء إلى رسالة عربية مفهومة للمستخدم.
String friendlyError(Object error) {
  if (error is AuthException) {
    final m = error.message;
    if (m.contains('Invalid login credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (m.contains('Email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني أولاً';
    }
    if (m.contains('already registered')) {
      return 'هذا البريد مسجّل مسبقاً';
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
