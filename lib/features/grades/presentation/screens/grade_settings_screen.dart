import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';
import 'package:teacher_app/core/utils/color_utils.dart';

/// شاشة إعدادات الدرجات لكل فصل:
/// - سياسة الدرجة الناقصة (استثناء / صفر)
/// - سلم التقديرات (حدود قابلة للتخصيص لكل فصل)
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

  /// كل عنصر: {'min': num, 'grade': String}
  List<Map<String, dynamic>> _scale = [];

  static const _defaultScale = [
    {'min': 90, 'grade': 'ممتاز'},
    {'min': 80, 'grade': 'جيد جداً'},
    {'min': 70, 'grade': 'جيد'},
    {'min': 60, 'grade': 'مقبول'},
    {'min': 0, 'grade': 'ضعيف'},
  ];

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
        if (settings != null && settings.gradingScale.isNotEmpty) {
          _scale = settings.gradingScale
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => e['min'] is num && e['grade'] is String)
              .toList();
        }
        if (_scale.isEmpty) {
          _scale = _defaultScale
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        _sortScale();
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

  void _sortScale() {
    _scale.sort((a, b) {
      final am = (a['min'] as num?) ?? 0;
      final bm = (b['min'] as num?) ?? 0;
      return bm.compareTo(am);
    });
  }

  // ================== DIALOG: ADD / EDIT ==================

  Future<void> _editLevel({int? index}) async {
    final isNew = index == null;
    final existing = isNew ? null : _scale[index];
    final minCtrl = TextEditingController(
        text: existing == null ? '' : formatNumber(existing['min'] as num));
    final nameCtrl = TextEditingController(
        text: (existing?['grade'] as String?) ?? '');
    String? minError;
    String? nameError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isNew ? 'إضافة تقدير جديد' : 'تعديل التقدير'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'الحد الأدنى (%)',
                  hintText: 'مثال: 90',
                  errorText: minError,
                  helperText: 'النسبة المئوية الدنيا لهذا التقدير',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'اسم التقدير',
                  hintText: 'مثال: ممتاز، A، جيد جداً',
                  errorText: nameError,
                ),
                autofocus: isNew,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final minVal = parseNumber(minCtrl.text);
                final name = nameCtrl.text.trim();
                if (minVal == null || minVal < 0 || minVal > 100) {
                  setLocal(() => minError = 'أدخل رقماً بين 0 و 100');
                  return;
                }
                if (name.isEmpty) {
                  setLocal(() => nameError = 'أدخل اسم التقدير');
                  return;
                }
                // منع تكرار الحد الأدنى
                for (var i = 0; i < _scale.length; i++) {
                  if (i == index) continue;
                  final existingMin =
                      (_scale[i]['min'] as num).toDouble();
                  if ((existingMin - minVal).abs() < 0.01) {
                    setLocal(() =>
                        minError = 'هذا الحد مستخدم في تقدير آخر');
                    return;
                  }
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final minVal = parseNumber(minCtrl.text)!;
      final name = nameCtrl.text.trim();
      setState(() {
        if (isNew) {
          _scale.add({'min': minVal, 'grade': name});
        } else {
          _scale[index!] = {'min': minVal, 'grade': name};
        }
        _sortScale();
      });
    }

    minCtrl.dispose();
    nameCtrl.dispose();
  }

  // ================== DELETE ==================

  Future<void> _deleteLevel(int index) async {
    if (_scale.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب الاحتفاظ بمستوى واحد على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final level = _scale[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقدير'),
        content: Text(
          'سيُحذف "${level['grade']}" من سلم التقديرات.\n'
          'الطلاب الحاليون سيُعرضون بالتقدير الأدنى التالي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _scale.removeAt(index));
    }
  }

  // ================== RESET TO DEFAULT ==================

  Future<void> _resetToDefault() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة السلم الافتراضي'),
        content: const Text(
          'سيُستبدل السلم الحالي بالسلم الافتراضي:\n'
          '• 90% ممتاز\n'
          '• 80% جيد جداً\n'
          '• 70% جيد\n'
          '• 60% مقبول\n'
          '• 0% ضعيف',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _scale =
            _defaultScale.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
  }

  // ================== SAVE ==================

  Future<void> _save() async {
    if (_scale.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف مستوى واحداً على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _db.saveGradeSettings(
        classId: widget.classModel.id,
        gradingScale: _scale,
        missingGradePolicy: _policy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الإعدادات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ================== HELPERS ==================

  String _rangeText(int i) {
    final min = (_scale[i]['min'] as num).toDouble();
    if (i == 0) {
      return 'من ${formatNumber(min)}% إلى 100%';
    }
    final upper = (_scale[i - 1]['min'] as num).toDouble();
    final display = (upper - 0.01);
    return 'من ${formatNumber(min)}% إلى ${formatNumber(display)}%';
  }

  String _preview(num percentage) {
    for (var i = 0; i < _scale.length; i++) {
      final min = (_scale[i]['min'] as num).toDouble();
      if (percentage >= min) {
        return _scale[i]['grade']?.toString() ?? '-';
      }
    }
    return 'غير محدد';
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الدرجات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // ===== 1. سياسة الدرجة الناقصة =====
                const Text(
                  'سياسة الدرجة الناقصة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'كيف يُحسب التقييم الذي لم تُدخل له درجة؟',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('استثناء التقييم (افتراضي)'),
                        subtitle:
                            const Text('لا يدخل في المعدل — أعدل للطالب'),
                        value: 'exclude',
                        groupValue: _policy,
                        onChanged: (v) =>
                            setState(() => _policy = v ?? 'exclude'),
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('احتساب صفر'),
                        subtitle: const Text('يُحسب صفراً على الطالب'),
                        value: 'zero',
                        groupValue: _policy,
                        onChanged: (v) => setState(() => _policy = v ?? 'zero'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ===== 2. سلم التقديرات =====
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'سلم التقديرات',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetToDefault,
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('افتراضي'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'حدد الحد الأدنى لكل تقدير. يُرتَّب تلقائياً من الأعلى للأدنى.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < _scale.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).primaryColor.soft(0.1),
                            child: Text(
                              formatNumber(_scale[i]['min'] as num),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          title: Text(
                            _scale[i]['grade']?.toString() ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _rangeText(i),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'تعديل',
                                icon:
                                    const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editLevel(index: i),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteLevel(i),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline,
                            color: Colors.green),
                        title: const Text('إضافة مستوى'),
                        onTap: () => _editLevel(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ===== 3. معاينة =====
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'معاينة (كيف ستظهر النتائج)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _previewRow(85),
                        _previewRow(75),
                        _previewRow(60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('حفظ الإعدادات'),
                ),
              ),
            ),
    );
  }

  Widget _previewRow(num percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$percentage%',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 14),
          const SizedBox(width: 8),
          Text(
            _preview(percentage),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
