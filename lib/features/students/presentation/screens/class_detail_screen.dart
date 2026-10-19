import 'package:flutter/material.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/attendance_calculator.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/student_picker_dialog.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/services/database_service.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../attendance/presentation/screens/attendance_history_screen.dart';
import '../../../attendance/presentation/screens/take_attendance_screen.dart';
import '../../../grades/presentation/screens/assessments_screen.dart';
import '../../../grades/presentation/screens/class_results_screen.dart';
import 'bulk_students_screen.dart';
import 'student_detail_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassDetailScreen({super.key, required this.classModel});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen>
    with SyncRefreshMixin {
  final _db = DatabaseService();
  List<StudentModel> _enrolled = [];
  List<StudentModel> _allStudents = [];
  bool _isLoading = true;

  // إحصائيات
  int _sessionsCount = 0;
  double? _avgAttendance;
  int _atRiskCount = 0;
  List<({String name, double? percentage})> _atRiskStudents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> reloadSilently() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final enrolled = await _db.getStudentsInClass(widget.classModel.id);
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
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEnrollDialog() async {
    final enrolledIds = _enrolled.map((s) => s.id).toSet();
    final available = _allStudents.where((s) => !enrolledIds.contains(s.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب متاحون للإضافة')),
      );
      return;
    }

    final selected = await showStudentPickerDialog(
      context,
      students: available,
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    try {
      for (final student in selected) {
        await _db.enrollStudent(
          classId: widget.classModel.id,
          studentId: student.id,
        );
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(selected.length == 1
                ? 'تم إضافة الطالب'
                : 'تم إضافة ${selected.length} طلاب'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addNewMany() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BulkStudentsScreen(classModel: widget.classModel),
      ),
    );
    if (added == true) _load(silent: true);
  }

  Future<void> _unenroll(StudentModel student) async {
    final confirm = await confirmDelete(
      context,
      title: 'إزالة طالب',
      message:
          'هل تريد إزالة "${student.fullName}" من الفصل؟\nتبقى بياناته وسجلاته ويمكن إعادة إضافته.',
      confirmLabel: 'إزالة',
    );
    if (!confirm || !mounted) return;

    try {
      await _db.unenrollStudent(
        classId: widget.classModel.id,
        studentId: student.id,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classModel.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // أزرار سريعة
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TakeAttendanceScreen(
                                  classModel: widget.classModel,
                                  students: _enrolled,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('تسجيل حضور'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssessmentsScreen(
                                  classModel: widget.classModel,
                                  students: _enrolled,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.grade_outlined),
                          label: const Text('الدرجات'),
                        ),
                      ),
                    ],
                  ),
                ),
                // ===== إحصائيات الفصل =====
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
                // ===== إحصائيات الفصل =====
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttendanceHistoryScreen(
                              classModel: widget.classModel),
                        ),
                      ),
                      icon: const Icon(Icons.event_note_outlined),
                      label: const Text('سجل الحضور السابق'),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الطلاب (${_enrolled.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _addNewMany,
                            icon: const Icon(Icons.group_add, size: 18),
                            label: const Text('طلاب جدد'),
                          ),
                          TextButton.icon(
                            onPressed: _showEnrollDialog,
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('إضافة'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _enrolled.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              const Text('لا يوجد طلاب في هذا الفصل'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showEnrollDialog,
                                child: const Text('إضافة طالب'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _enrolled.length,
                          itemBuilder: (context, index) {
                            final s = _enrolled[index];
                            return ListTile(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentDetailScreen(student: s),
                                ),
                              ).then((_) => _load(silent: true)),
                              leading: CircleAvatar(
                                child: Text(s.fullName.isNotEmpty ? s.fullName[0] : '?'),
                              ),
                              title: Text(s.fullName),
                              subtitle: s.studentCode != null
                                  ? Text('الرقم: ${s.studentCode}')
                                  : null,
                              trailing: IconButton(
                                tooltip: 'إزالة من الفصل',
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _unenroll(s),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
