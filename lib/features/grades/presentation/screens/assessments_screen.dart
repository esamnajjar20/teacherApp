import 'package:flutter/material.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/models/grade_model.dart';
import '../../../../shared/services/database_service.dart';
import 'enter_grades_screen.dart';

class AssessmentsScreen extends StatefulWidget {
  final ClassModel classModel;
  final List<StudentModel> students;

  const AssessmentsScreen({
    super.key,
    required this.classModel,
    required this.students,
  });

  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen> {
  final _db = DatabaseService();
  List<AssessmentModel> _assessments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getAssessments(widget.classModel.id);
      setState(() {
        _assessments = list;
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

  double get _totalWeight =>
      _assessments.where((a) => a.isActive).fold(0.0, (sum, a) => sum + a.weight);

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '20');
    final maxCtrl = TextEditingController(text: '100');
    String type = 'exam';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة تقييم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم التقييم'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: const [
                    DropdownMenuItem(value: 'exam', child: Text('امتحان')),
                    DropdownMenuItem(value: 'homework', child: Text('واجب')),
                    DropdownMenuItem(value: 'participation', child: Text('مشاركة')),
                    DropdownMenuItem(value: 'project', child: Text('مشروع')),
                    DropdownMenuItem(value: 'quiz', child: Text('اختبار قصير')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'exam'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الوزن (%)',
                    hintText: 'مثال: 30',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الدرجة العظمى',
                    hintText: 'مثال: 20 أو 100',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final weight = double.tryParse(weightCtrl.text) ?? 0;
    final maxScore = double.tryParse(maxCtrl.text) ?? 100;

    if (weight < 0 || weight > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الوزن يجب أن يكون بين 0 و 100'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_totalWeight + weight > 100.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('مجموع الأوزان سيتجاوز 100% (الحالي: ${_totalWeight.toStringAsFixed(1)}%)'),
          backgroundColor: Colors.orange,
        ),
      );
      // نسمح بالحفظ مع تحذير
    }

    try {
      await _db.createAssessment(
        classId: widget.classModel.id,
        name: nameCtrl.text.trim(),
        type: type,
        weight: weight,
        maxScore: maxScore,
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة التقييم'), backgroundColor: Colors.green),
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

  Future<void> _delete(AssessmentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقييم'),
        content: Text('هل تريد حذف "${a.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _db.softDeleteAssessment(a.id);
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
        title: Text('تقييمات ${widget.classModel.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ملخص الأوزان
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: _totalWeight == 100
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _totalWeight == 100 ? Icons.check_circle : Icons.warning,
                        color: _totalWeight == 100 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'مجموع الأوزان: ${_totalWeight.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _totalWeight == 100 ? Colors.green : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _assessments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              const Text('لا توجد تقييمات بعد'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showAddDialog,
                                child: const Text('إضافة تقييم'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _assessments.length,
                          itemBuilder: (context, index) {
                            final a = _assessments[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                  child: Text(
                                    '${a.weight.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('من ${a.maxScore} • ${a.type ?? ""}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_note),
                                      tooltip: 'إدخال الدرجات',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EnterGradesScreen(
                                              assessment: a,
                                              students: widget.students,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _delete(a),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EnterGradesScreen(
                                        assessment: a,
                                        students: widget.students,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('تقييم جديد'),
      ),
    );
  }
}
