import 'package:flutter/material.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../shared/models/grade_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/services/database_service.dart';

class EnterGradesScreen extends StatefulWidget {
  final AssessmentModel assessment;
  final List<StudentModel> students;

  const EnterGradesScreen({
    super.key,
    required this.assessment,
    required this.students,
  });

  @override
  State<EnterGradesScreen> createState() => _EnterGradesScreenState();
}

class _EnterGradesScreenState extends State<EnterGradesScreen> {
  final _db = DatabaseService();
  late Map<String, TextEditingController> _controllers;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final s in widget.students) s.id: TextEditingController(),
    };
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final grades = await _db.getGradesForAssessment(widget.assessment.id);
      for (final g in grades) {
        if (_controllers.containsKey(g.studentId) && g.rawScore != null) {
          _controllers[g.studentId]!.text = formatNumber(g.rawScore!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final grades = <({String studentId, double? rawScore})>[];

      for (final student in widget.students) {
        final text = _controllers[student.id]!.text.trim();
        double? score;
        if (text.isNotEmpty) {
          score = parseNumber(text);
          if (score == null) {
            _showError('درجة غير صالحة للطالب: ${student.fullName}');
            return;
          }
          if (score < 0 || score > widget.assessment.maxScore) {
            _showError(
              'درجة ${student.fullName} يجب أن تكون بين 0 و ${formatNumber(widget.assessment.maxScore)}',
            );
            return;
          }
        }
        grades.add((studentId: student.id, rawScore: score));
      }

      await _db.saveGrades(
        assessmentId: widget.assessment.id,
        grades: grades,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الدرجات'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment.name),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).primaryColor.withOpacity(0.08),
                  child: Text(
                    'الدرجة العظمى: ${formatNumber(widget.assessment.maxScore)}  •  الوزن: ${formatNumber(widget.assessment.weight)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: widget.students.isEmpty
                      ? const Center(child: Text('لا يوجد طلاب'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: widget.students.length,
                          itemBuilder: (context, index) {
                            final student = widget.students[index];
                            final ctrl = _controllers[student.id]!;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      child: Text(
                                        student.fullName.isNotEmpty
                                            ? student.fullName[0]
                                            : '?',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        student.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: TextField(
                                        controller: ctrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          hintText: '0-${formatNumber(widget.assessment.maxScore)}',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
