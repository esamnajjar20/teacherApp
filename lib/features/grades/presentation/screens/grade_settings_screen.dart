import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';

class GradeSettingsScreen extends StatefulWidget {
  final ClassModel classModel;
  const GradeSettingsScreen({super.key, required this.classModel});

  @override
  State<GradeSettingsScreen> createState() => _GradeSettingsScreenState();
}

class _GradeSettingsScreenState extends State<GradeSettingsScreen>
    with SyncRefreshMixin {
  final _db = DatabaseService();
  bool _isLoading = true;
  bool _isSaving = false;
  String _policy = 'exclude';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> reloadSilently() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    try {
      final settings = await _db.getGradeSettings(widget.classModel.id);
      if (!mounted) return;
      setState(() {
        _policy = settings?.missingGradePolicy ?? 'exclude';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final existing = await _db.getGradeSettings(widget.classModel.id);
      final scale = existing?.gradingScale ??
          [
            {'min': 90, 'grade': 'ممتاز'},
            {'min': 80, 'grade': 'جيد جداً'},
            {'min': 70, 'grade': 'جيد'},
            {'min': 60, 'grade': 'مقبول'},
            {'min': 0, 'grade': 'ضعيف'},
          ];
      await _db.saveGradeSettings(
        classId: widget.classModel.id,
        gradingScale: scale.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        missingGradePolicy: _policy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم حفظ الإعدادات'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الدرجات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'سياسة الدرجة الناقصة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: const Text('استثناء التقييم (الافتراضي)'),
                  subtitle: const Text(
                      'التقييم الذي ليس له درجة لا يدخل في حساب المعدل'),
                  value: 'exclude',
                  groupValue: _policy,
                  onChanged: (v) => setState(() => _policy = v ?? 'exclude'),
                ),
                RadioListTile<String>(
                  title: const Text('احتساب صفر'),
                  subtitle: const Text(
                      'أي تقييم بدون درجة يُحسب صفراً على الطالب'),
                  value: 'zero',
                  groupValue: _policy,
                  onChanged: (v) => setState(() => _policy = v ?? 'exclude'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('حفظ'),
                ),
              ],
            ),
    );
  }
}
