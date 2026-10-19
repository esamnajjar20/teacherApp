import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/excel_share.dart';
import '../../../../core/utils/grade_calculator.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/grade_model.dart';
import '../../../../shared/services/database_service.dart';
import '../../../attendance/presentation/screens/attendance_report_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseService();
  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final list = await _db.getClasses();
      if (!mounted) return;
      setState(() {
        _classes = list;
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

  Future<void> _exportGradesExcel() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر فصلاً أولاً')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final students = await _db.getStudentsInClass(_selectedClass!.id);
      // نفس ما تعرضه شاشة نتائج الفصل: التقييمات المحتسبة فقط، مع الترتيب
      final assessments = (await _db.getAssessments(_selectedClass!.id))
          .where((a) => a.isActive)
          .toList();
      final settings = await _db.getGradeSettings(_selectedClass!.id);
      final policy = settings?.missingGradePolicy ?? 'exclude';
      final scale = (settings == null || settings.gradingScale.isEmpty)
          ? GradeCalculator.defaultScale
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : settings.gradingScale;

      // جلب كل الدرجات بطلب واحد وتجميعها حسب (تقييم، طالب)
      final allGrades =
          await _db.getGradesForAssessments(assessments.map((a) => a.id).toList());
      final gradeLookup = <String, GradeModel>{
        for (final g in allGrades) '${g.assessmentId}|${g.studentId}': g,
      };

      final results = GradeCalculator.classResults(
        studentIds: students.map((s) => s.id).toList(),
        assessments: assessments,
        grades: allGrades,
        policy: policy,
        scale: scale,
      );
      final resultById = {for (final r in results) r.studentId: r};

      final excel = Excel.createExcel();
      const sheetName = 'كشف الدرجات';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      final sheet = excel[sheetName];
      sheet.isRTL = true;

      // العنوان
      sheet.appendRow([
        TextCellValue('كشف درجات: ${_selectedClass!.name}'),
      ]);
      sheet.appendRow([
        TextCellValue('المادة: ${_selectedClass!.subject ?? "-"}'),
        TextCellValue('السنة: ${_selectedClass!.academicYear ?? "-"}'),
      ]);
      sheet.appendRow([]);

      // رأس الجدول
      final header = <CellValue?>[TextCellValue('الطالب')];
      for (final a in assessments) {
        header.add(TextCellValue('${a.name} (${formatNumber(a.weight)}%)'));
      }
      header.add(TextCellValue('المعدل (%)'));
      header.add(TextCellValue('التقدير'));
      header.add(TextCellValue('الترتيب'));
      sheet.appendRow(header);

      // صفوف الطلاب بترتيب القائمة، والترتيب في عمود مستقل
      for (final student in students) {
        final row = <CellValue?>[TextCellValue(student.fullName)];

        for (final a in assessments) {
          final g = gradeLookup['${a.id}|${student.id}'];
          if (g?.rawScore != null) {
            row.add(DoubleCellValue(g!.rawScore!));
          } else {
            row.add(TextCellValue('-'));
          }
        }

        final r = resultById[student.id];
        final avg = r?.average;
        row.add(avg != null
            ? DoubleCellValue(double.parse(avg.toStringAsFixed(2)))
            : TextCellValue('-'));
        row.add(TextCellValue(r?.letter ?? '-'));
        row.add(r?.rank != null ? IntCellValue(r!.rank!) : TextCellValue('-'));

        sheet.appendRow(row);
      }

      await shareExcel(
        excel,
        baseName: 'grades_${_selectedClass!.name}',
        text: 'كشف درجات ${_selectedClass!.name}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تجهيز الملف'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التصدير: ${friendlyError(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'اختر الفصل',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ClassModel>(
                    value: _selectedClass,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'اختر فصلاً',
                    ),
                    items: _classes.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedClass = v),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.table_chart, color: Colors.green),
                      title: const Text('تصدير كشف الدرجات (Excel)'),
                      subtitle: const Text('ملف Excel يحتوي على درجات كل الطلاب'),
                      trailing: _isExporting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share),
                      onTap: _isExporting ? null : _exportGradesExcel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_month, color: Colors.blue),
                      title: const Text('تقرير الحضور'),
                      subtitle: const Text('نسب الحضور والغياب لكل طالب مع تصدير Excel'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        final cls = _selectedClass;
                        if (cls == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('اختر فصلاً أولاً')),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttendanceReportScreen(classModel: cls),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
