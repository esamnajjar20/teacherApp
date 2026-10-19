import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/attendance_calculator.dart';
import '../../../../core/utils/grade_calculator.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/student_form_dialog.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/services/database_service.dart';
import 'package:teacher_app/core/utils/color_utils.dart';

class _ClassSummary {
  final String className;
  final String? subject;
  final AttendanceStats attendance;
  final StudentResult result;
  final int classSize;

  const _ClassSummary({
    required this.className,
    required this.subject,
    required this.attendance,
    required this.result,
    required this.classSize,
  });
}

/// ملف طالب: بياناته + حضوره ومعدله وترتيبه في كل فصل مسجَّل فيه.
class StudentDetailScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _db = DatabaseService();
  late StudentModel _student = widget.student;
  bool _isLoading = true;
  String? _error;
  List<_ClassSummary> _summaries = [];

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
      final sid = _student.id;
      final classes = await _db.getClassesOfStudent(sid);
      final out = <_ClassSummary>[];

      for (final cls in classes) {
        final records = await _db.getAttendanceRecordsForStudent(
          studentId: sid,
          classId: cls.id,
        );
        final attendance = AttendanceCalculator.summarize(
          studentIds: [sid],
          records: records.map((r) => (studentId: r.studentId, status: r.status)),
        ).single;

        final classStudents = await _db.getStudentsInClass(cls.id);
        final assessments = (await _db.getAssessments(cls.id))
            .where((a) => a.isActive)
            .toList();
        final grades = await _db
            .getGradesForAssessments(assessments.map((a) => a.id).toList());
        final settings = await _db.getGradeSettings(cls.id);
        final scale = (settings == null || settings.gradingScale.isEmpty)
            ? GradeCalculator.defaultScale
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : settings.gradingScale;

        final results = GradeCalculator.classResults(
          studentIds: classStudents.map((s) => s.id).toList(),
          assessments: assessments,
          grades: grades,
          policy: settings?.missingGradePolicy ?? 'exclude',
          scale: scale,
        );
        final mine = results.firstWhere(
          (r) => r.studentId == sid,
          orElse: () => StudentResult(studentId: sid),
        );

        out.add(_ClassSummary(
          className: cls.name,
          subject: cls.subject,
          attendance: attendance,
          result: mine,
          classSize: classStudents.length,
        ));
      }

      if (!mounted) return;
      setState(() {
        _summaries = out;
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

  Future<void> _edit() async {
    final data = await showStudentFormDialog(context, existing: _student);
    if (data == null) return;
    try {
      await _db.updateStudent(
        id: _student.id,
        fullName: data.fullName,
        studentCode: data.code,
        parentPhone: data.phone,
      );
      if (!mounted) return;
      setState(() {
        _student = StudentModel(
          id: _student.id,
          teacherId: _student.teacherId,
          fullName: data.fullName,
          studentCode: data.code,
          parentPhone: data.phone,
          notes: _student.notes,
          deletedAt: _student.deletedAt,
          createdAt: _student.createdAt,
          updatedAt: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم حفظ التعديلات'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _student;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.fullName),
        actions: [
          IconButton(
            tooltip: 'تعديل بيانات الطالب',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _info(Icons.badge_outlined, 'الرقم', s.studentCode),
                  _info(Icons.phone_outlined, 'جوال ولي الأمر', s.parentPhone),
                  if (s.notes != null && s.notes!.isNotEmpty)
                    _info(Icons.notes, 'ملاحظات', s.notes),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('الفصول',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Column(children: [
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ])
          else if (_summaries.isEmpty)
            const SizedBox(
              height: 220,
              child: EmptyState(
                icon: Icons.class_outlined,
                title: 'الطالب غير مسجَّل في أي فصل',
              ),
            )
          else
            for (final c in _summaries) _classCard(c),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.black54)),
          Expanded(child: Text(value == null || value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _classCard(_ClassSummary c) {
    final p = c.attendance.percentage;
    final low = AttendanceCalculator.isBelowThreshold(p);
    final r = c.result;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.subject == null ? c.className : '${c.className} • ${c.subject}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    'الحضور',
                    p == null ? '-' : '${p.toStringAsFixed(0)}%',
                    p == null ? Colors.grey : (low ? Colors.red : Colors.green),
                    'حاضر ${c.attendance.present} • غائب ${c.attendance.absent} • متأخر ${c.attendance.tardy} • بعذر ${c.attendance.excused}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stat(
                    'المعدل',
                    r.average == null ? '-' : '${r.average!.toStringAsFixed(1)}%',
                    r.average == null ? Colors.grey : Colors.blue,
                    r.average == null
                        ? 'لا درجات'
                        : '${r.letter ?? ''} • الترتيب ${r.rank} من ${c.classSize}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color, String detail) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.soft(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(detail,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
