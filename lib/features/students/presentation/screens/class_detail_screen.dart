import 'package:flutter/material.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/services/database_service.dart';
import '../../../attendance/presentation/screens/take_attendance_screen.dart';
import '../../../grades/presentation/screens/assessments_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassDetailScreen({super.key, required this.classModel});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final _db = DatabaseService();
  List<StudentModel> _enrolled = [];
  List<StudentModel> _allStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final enrolled = await _db.getStudentsInClass(widget.classModel.id);
      final all = await _db.getStudents();
      setState(() {
        _enrolled = enrolled;
        _allStudents = all;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
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

    final selected = await showDialog<StudentModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('إضافة طالب للفصل'),
        children: available.map((s) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Text(s.fullName),
          );
        }).toList(),
      ),
    );

    if (selected == null) return;

    try {
      await _db.enrollStudent(
        classId: widget.classModel.id,
        studentId: selected.id,
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة الطالب'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _unenroll(StudentModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة طالب'),
        content: Text('هل تريد إزالة "${student.fullName}" من الفصل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _db.unenrollStudent(
        classId: widget.classModel.id,
        studentId: student.id,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
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
                      TextButton.icon(
                        onPressed: _showEnrollDialog,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('إضافة'),
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
                              leading: CircleAvatar(
                                child: Text(s.fullName.isNotEmpty ? s.fullName[0] : '?'),
                              ),
                              title: Text(s.fullName),
                              subtitle: s.studentCode != null
                                  ? Text('الرقم: ${s.studentCode}')
                                  : null,
                              trailing: IconButton(
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
