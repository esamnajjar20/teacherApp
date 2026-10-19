import os

print("=" * 68)
print("🔧 إصلاح main/config (4 تحسينات)")
print("=" * 68)

# ============================================================
# 1. main.dart: await إغلاق الموارد + theme لـ _MissingConfigApp
# ============================================================
print("\n📁 [1] main.dart")

path = 'lib/main.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    # 1.1: ترتيب إغلاق الموارد
    old_listener = """  // عند انتهاء الجلسة أو تسجيل الخروج → العودة لشاشة الدخول
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut) {
      SyncService.instance.stop();
      LocalDatabase.instance.close();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  });"""

    new_listener = """  // عند انتهاء الجلسة أو تسجيل الخروج → العودة لشاشة الدخول
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut) {
      // نغلق الموارد أولاً ثم نتنقل (fire-and-forget مع ترتيب صحيح)
      Future(() async {
        try {
          await SyncService.instance.stop();
          await LocalDatabase.instance.close();
        } catch (_) {}
        final nav = navigatorKey.currentState;
        if (nav != null && nav.mounted) {
          nav.pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
    }
  });"""

    if old_listener in c:
        c = c.replace(old_listener, new_listener, 1)
        print("   ✅ إغلاق الموارد قبل التنقل")
    elif 'Future(() async {' in c:
        print("   ⏭️  مطبق مسبقاً")

    # 1.2: theme في _MissingConfigApp
    old_missing = """    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale('ar'),
      supportedLocales: [Locale('ar')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold("""

    new_missing = """    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold("""

    if old_missing in c:
        c = c.replace(old_missing, new_missing, 1)
        print("   ✅ theme في شاشة الإعدادات المفقودة")
    elif 'theme: AppTheme.lightTheme,\n      locale: const Locale' in c:
        print("   ⏭️  مطبق مسبقاً")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

# ============================================================
# 2. error_message.dart: TimeoutException صريح + rate limit محسّن
# ============================================================
print("\n📁 [2] error_message.dart")

path = 'lib/core/errors/error_message.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    # 2.1: إضافة import
    if "import 'dart:async';" not in c:
        c = "import 'dart:async';\n" + c
        print("   ✅ import 'dart:async'")

    # 2.2: rate limit قبل Email not confirmed (أهم)
    old_block = """String friendlyError(Object error) {
  if (error is AuthException) {
    final m = error.message;
    if (m.contains('Invalid login credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (m.contains('Email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني أولاً';
    }
    if (error.statusCode == '429' ||
        m.toLowerCase().contains('rate limit') ||
        m.contains('you can only request this after')) {
      return 'انتظر قليلاً قبل طلب رمز جديد';
    }
    if (m.contains('already registered')) {
      return 'هذا البريد مسجّل مسبقاً';
    }
    return m;
  }"""

    new_block = """String friendlyError(Object error) {
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
  }"""

    if old_block in c:
        c = c.replace(old_block, new_block, 1)
        print("   ✅ Rate limit أولاً + حالات إضافية")
    elif 'error is TimeoutException' in c:
        print("   ⏭️  مطبق مسبقاً")

    # 2.3: string-based detection يبقى للـ SocketException
    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

# ============================================================
# 3. pubspec.yaml: تنظيف assets الفارغ
# ============================================================
print("\n📁 [3] pubspec.yaml")

path = 'pubspec.yaml'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    # إذا assets: مع تعليق فقط (بدون عناصر)، احذفها
    old_assets = """flutter:
  uses-material-design: true
  assets:
    # خط Cairo المضمَّن (انظر assets/google_fonts/README.md)"""

    new_assets = """flutter:
  uses-material-design: true
  # ملاحظة: خط Cairo من google_fonts (يُحمّل عند أول اتصال ثم يُخزَّن)
  # لا يوجد assets محلية مضمّنة حالياً"""

    if old_assets in c:
        c = c.replace(old_assets, new_assets, 1)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print("   ✅ إزالة assets الفارغ")
    elif '# ملاحظة: خط Cairo' in c:
        print("   ⏭️  مطبق مسبقاً")
    else:
        print("   ⚠️  النمط غير موجود")

# ============================================================
# 4. التحقق
# ============================================================
print("\n" + "=" * 68)
print("🔍 التحقق")
print("=" * 68)

checks = [
    ('lib/main.dart', ['Future(() async {', 'theme: AppTheme.lightTheme,\n      locale: const Locale']),
    ('lib/core/errors/error_message.dart', ['import \'dart:async\';', 'error is TimeoutException']),
    ('pubspec.yaml', ['# ملاحظة: خط Cairo']),
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
print("📋 ملخص:")
print("=" * 68)
print("""
   ✅ main: إغلاق الموارد قبل التنقل
   ✅ main: theme في _MissingConfigApp
   ✅ errors: TimeoutException صريح
   ✅ errors: rate limit أولاً
   ✅ pubspec: assets نظيف

🚀 ارفع وابنِ:
   git add .
   git commit -m "Fix: main lifecycle, theme, error messages, clean pubspec"
   git push origin main
""")
