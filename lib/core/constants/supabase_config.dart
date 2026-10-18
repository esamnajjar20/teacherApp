/// إعدادات Supabase.
///
/// لا تضع المفاتيح داخل الكود. مرّرها وقت التشغيل/البناء:
///
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// صحيح فقط إذا تم تمرير قيم حقيقية.
  static bool get isConfigured =>
      url.startsWith('http') && anonKey.isNotEmpty;
}
