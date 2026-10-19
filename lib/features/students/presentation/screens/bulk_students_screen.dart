import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/student_file_import.dart';
import '../../../../core/utils/student_import.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';

/// إضافة عدة طلاب دفعة واحدة: لصق قائمة (من Excel مثلاً) أو استيراد ملف.
/// إن مُرّر [classModel] يُسجَّل الطلاب في ذلك الفصل أيضاً.
/// ترجع true عند إضافة شيء.
class BulkStudentsScreen extends StatefulWidget {
  final ClassModel? classModel;

  const BulkStudentsScreen({super.key, this.classModel});

  @override
  State<BulkStudentsScreen> createState() => _BulkStudentsScreenState();
}

class _BulkStudentsScreenState extends State<BulkStudentsScreen> {
  final _db = DatabaseService();
  final _text = TextEditingController();
  bool _saving = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<ImportedStudent> get _parsed => parseStudentsText(_text.text);

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final students = await pickStudentsFile();
      if (students == null) return; // ألغى المعلم
      if (students.isEmpty) {
        _snack('لم أجد أسماء طلاب في الملف', error: true);
        return;
      }
      // نضع الصفوف في مربع النص ليراجعها المعلم ويعدّلها قبل الإضافة
      final lines = students
          .map((s) => [
                s.fullName,
                s.studentCode ?? '',
                s.parentPhone ?? '',
              ].join('\t'))
          .join('\n');
      final current = _text.text.trimRight();
      _text.text = current.isEmpty ? lines : '$current\n$lines';
    } on FormatException catch (e) {
      _snack(e.message, error: true);
    } catch (e) {
      _snack(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    final rows = _parsed;
    if (rows.isEmpty) return;
    setState(() => _saving = true);
    try {
      final r = await _db.createStudentsBulk(
        rows: rows,
        enrollInClassId: widget.classModel?.id,
      );
      final parts = <String>[
        'تمت إضافة ${r.created} طالب',
        if (r.matchedExisting > 0)
          '${r.matchedExisting} موجود مسبقاً (نفس الرقم)',
        if (widget.classModel != null && r.enrolled > 0)
          'سُجّل ${r.enrolled} في الفصل',
        if (r.skipped > 0) 'تُجوهل ${r.skipped} صف',
      ];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.join(' • ')), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _snack(friendlyError(e), error: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _parsed;
    final cls = widget.classModel;
    final busy = _saving || _picking;

    return Scaffold(
      appBar: AppBar(
        title: Text(cls == null ? 'إضافة عدة طلاب' : 'إضافة طلاب إلى ${cls.name}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'اكتب كل طالب في سطر: الاسم، ثم الرقم، ثم جوال ولي الأمر (اختياري)، '
            'مفصولة بفاصلة. ويمكنك لصق أعمدة منسوخة من Excel مباشرة، '
            'أو استيراد ملف .xlsx / .csv.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 4),
          Text(
            'إن طابق رقمٌ طالباً موجوداً يُستخدم الطالب نفسه ولا يُنشأ مكرر.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _pickFile,
            icon: _picking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: const Text('استيراد من ملف Excel / CSV'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 8,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'أحمد علي، 1001، 0599000000\nسارة خالد، 1002',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isNotEmpty) ...[
            Text(
              'سيُضاف ${rows.length} طالب',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final s in rows.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  [
                    s.fullName,
                    if (s.studentCode != null) 'الرقم: ${s.studentCode}',
                    if (s.parentPhone != null) 'ولي الأمر: ${s.parentPhone}',
                  ].join('  •  '),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (rows.length > 5)
              Text('... و${rows.length - 5} آخرين',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: (busy || rows.isEmpty) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.group_add),
            label: Text(rows.isEmpty ? 'أضف' : 'إضافة ${rows.length} طالب'),
          ),
        ],
      ),
    );
  }
}
