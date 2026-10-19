import os
import shutil

print("=" * 72)
print("🚀 الحزمة الثانية: Dashboard + إحصائيات + تصدير")
print("=" * 72)

def backup(path):
    if os.path.exists(path):
        shutil.copy(path, path + '.bak2')
        return True
    return False

# ============================================================
# [1/5] HomeScreen — Dashboard
# ============================================================
print("\n📁 [1/5] home_screen.dart — Dashboard")

path = 'lib/features/students/presentation/screens/home_screen.dart'
if backup(path):
    print(f"   💾 نسخة احتياطية: {path}.bak2")

    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    original = c

    # 1.1: إضافة import DatabaseService
    if "import '../../../../shared/services/database_service.dart';" not in c:
        c = c.replace(
            "import '../../../../shared/services/sync_service.dart';",
            "import '../../../../shared/services/database_service.dart';\n"
            "import '../../../../shared/services/sync_service.dart';",
            1
        )
        print("   ✅ إضافة import DatabaseService")

    # 1.2: إضافة state
    old_state = '''class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;'''
    new_state = '''class _HomeScreenState extends State<HomeScreen> {
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
  }'''
    if old_state in c and '_classesWithoutAttendance' not in c:
        c = c.replace(old_state, new_state, 1)
        print("   ✅ Dashboard state + banner")

    # إزالة initState المكرر (القديم)
    old_init = '''  @override
  void initState() {
    super.initState();
    SyncService.instance.start();
  }

  Widget _syncButton() {'''
    new_init = '''  Widget _syncButton() {'''
    if old_init in c and c.count('void initState()') > 1:
        c = c.replace(old_init, new_init, 1)
        print("   ✅ إزالة initState المكرر")

    # 1.3: عرض الـ banner في body
    old_body = '''      // كل تبويب يحدّث بياناته بصمت عند وصول تغييرات من السيرفر
      // (SyncRefreshMixin)، فلا يضيع نص البحث ولا موضع التمرير.
      body: _screens[_currentIndex],'''
    new_body = '''      body: Column(
        children: [
          _buildDashboardBanner(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),'''
    if old_body in c:
        c = c.replace(old_body, new_body, 1)
        print("   ✅ Dashboard banner في body")

    # 1.4: تحديث Dashboard عند العودة للتبويب
    old_nav = '''        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },'''
    new_nav = '''        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 0 || index == 2) _loadDashboard();
        },'''
    if old_nav in c:
        c = c.replace(old_nav, new_nav, 1)
        print("   ✅ تحديث Dashboard عند التنقل")

    if c != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print(f"   💾 حفظ")

# ============================================================
# [2/5] ClassDetailScreen — إحصائيات + تنبيهات
# ============================================================
print("\n📁 [2/5] class_detail_screen.dart — إحصائيات + تنبيهات")

path = 'lib/features/students/presentation/screens/class_detail_screen.dart'
if backup(path):
    print(f"   💾 نسخة احتياطية")

    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    original = c

    # 2.1: إضافة imports
    if "import '../../../../core/utils/attendance_calculator.dart';" not in c:
        c = c.replace(
            "import '../../../../core/errors/error_message.dart';",
            "import '../../../../core/errors/error_message.dart';\n"
            "import '../../../../core/utils/attendance_calculator.dart';",
            1
        )
    if "import '../../../../core/utils/color_utils.dart';" not in c:
        c = c.replace(
            "import '../../../../shared/services/database_service.dart';",
            "import '../../../../shared/services/database_service.dart';\n"
            "import '../../../../core/utils/color_utils.dart';",
            1
        )
    print("   ✅ إضافة imports")

    # 2.2: إضافة state للإحصائيات
    old_state = '''  final _db = DatabaseService();
  List<StudentModel> _enrolled = [];
  List<StudentModel> _allStudents = [];
  bool _isLoading = true;'''
    new_state = '''  final _db = DatabaseService();
  List<StudentModel> _enrolled = [];
  List<StudentModel> _allStudents = [];
  bool _isLoading = true;

  // إحصائيات
  int _sessionsCount = 0;
  double? _avgAttendance;
  int _atRiskCount = 0;
  List<({String name, double? percentage})> _atRiskStudents = [];'''
    if old_state in c and '_sessionsCount' not in c:
        c = c.replace(old_state, new_state, 1)
        print("   ✅ state الإحصائيات")

    # 2.3: تحديث _load لجلب الإحصائيات
    old_load = '''      final enrolled = await _db.getStudentsInClass(widget.classModel.id);
      final all = await _db.getStudents();
      if (!mounted) return;
      setState(() {
        _enrolled = enrolled;
        _allStudents = all;
        _isLoading = false;
      });'''
    new_load = '''      final enrolled = await _db.getStudentsInClass(widget.classModel.id);
      final all = await _db.getStudents();
      
      // جلب الإحصائيات
      final sessions = await _db.getSessionSummaries(widget.classModel.id);
      double? avgAtt;
      int atRisk = 0;
      List<({String name, double? percentage})> atRiskList = [];
      
      if (sessions.isNotEmpty && enrolled.isNotEmpty) {
        final sessionIds = sessions.take(50).map((s) => s.session.id).toList();
        final records = await _db.getRecordsForSessions(sessionIds);
        final stats = AttendanceCalculator.summarize(
          studentIds: enrolled.map((s) => s.id).toList(),
          records: records
              .map((r) => (studentId: r.studentId, status: r.status)),
        );
        avgAtt = AttendanceCalculator.classAverage(stats);
        final risk =
            stats.where((s) => AttendanceCalculator.isBelowThreshold(s.percentage)).toList();
        atRisk = risk.length;
        final nameById = {for (final s in enrolled) s.id: s.fullName};
        atRiskList = risk
            .map((s) => (
                  name: nameById[s.studentId] ?? '',
                  percentage: s.percentage,
                ))
            .toList()
          ..sort((a, b) =>
              (a.percentage ?? 100).compareTo(b.percentage ?? 100));
      }
      
      if (!mounted) return;
      setState(() {
        _enrolled = enrolled;
        _allStudents = all;
        _sessionsCount = sessions.length;
        _avgAttendance = avgAtt;
        _atRiskCount = atRisk;
        _atRiskStudents = atRiskList;
        _isLoading = false;
      });'''
    if old_load in c:
        c = c.replace(old_load, new_load, 1)
        print("   ✅ جلب الإحصائيات في _load")

    # 2.4: إضافة بطاقة الإحصائيات + التنبيهات
    old_buttons = '''                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ClassResultsScreen(classModel: widget.classModel),
                        ),
                      ),
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: const Text('نتائج الفصل والترتيب'),
                    ),
                  ),
                ),'''
    new_buttons = '''                // ===== إحصائيات الفصل =====
                if (_sessionsCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'الطلاب',
                            '${_enrolled.length}',
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statCard(
                            'الحصص',
                            '$_sessionsCount',
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statCard(
                            'متوسط الحضور',
                            _avgAttendance == null
                                ? '-'
                                : '${_avgAttendance!.toStringAsFixed(0)}%',
                            (_avgAttendance ?? 100) >= 75
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ===== تنبيه الطلاب المعرضين للخطر =====
                if (_atRiskStudents.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$_atRiskCount طالب بحضور منخفض (أقل من 75%)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final s in _atRiskStudents.take(5))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '• ${s.name} — ${s.percentage?.toStringAsFixed(0) ?? '-'}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          if (_atRiskStudents.length > 5)
                            Text(
                              '... و${_atRiskStudents.length - 5} آخرين',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // ===== الأزرار =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ClassResultsScreen(classModel: widget.classModel),
                        ),
                      ),
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: const Text('نتائج الفصل والترتيب'),
                    ),
                  ),
                ),'''
    if old_buttons in c:
        c = c.replace(old_buttons, new_buttons, 1)
        print("   ✅ بطاقة الإحصائيات + تنبيه المعرضين للخطر")

    # 2.5: دالة _statCard
    old_close = '''  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classModel.name),
      ),'''
    new_close = '''  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.soft(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classModel.name),
      ),'''
    if old_close in c and '_statCard' not in c:
        c = c.replace(old_close, new_close, 1)
        print("   ✅ دالة _statCard")

    if c != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print(f"   💾 حفظ")

# ============================================================
# [3/5] StudentsScreen — تصدير Excel
# ============================================================
print("\n📁 [3/5] students_screen.dart — تصدير قائمة الطلاب")

path = 'lib/features/students/presentation/screens/students_screen.dart'
if backup(path):
    print(f"   💾 نسخة احتياطية")

    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    original = c

    # 3.1: imports
    if "import 'package:excel/excel.dart';" not in c:
        c = c.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:excel/excel.dart';\nimport 'package:flutter/material.dart';",
            1
        )
    if "import '../../../../core/utils/excel_share.dart';" not in c:
        c = c.replace(
            "import '../../../../core/errors/error_message.dart';",
            "import '../../../../core/errors/error_message.dart';\n"
            "import '../../../../core/utils/excel_share.dart';",
            1
        )
    print("   ✅ imports (excel + share)")

    # 3.2: دالة التصدير
    old_export = '''  void _openProfile(StudentModel student) {'''
    new_export = '''  Future<void> _exportExcel() async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب لتصديرهم')),
      );
      return;
    }
    try {
      final excel = Excel.createExcel();
      const sheetName = 'قائمة الطلاب';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      final sheet = excel[sheetName];
      sheet.isRTL = true;

      sheet.appendRow([
        TextCellValue('قائمة الطلاب (${_students.length} طالب)'),
      ]);
      sheet.appendRow([
        TextCellValue('تاريخ التصدير: ${DateTime.now().toLocal()}'),
      ]);
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('#'),
        TextCellValue('الاسم'),
        TextCellValue('الرقم'),
        TextCellValue('ولي الأمر'),
      ]);

      for (var i = 0; i < _students.length; i++) {
        final s = _students[i];
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(s.fullName),
          TextCellValue(s.studentCode ?? ''),
          TextCellValue(s.parentPhone ?? ''),
        ]);
      }

      await shareExcel(
        excel,
        baseName: 'students_list',
        text: 'قائمة الطلاب',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تجهيز الملف'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التصدير: ${friendlyError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openProfile(StudentModel student) {'''
    if old_export in c and '_exportExcel' not in c:
        c = c.replace(old_export, new_export, 1)
        print("   ✅ دالة _exportExcel")

    # 3.3: زر التصدير بجانب البحث
    old_search_btn = '''                      IconButton(
                        tooltip: 'إضافة عدة طلاب / استيراد من Excel',
                        icon: const Icon(Icons.group_add),
                        onPressed: _addMany,
                      ),'''
    new_search_btn = '''                      IconButton(
                        tooltip: 'إضافة عدة طلاب / استيراد من Excel',
                        icon: const Icon(Icons.group_add),
                        onPressed: _addMany,
                      ),
                      IconButton(
                        tooltip: 'تصدير القائمة (Excel)',
                        icon: const Icon(Icons.file_upload_outlined),
                        onPressed: _students.isEmpty ? null : _exportExcel,
                      ),'''
    if old_search_btn in c:
        c = c.replace(old_search_btn, new_search_btn, 1)
        print("   ✅ زر التصدير في شريط البحث")

    if c != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print(f"   💾 حفظ")

# ============================================================
# [4/5] ClassResultsScreen — تصدير Excel
# ============================================================
print("\n📁 [4/5] class_results_screen.dart — تصدير Excel")

path = 'lib/features/grades/presentation/screens/class_results_screen.dart'
if backup(path):
    print(f"   💾 نسخة احتياطية")

    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    original = c

    # 4.1: imports
    if "import 'package:excel/excel.dart';" not in c:
        c = c.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:excel/excel.dart';\nimport 'package:flutter/material.dart';",
            1
        )
    if "import '../../../../core/utils/excel_share.dart';" not in c:
        c = c.replace(
            "import '../../../../core/errors/error_message.dart';",
            "import '../../../../core/errors/error_message.dart';\n"
            "import '../../../../core/utils/excel_share.dart';",
            1
        )
    print("   ✅ imports")

    # 4.2: دالة التصدير
    old_load_end = '''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('نتائج ${widget.classModel.name}')),'''
    new_load_end = '''  Future<void> _exportExcel() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد نتائج لتصديرها')),
      );
      return;
    }
    try {
      final excel = Excel.createExcel();
      const sheetName = 'نتائج الفصل';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      final sheet = excel[sheetName];
      sheet.isRTL = true;

      sheet.appendRow([
        TextCellValue('نتائج فصل: ${widget.classModel.name}'),
      ]);
      if (widget.classModel.subject != null) {
        sheet.appendRow([TextCellValue('المادة: ${widget.classModel.subject}')]);
      }
      sheet.appendRow([]);

      sheet.appendRow([
        TextCellValue('الترتيب'),
        TextCellValue('الطالب'),
        TextCellValue('المعدل (%)'),
        TextCellValue('التقدير'),
      ]);

      for (final r in _rows) {
        sheet.appendRow([
          r.rank != null ? IntCellValue(r.rank!) : TextCellValue('-'),
          TextCellValue(r.name),
          r.average != null
              ? DoubleCellValue(double.parse(r.average!.toStringAsFixed(2)))
              : TextCellValue('-'),
          TextCellValue(r.letter ?? '-'),
        ]);
      }

      await shareExcel(
        excel,
        baseName: 'results_${widget.classModel.name}',
        text: 'نتائج ${widget.classModel.name}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تجهيز الملف'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في التصدير: ${friendlyError(e)}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('نتائج ${widget.classModel.name}'),
        actions: [
          IconButton(
            tooltip: 'تصدير Excel',
            icon: const Icon(Icons.ios_share),
            onPressed: _isLoading || _rows.isEmpty ? null : _exportExcel,
          ),
        ],
      ),'''
    if old_load_end in c:
        c = c.replace(old_load_end, new_load_end, 1)
        print("   ✅ دالة _exportExcel + زر AppBar")

    if c != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print(f"   💾 حفظ")

# ============================================================
# [5/5] التحقق
# ============================================================
print("\n" + "=" * 72)
print("🔍 التحقق")
print("=" * 72)

files = [
    ('lib/features/students/presentation/screens/home_screen.dart',
     {'Dashboard': '_classesWithoutAttendance' in open('lib/features/students/presentation/screens/home_screen.dart').read()}),
    ('lib/features/students/presentation/screens/class_detail_screen.dart',
     {'إحصائيات': '_statCard' in open('lib/features/students/presentation/screens/class_detail_screen.dart').read(),
      'تنبيهات': '_atRiskStudents' in open('lib/features/students/presentation/screens/class_detail_screen.dart').read()}),
    ('lib/features/students/presentation/screens/students_screen.dart',
     {'تصدير الطلاب': '_exportExcel' in open('lib/features/students/presentation/screens/students_screen.dart').read()}),
    ('lib/features/grades/presentation/screens/class_results_screen.dart',
     {'تصدير النتائج': '_exportExcel' in open('lib/features/grades/presentation/screens/class_results_screen.dart').read()}),
]

all_ok = True
for path, checks_dict in files:
    name = os.path.basename(path)
    if not os.path.exists(path):
        print(f"   ❌ {name}")
        all_ok = False
        continue
    file_ok = True
    for label, ok in checks_dict.items():
        if not ok:
            print(f"   ⚠️  {name}: {label}")
            file_ok = False
            all_ok = False
    if file_ok:
        print(f"   ✅ {name}")

print("\n" + "=" * 72)
if all_ok:
    print("🎉 جميع الميزات مطبقة!")
else:
    print("⚠️  بعض الميزات فشلت")
print("=" * 72)
print("""
🚀 الخطوات:

  rm -f add_dashboard_and_export.py
  git add .
  git commit -m "Feat: Dashboard, class statistics, at-risk alerts, Excel exports"
  git push origin main
  
  sleep 5
  gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
""")
