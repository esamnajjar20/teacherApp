import 'package:flutter/material.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/models/grade_model.dart';
import '../../../../shared/services/database_service.dart';
import 'enter_grades_screen.dart';
import 'grade_settings_screen.dart';
import 'package:teacher_app/core/utils/color_utils.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';

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

class _AssessmentsScreenState extends State<AssessmentsScreen>
    with SyncRefreshMixin {
  final _db = DatabaseService();
  List<AssessmentModel> _assessments = [];
  bool _isLoading = true;

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
      final list = await _db.getAssessments(widget.classModel.id);
      if (!mounted) return;
      setState(() {
        _assessments = list;
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

  double get _totalWeight =>
      _assessments.where((a) => a.isActive).fold(0.0, (sum, a) => sum + a.weight);

  bool get _isWeightComplete => (_totalWeight - 100).abs() < 0.01;

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  /// نافذة واحدة للإضافة والتعديل. [existing] == null يعني إضافة.
  Future<void> _showFormDialog({AssessmentModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name);
    final weightCtrl = TextEditingController(
        text: existing == null ? '20' : formatNumber(existing.weight));
    final maxCtrl = TextEditingController(
        text: existing == null ? '100' : formatNumber(existing.maxScore));
    String type = existing?.type != null && _typeLabels.containsKey(existing!.type)
        ? existing.type!
        : 'exam';
    DateTime? date = existing?.date;
    bool active = existing?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة تقييم' : 'تعديل التقييم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'اسم التقييم'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: [
                    for (final e in _typeLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'exam'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'الوزن (%)',
                    hintText: 'مثال: 30',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'الدرجة العظمى',
                    hintText: 'مثال: 20 أو 100',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(date == null ? 'تاريخ التقييم (اختياري)' : _fmtDate(date!)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            locale: const Locale('ar'),
                          );
                          if (picked != null) setDialogState(() => date = picked);
                        },
                      ),
                    ),
                    if (date != null)
                      IconButton(
                        tooltip: 'إزالة التاريخ',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setDialogState(() => date = null),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('محتسب في المعدل'),
                  subtitle: const Text('أوقفه لاستبعاد التقييم من المعدل دون حذفه'),
                  value: active,
                  onChanged: (v) => setDialogState(() => active = v),
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

    final name = nameCtrl.text.trim();
    final weight = parseNumber(weightCtrl.text);
    final maxScore = parseNumber(maxCtrl.text);

    // نحرر الـ controllers فوراً بعد قراءة القيم
    nameCtrl.dispose();
    weightCtrl.dispose();
    maxCtrl.dispose();

    if (result != true || !mounted) return;

    void showError(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }

    if (weight == null || weight < 0 || weight > 100) {
      showError('الوزن يجب أن يكون رقماً بين 0 و 100');
      return;
    }
    if (maxScore == null || maxScore <= 0 || maxScore > 9999.99) {
      showError('الدرجة العظمى يجب أن تكون رقماً أكبر من 0');
      return;
    }

    // مجموع الأوزان بعد الحفظ (نستبعد وزن التقييم نفسه عند التعديل)
    final others = _assessments
        .where((a) => a.isActive && a.id != existing?.id)
        .fold(0.0, (sum, a) => sum + a.weight);
    if (active && others + weight > 100.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تنبيه: مجموع الأوزان سيتجاوز 100% (سيصبح ${formatNumber(double.parse((others + weight).toStringAsFixed(2)))}%)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      // نسمح بالحفظ مع تحذير
    }

    try {
      if (existing == null) {
        final created = await _db.createAssessment(
          classId: widget.classModel.id,
          name: name,
          type: type,
          weight: weight,
          maxScore: maxScore,
          date: date,
        );
        if (!active) {
          await _db.updateAssessment(
            id: created.id,
            name: name,
            type: type,
            weight: weight,
            maxScore: maxScore,
            date: date,
            isActive: false,
          );
        }
      } else {
        await _db.updateAssessment(
          id: existing.id,
          name: name,
          type: type,
          weight: weight,
          maxScore: maxScore,
          date: date,
          isActive: active,
        );
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? 'تم إضافة التقييم' : 'تم حفظ التعديلات'),
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

  Future<void> _delete(AssessmentModel a) async {
    final grades = await _db.getGradesForAssessment(a.id);
    final withScores = grades.where((g) => g.rawScore != null).length;
    if (!mounted) return;
    final ok = await confirmDelete(
      context,
      title: 'حذف التقييم',
      message: withScores > 0
          ? 'سيُحذف "${a.name}" مع $withScores درجة مُدخلة، ويتغير معدل الطلاب.\n\nيمكنك استعادته من سلة المحذوفات.'
          : 'سيُحذف "${a.name}".\n\nيمكنك استعادته من سلة المحذوفات.',
    );
    if (!ok || !mounted) return;

    try {
      await _db.softDeleteAssessment(a.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  static const Map<String, String> _typeLabels = {
    'exam': 'امتحان',
    'homework': 'واجب',
    'participation': 'مشاركة',
    'project': 'مشروع',
    'quiz': 'اختبار قصير',
  };

  String _typeLabel(String? type) =>
      type == null ? '' : (_typeLabels[type] ?? type);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تقييمات ${widget.classModel.name}'),
        actions: [
          IconButton(
            tooltip: 'إعدادات الدرجات',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    GradeSettingsScreen(classModel: widget.classModel),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ملخص الأوزان
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: _isWeightComplete
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isWeightComplete ? Icons.check_circle : Icons.warning,
                        color: _isWeightComplete ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'مجموع الأوزان: ${formatNumber(double.parse(_totalWeight.toStringAsFixed(2)))}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isWeightComplete ? Colors.green : Colors.orange.shade800,
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
                                onPressed: _showFormDialog,
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
                                  backgroundColor: Theme.of(context).primaryColor.soft(0.1),
                                  child: Text(
                                    '${formatNumber(a.weight)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('من ${formatNumber(a.maxScore)} • ${_typeLabel(a.type)}${a.date == null ? '' : ' • ${_fmtDate(a.date!)}'}${a.isActive ? '' : ' • غير محتسب'}'),
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
                                      tooltip: 'تعديل التقييم',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _showFormDialog(existing: a),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
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
        onPressed: _showFormDialog,
        icon: const Icon(Icons.add),
        label: const Text('تقييم جديد'),
      ),
    );
  }
}
