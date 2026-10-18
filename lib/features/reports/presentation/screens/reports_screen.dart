import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/models/grade_model.dart';
import '../../../../shared/services/database_service.dart';
import '../../../../core/utils/grade_calculator.dart';

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
      setState(() {
        _classes = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
      final assessments = await _db.getAssessments(_selectedClass!.id);
      final settings = await _db.getGradeSettings(_selectedClass!.id);
      final policy = settings?.missingGradePolicy ?? 'exclude';

      // جلب كل الدرجات
      final Map<String, List<GradeModel>> gradesByAssessment = {};
      for (final a in assessments) {
        gradesByAssessment[a.id] = await _db.getGradesForAssessment(a.id);
      }

      final excel = Excel.createExcel();
      final sheet = excel['كشف الدرجات'];
      excel.delete('Sheet1');

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
        header.add(TextCellValue('${a.name} (${a.weight}%)'));
      }
      header.add(TextCellValue('المعدل'));
      sheet.appendRow(header);

      // صفوف الطلاب
      for (final student in students) {
        final row = <CellValue?>[TextCellValue(student.fullName)];
        final items = <({AssessmentModel assessment, GradeModel? grade})>[];

        for (final a in assessments) {
          final grades = gradesByAssessment[a.id] ?? [];
          final g = grades.where((x) => x.studentId == student.id).firstOrNull;
          items.add((assessment: a, grade: g));

          if (g?.rawScore != null) {
            row.add(DoubleCellValue(g!.rawScore!));
          } else {
            row.add(TextCellValue('-'));
          }
        }

        final avg = GradeCalculator.calculateFinalAverage(
          items: items,
          policy: policy,
        );
        row.add(avg != null
            ? DoubleCellValue(double.parse(avg.toStringAsFixed(2)))
            : TextCellValue('-'));

        sheet.appendRow(row);
      }

      final dir = await getTemporaryDirectory();
      final fileName =
          'grades_${_selectedClass!.name}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final path = '${dir.path}/$fileName';
      final bytes = excel.encode();
      if (bytes != null) {
        final file = File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: 'كشف درجات ${_selectedClass!.name}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير الملف'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التصدير: $e'), backgroundColor: Colors.red),
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
                      subtitle: const Text('قريباً'),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تقرير الحضور قيد التطوير')),
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
