import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'shared/local/local_database.dart';
import 'shared/services/sync_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  // تهيئة Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // عند انتهاء الجلسة أو تسجيل الخروج → العودة لشاشة الدخول
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut) {
      SyncService.instance.stop();
      LocalDatabase.instance.close();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  });

  runApp(
    const ProviderScope(
      child: TeacherApp(),
    ),
  );
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'تطبيق المعلمين',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}

/// تظهر عند نسيان تمرير مفاتيح Supabase بدل انهيار التطبيق.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale('ar'),
      supportedLocales: [Locale('ar')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'لم يتم ضبط إعدادات Supabase.\n\n'
              'شغّل التطبيق مع:\n'
              '--dart-define=SUPABASE_URL=...\n'
              '--dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.8),
            ),
          ),
        ),
      ),
    );
  }
}
