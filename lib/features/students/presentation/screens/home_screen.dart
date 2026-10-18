import 'package:flutter/material.dart';
import '../../../../core/constants/supabase_client.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../shared/services/sync_service.dart';
import '../../../attendance/presentation/screens/attendance_list_screen.dart';
import '../../../grades/presentation/screens/grades_list_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import 'classes_screen.dart';
import 'students_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    SyncService.instance.start();
  }

  Widget _syncButton() {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.status,
      builder: (context, st, _) {
        IconData icon;
        Color? color;
        String tip;
        if (st.syncing) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          );
        } else if (st.error != null) {
          icon = Icons.cloud_off;
          color = Colors.orangeAccent;
          tip = 'غير متزامن: ${st.error}';
        } else if (st.pending > 0) {
          icon = Icons.cloud_upload_outlined;
          tip = '${st.pending} تعديل بانتظار الرفع';
        } else {
          icon = Icons.cloud_done_outlined;
          tip = 'كل البيانات متزامنة';
        }
        return IconButton(
          icon: Badge(
            isLabelVisible: st.pending > 0,
            label: Text('${st.pending}'),
            child: Icon(icon, color: color),
          ),
          tooltip: tip,
          onPressed: () async {
            await SyncService.instance.sync();
            if (!mounted) return;
            final s = SyncService.instance.status.value;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  s.error != null
                      ? s.error!
                      : (s.pending > 0
                          ? '${s.pending} تعديل بانتظار الرفع'
                          : 'تمت المزامنة'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  final List<Widget> _screens = const [
    ClassesScreen(),
    StudentsScreen(),
    AttendanceListScreen(),
    GradesListScreen(),
  ];

  Future<void> _signOut() async {
    try {
      // التنقل لشاشة الدخول يتم تلقائياً من مستمع onAuthStateChange في main.dart
      await supabase.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق المعلمين'),
        actions: [
          _syncButton(),
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'التقارير',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _signOut();
                      },
                      child: const Text('خروج'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      // عند وصول بيانات جديدة من السيرفر نعيد بناء التبويب الحالي ليقرأها
      body: ValueListenableBuilder<int>(
        valueListenable: SyncService.instance.dataVersion,
        builder: (context, version, _) => KeyedSubtree(
          key: ValueKey(version),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            selectedIcon: Icon(Icons.class_),
            label: 'الفصول',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'الطلاب',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'الحضور',
          ),
          NavigationDestination(
            icon: Icon(Icons.grade_outlined),
            selectedIcon: Icon(Icons.grade),
            label: 'الدرجات',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                user?.userMetadata?['full_name']?.toString() ?? 'معلم',
              ),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user?.email?.isNotEmpty == true)
                      ? user!.email![0].toUpperCase()
                      : 'م',
                  style: TextStyle(
                    fontSize: 28,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            ),
            ListTile(
              leading: const Icon(Icons.assessment_outlined),
              title: const Text('التقارير والتصدير'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('حول التطبيق'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'تطبيق المعلمين',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'يعمل بدون إنترنت ويتزامن مع الخادم تلقائياً',
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
