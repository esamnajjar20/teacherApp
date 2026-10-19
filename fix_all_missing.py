import os

created = []

# ============ 1. lib/core/utils/attendance_calculator.dart ============
with open('lib/core/utils/attendance_calculator.dart', 'w', encoding='utf-8') as f:
    f.write('''/// حساب إحصائيات الحضور لكل طالب.
class AttendanceStats {
  final String studentId;
  final int present;
  final int absent;
  final int tardy;
  final int excused;

  const AttendanceStats({
    required this.studentId,
    this.present = 0,
    this.absent = 0,
    this.tardy = 0,
    this.excused = 0,
  });

  /// نسبة الحضور = (حاضر + متأخر) ÷ (كل الجلسات − بعذر) × 100
  double? get percentage {
    final total = present + absent + tardy + excused;
    if (total == 0) return null;
    final denominator = total - excused;
    if (denominator == 0) return null;
    return ((present + tardy) / denominator) * 100;
  }
}

class AttendanceCalculator {
  /// نسبة الحضور التي تحتها يُنبَّه إلى الطالب.
  static const double warningThreshold = 75.0;

  static List<AttendanceStats> summarize({
    required List<String> studentIds,
    required Iterable<({String studentId, String status})> records,
  }) {
    final map = <String, Map<String, int>>{
      for (final id in studentIds)
        id: {'present': 0, 'absent': 0, 'late': 0, 'excused': 0},
    };

    for (final r in records) {
      final entry = map[r.studentId];
      if (entry == null) continue;
      if (entry.containsKey(r.status)) {
        entry[r.status] = entry[r.status]! + 1;
      }
    }

    return map.entries.map((e) => AttendanceStats(
          studentId: e.key,
          present: e.value['present']!,
          absent: e.value['absent']!,
          tardy: e.value['late']!,
          excused: e.value['excused']!,
        )).toList();
  }

  static double? classAverage(List<AttendanceStats> stats) {
    final valid = stats.map((s) => s.percentage).whereType<double>().toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  static bool isBelowThreshold(double? percentage) {
    if (percentage == null) return false;
    return percentage < warningThreshold;
  }
}
''')
created.append('lib/core/utils/attendance_calculator.dart')

# ============ 2. lib/core/utils/excel_share.dart ============
with open('lib/core/utils/excel_share.dart', 'w', encoding='utf-8') as f:
    f.write('''import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// يحوّل مصنّف Excel إلى ملف ويشاركه عبر تطبيقات الهاتف.
Future<void> shareExcel(
  Excel excel, {
  required String baseName,
  required String text,
}) async {
  final dir = await getTemporaryDirectory();
  final safeName = baseName
      .replaceAll(RegExp(r'[^\\p{L}\\p{N}]+', unicode: true), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final fileName =
      '${safeName.isEmpty ? 'file' : safeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
  final path = '${dir.path}${Platform.pathSeparator}$fileName';
  final bytes = excel.encode();
  if (bytes == null) throw StateError('تعذّر إنشاء ملف Excel');
  await File(path).writeAsBytes(bytes);
  await Share.shareXFiles([XFile(path)], text: text);
}
''')
created.append('lib/core/utils/excel_share.dart')

# ============ 3. lib/core/widgets/student_picker_dialog.dart ============
with open('lib/core/widgets/student_picker_dialog.dart', 'w', encoding='utf-8') as f:
    f.write('''import 'package:flutter/material.dart';

import '../../shared/models/student_model.dart';

/// بحث داخل قائمة الطلاب (اسم / رقم / جوال).
bool studentMatchesQuery(StudentModel s, String query) {
  if (query.trim().isEmpty) return true;
  final q = query.trim().toLowerCase();
  return s.fullName.toLowerCase().contains(q) ||
      (s.studentCode?.toLowerCase().contains(q) ?? false) ||
      (s.parentPhone?.toLowerCase().contains(q) ?? false);
}

/// نافذة اختيار متعدد للطلاب. ترجع قائمة فارغة عند الإلغاء.
Future<List<StudentModel>?> showStudentPickerDialog(
  BuildContext context, {
  required List<StudentModel> students,
}) async {
  return showDialog<List<StudentModel>>(
    context: context,
    builder: (ctx) {
      final selected = <StudentModel>{};
      var query = '';

      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final visible =
              students.where((s) => studentMatchesQuery(s, query)).toList();
          return AlertDialog(
            title: const Text('اختر الطلاب'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث بالاسم أو الرقم',
                      isDense: true,
                    ),
                    onChanged: (v) => setLocal(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(child: Text('لا توجد نتائج'))
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (ctx, i) {
                              final s = visible[i];
                              return CheckboxListTile(
                                title: Text(s.fullName),
                                subtitle: s.studentCode != null
                                    ? Text('الرقم: ${s.studentCode}')
                                    : null,
                                value: selected.contains(s),
                                onChanged: (v) {
                                  setLocal(() {
                                    if (v == true) {
                                      selected.add(s);
                                    } else {
                                      selected.remove(s);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, <StudentModel>[]),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, selected.toList()),
                child: Text('إضافة ${selected.length}'),
              ),
            ],
          );
        },
      );
    },
  );
}
''')
created.append('lib/core/widgets/student_picker_dialog.dart')

# ============ 4. forgot_password_screen.dart ============
with open('lib/features/auth/presentation/screens/forgot_password_screen.dart', 'w', encoding='utf-8') as f:
    f.write('''import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_client.dart';
import '../../../../core/errors/error_message.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _emailController = TextEditingController(text: widget.initialEmail);
  bool _isLoading = false;
  String? _error;
  String? _info;

  Future<void> _reset() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل بريدك الإلكتروني');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });
    try {
      await supabase.auth
          .resetPasswordForEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _info = 'تم إرسال رمز إعادة التعيين إلى بريدك');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'أدخل بريدك الإلكتروني وسنرسل لك رمزاً لإعادة تعيين كلمة المرور.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            if (_info != null) ...[
              Text(_info!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _reset,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('إرسال رمز إعادة التعيين'),
            ),
          ],
        ),
      ),
    );
  }
}
''')
created.append('lib/features/auth/presentation/screens/forgot_password_screen.dart')

# ============ 5. grade_settings_screen.dart ============
with open('lib/features/grades/presentation/screens/grade_settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write('''import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';

class GradeSettingsScreen extends StatefulWidget {
  final ClassModel classModel;
  const GradeSettingsScreen({super.key, required this.classModel});

  @override
  State<GradeSettingsScreen> createState() => _GradeSettingsScreenState();
}

class _GradeSettingsScreenState extends State<GradeSettingsScreen> {
  final _db = DatabaseService();
  bool _isLoading = true;
  bool _isSaving = false;
  String _policy = 'exclude';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _db.getGradeSettings(widget.classModel.id);
      if (!mounted) return;
      setState(() {
        _policy = settings?.missingGradePolicy ?? 'exclude';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final existing = await _db.getGradeSettings(widget.classModel.id);
      final scale = existing?.gradingScale ??
          [
            {'min': 90, 'grade': 'ممتاز'},
            {'min': 80, 'grade': 'جيد جداً'},
            {'min': 70, 'grade': 'جيد'},
            {'min': 60, 'grade': 'مقبول'},
            {'min': 0, 'grade': 'ضعيف'},
          ];
      await _db.saveGradeSettings(
        classId: widget.classModel.id,
        gradingScale: scale.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        missingGradePolicy: _policy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم حفظ الإعدادات'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الدرجات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'سياسة الدرجة الناقصة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: const Text('استثناء التقييم (الافتراضي)'),
                  subtitle: const Text(
                      'التقييم الذي ليس له درجة لا يدخل في حساب المعدل'),
                  value: 'exclude',
                  groupValue: _policy,
                  onChanged: (v) => setState(() => _policy = v ?? 'exclude'),
                ),
                RadioListTile<String>(
                  title: const Text('احتساب صفر'),
                  subtitle: const Text(
                      'أي تقييم بدون درجة يُحسب صفراً على الطالب'),
                  value: 'zero',
                  groupValue: _policy,
                  onChanged: (v) => setState(() => _policy = v ?? 'exclude'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('حفظ'),
                ),
              ],
            ),
    );
  }
}
''')
created.append('lib/features/grades/presentation/screens/grade_settings_screen.dart')

# ============ 6. class_results_screen.dart ============
with open('lib/features/grades/presentation/screens/class_results_screen.dart', 'w', encoding='utf-8') as f:
    f.write('''import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/grade_calculator.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';

class ClassResultsScreen extends StatefulWidget {
  final ClassModel classModel;
  const ClassResultsScreen({super.key, required this.classModel});

  @override
  State<ClassResultsScreen> createState() => _ClassResultsScreenState();
}

class _ClassResultsScreenState extends State<ClassResultsScreen> {
  final _db = DatabaseService();
  bool _isLoading = true;
  String? _error;
  List<({String name, double? average, String? letter, int? rank})> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final students = await _db.getStudentsInClass(widget.classModel.id);
      final assessments = (await _db.getAssessments(widget.classModel.id))
          .where((a) => a.isActive)
          .toList();
      final grades = await _db
          .getGradesForAssessments(assessments.map((a) => a.id).toList());
      final settings = await _db.getGradeSettings(widget.classModel.id);
      final scale = (settings == null || settings.gradingScale.isEmpty)
          ? GradeCalculator.defaultScale
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : settings.gradingScale;

      final results = GradeCalculator.classResults(
        studentIds: students.map((s) => s.id).toList(),
        assessments: assessments,
        grades: grades,
        policy: settings?.missingGradePolicy ?? 'exclude',
        scale: scale,
      );

      final names = {for (final s in students) s.id: s.fullName};
      final list = results
          .map((r) => (
                name: names[r.studentId] ?? '',
                average: r.average,
                letter: r.letter,
                rank: r.rank,
              ))
          .toList()
        ..sort((a, b) {
          if (a.rank == null && b.rank == null) return a.name.compareTo(b.name);
          if (a.rank == null) return 1;
          if (b.rank == null) return -1;
          return a.rank!.compareTo(b.rank!);
        });

      if (!mounted) return;
      setState(() {
        _rows = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('نتائج ${widget.classModel.name}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _rows.isEmpty
                  ? const Center(child: Text('لا يوجد طلاب في هذا الفصل'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(r.rank?.toString() ?? '-'),
                            ),
                            title: Text(r.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(r.letter ?? 'بلا تقدير'),
                            trailing: Text(
                              r.average == null
                                  ? '-'
                                  : '${r.average!.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
''')
created.append('lib/features/grades/presentation/screens/class_results_screen.dart')

# ============ 7. إصلاح grade_calculator.dart ============
grade_path = 'lib/core/utils/grade_calculator.dart'
with open(grade_path, 'r', encoding='utf-8') as f:
    content = f.read()

# إضافة StudentResult
if 'class StudentResult' not in content:
    content += '''

class StudentResult {
  final String studentId;
  final double? average;
  final String? letter;
  final int? rank;

  StudentResult({
    required this.studentId,
    this.average,
    this.letter,
    this.rank,
  });
}
'''

# إضافة defaultScale و classResults
if 'defaultScale' not in content:
    content = content.replace('class GradeCalculator {', '''class GradeCalculator {
  static const List<Map<String, dynamic>> defaultScale = [
    {'min': 90, 'grade': 'ممتاز'},
    {'min': 80, 'grade': 'جيد جداً'},
    {'min': 70, 'grade': 'جيد'},
    {'min': 60, 'grade': 'مقبول'},
    {'min': 0, 'grade': 'ضعيف'},
  ];

  static List<StudentResult> classResults({
    required List<String> studentIds,
    required List<AssessmentModel> assessments,
    required List<GradeModel> grades,
    required String policy,
    required List<Map<String, dynamic>> scale,
  }) {
    final list = <StudentResult>[];
    for (final id in studentIds) {
      final items = <({AssessmentModel assessment, GradeModel? grade})>[];
      for (final a in assessments) {
        if (!a.isActive) continue;
        final g = grades
            .where((g) => g.assessmentId == a.id && g.studentId == id)
            .firstOrNull;
        items.add((assessment: a, grade: g));
      }

      double totalWeighted = 0;
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
      list.add(StudentResult(studentId: id, average: avg, letter: letter));
    }

    final sorted = list.where((r) => r.average != null).toList()
      ..sort((a, b) => b.average!.compareTo(a.average!));
    for (var i = 0; i < sorted.length; i++) {
      final originalIndex =
          list.indexWhere((r) => r.studentId == sorted[i].studentId);
      list[originalIndex] = StudentResult(
        studentId: list[originalIndex].studentId,
        average: list[originalIndex].average,
        letter: list[originalIndex].letter,
        rank: i + 1,
      );
    }
    return list;
  }
''')

with open(grade_path, 'w', encoding='utf-8') as f:
    f.write(content)
created.append(grade_path + ' (معدّل)')

print(f"\n✅ تم إنشاء/تعديل {len(created)} ملف:")
for c in created:
    print(f"   • {c}")
