import 'package:flutter/material.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../shared/models/grade_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/services/database_service.dart';
import 'package:teacher_app/core/utils/color_utils.dart';

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
  bool _dirty = false;

  /// نص البحث
  final _searchCtrl = TextEditingController();
  String _search = '';

  /// نص البحث
  final _searchCtrl = TextEditingController();
  String _search = '';

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
    _searchCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// ملء درجة الجميع بالدرجة العظمى
  void _fillAllMax() {
    final max = widget.assessment.maxScore;
    final display = formatNumber(max);
    for (final ctrl in _controllers.values) {
      ctrl.text = display;
    }
    setState(() => _dirty = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم ملء جميع الدرجات بـ $display')),
    );
  }

  /// مسح جميع الحقول
  void _clearAll() {
    for (final ctrl in _controllers.values) {
      ctrl.clear();
    }
    setState(() => _dirty = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم مسح جميع الدرجات')),
    );
  }

  /// تعيين "بدون درجة" للجميع (فراغ)
  void _setAllNoGrade() {
    _clearAll();
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
        _dirty = false;
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

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديلات غير محفوظة'),
        content: const Text('لم تحفظ الدرجات بعد. هل تريد الخروج وتجاهل التعديلات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('البقاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج دون حفظ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'fill_max') _fillAllMax();
              if (value == 'clear') _clearAll();
              if (value == 'no_grade') _setAllNoGrade();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'fill_max',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('ملء الدرجة العظمى للكل'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('مسح جميع الدرجات'),
                  ],
                ),
              ),
            ],
          ),
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
                  color: Theme.of(context).primaryColor.soft(0.08),
                  child: Text(
                    'الدرجة العظمى: ${formatNumber(widget.assessment.maxScore)}  •  الوزن: ${formatNumber(widget.assessment.weight)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.students.length > 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'ابحث باسم الطالب...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    ),
                  ),
                Expanded(
                  child: widget.students.isEmpty
                      ? const Center(child: Text('لا يوجد طلاب'))
                      : Builder(
                          builder: (context) {
                            final filtered = _search.isEmpty
                                ? widget.students
                                : widget.students
                                    .where((s) => s.fullName
                                        .toLowerCase()
                                        .contains(_search.toLowerCase()))
                                    .toList();
                            if (filtered.isEmpty) {
                              return const Center(
                                  child: Text('لا توجد نتائج مطابقة'));
                            }
                            return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final student = filtered[index];
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
                                      child: ValueListenableBuilder<TextEditingValue>(
                                        valueListenable: ctrl,
                                        builder: (_, val, __) {
                                          final score = parseNumber(val.text);
                                          final pct = (score != null &&
                                                  score >= 0 &&
                                                  widget.assessment.maxScore > 0)
                                              ? (score /
                                                      widget.assessment.maxScore *
                                                      100)
                                                  .toStringAsFixed(0)
                                              : null;
                                          return TextField(
                                            controller: ctrl,
                                            textInputAction: index ==
                                                    filtered.length - 1
                                                ? TextInputAction.done
                                                : TextInputAction.next,
                                            onChanged: (_) {
                                              if (!_dirty) {
                                                setState(() => _dirty = true);
                                              }
                                            },
                                            keyboardType: const TextInputType
                                                .numberWithOptions(decimal: true),
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              hintText:
                                                  '0-${formatNumber(widget.assessment.maxScore)}',
                                              suffixText: pct != null ? '$pct%' : null,
                                              suffixStyle: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 10,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
