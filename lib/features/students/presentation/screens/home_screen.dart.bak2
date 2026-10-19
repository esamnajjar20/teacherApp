import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/supabase_client.dart';
import '../../../../core/utils/auth_actions.dart';
import '../../../../shared/services/database_service.dart';
import '../../../../shared/services/sync_service.dart';
import '../../../attendance/presentation/screens/attendance_list_screen.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../grades/presentation/screens/grades_list_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../trash/presentation/screens/trash_screen.dart';
import 'classes_screen.dart';
import 'students_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _db = DatabaseService();
  int _classesWithoutAttendance = 0;

  @override
  void initState() {
    super.initState();
    SyncService.instance.start();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final classes = await _db.getClasses();
      final today = DateTime.now();
      var count = 0;
      for (final c in classes) {
        final session = await _db.findSession(classId: c.id, date: today);
        if (session == null) count++;
      }
      if (mounted) setState(() => _classesWithoutAttendance = count);
    } catch (_) {}
  }

  Widget _buildDashboardBanner() {
    if (_classesWithoutAttendance == 0) return const SizedBox.shrink();
    final n = _classesWithoutAttendance;
    return Material(
      color: Colors.orange.shade50,
      child: InkWell(
        onTap: () {
          setState(() => _currentIndex = 2); // تبويب الحضور
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  n == 1
                      ? 'فصل واحد بدون حضور اليوم'
                      : '$n فصول بدون حضور اليوم',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              Text(
                'سجّل الآن',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
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
            await SyncService.instance.sync(force: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
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
        ],
      ),
      body: Column(
        children: [
          _buildDashboardBanner(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 0 || index == 2) _loadDashboard();
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
            StreamBuilder<AuthState>(
              stream: supabase.auth.onAuthStateChange,
              builder: (context, _) {
                final user = supabase.auth.currentUser;
                return UserAccountsDrawerHeader(
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
                  decoration:
                      BoxDecoration(color: Theme.of(context).primaryColor),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('حسابي'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('سلة المحذوفات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrashScreen()),
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
                  applicationName: AppConstants.appName,
                  applicationVersion: AppConstants.appVersion,
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
                confirmAndSignOut(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
