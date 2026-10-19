import 'package:flutter/material.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';
import 'class_detail_screen.dart';
import 'package:teacher_app/core/utils/color_utils.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> with SyncRefreshMixin {
  final _db = DatabaseService();
  List<ClassModel> _classes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  Future<void> reloadSilently() => _loadClasses(silent: true);

  Future<void> _loadClasses({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final list = await _db.getClasses();
      if (!mounted) return;
      setState(() {
        _classes = list;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  /// نافذة واحدة للإضافة والتعديل. [existing] == null يعني إضافة.
  Future<void> _showClassDialog({ClassModel? existing}) async {
    final nameController = TextEditingController(text: existing?.name);
    final subjectController = TextEditingController(text: existing?.subject);
    final now = DateTime.now();
    // العام الدراسي يبدأ تقريباً في شهر 8 (أغسطس)
    final startYear = now.month >= 8 ? now.year : now.year - 1;
    final yearController = TextEditingController(
        text: existing != null
            ? existing.academicYear
            : '$startYear-${startYear + 1}');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة فصل جديد' : 'تعديل الفصل'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الفصل',
                  hintText: 'مثال: الصف العاشر - شعبة أ',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'المادة',
                  hintText: 'مثال: رياضيات',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                decoration: const InputDecoration(labelText: 'السنة الدراسية'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    final subject = subjectController.text.trim();
    final year = yearController.text.trim();

    // نحرر الـ controllers فوراً بعد قراءة القيم
    nameController.dispose();
    subjectController.dispose();
    yearController.dispose();

    if (result != true) return;

    try {
      if (existing == null) {
        await _db.createClass(
          name: name,
          subject: subject.isEmpty ? null : subject,
          academicYear: year.isEmpty ? null : year,
        );
      } else {
        await _db.updateClass(
          id: existing.id,
          name: name,
          subject: subject.isEmpty ? null : subject,
          academicYear: year.isEmpty ? null : year,
        );
      }
      _loadClasses(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null
                ? 'تم إضافة الفصل بنجاح'
                : 'تم حفظ التعديلات'),
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

  Future<void> _deleteClass(ClassModel cls) async {
    try {
      final impact = await _db.classDeletionImpact(cls.id);
      final lines = <String>[
        if (impact.students > 0) '• ${impact.students} طالب في الفصل',
        if (impact.sessions > 0) '• ${impact.sessions} جلسة حضور',
        if (impact.assessments > 0) '• ${impact.assessments} تقييم بدرجاته',
      ];
      final message = StringBuffer('سيختفي فصل "${cls.name}"');
      if (lines.isNotEmpty) {
        message
          ..write(' وكل ما فيه من الشاشات والتقارير:\n')
          ..write(lines.join('\n'));
      } else {
        message.write(' من القوائم.');
      }
      message.write('\n\nالطلاب أنفسهم لا يُحذفون. ويمكنك استعادة الفصل من سلة المحذوفات.');

      if (!mounted) return;
      final ok = await confirmDelete(
        context,
        title: 'حذف الفصل',
        message: message.toString(),
      );
      if (!ok) return;

      await _db.softDeleteClass(cls.id);
      _loadClasses(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadClasses, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    return Scaffold(
      body: _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('لا توجد فصول بعد', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('اضغط + لإضافة فصل جديد', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadClasses,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final cls = _classes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.soft(0.1),
                        child: Icon(Icons.class_, color: Theme.of(context).primaryColor),
                      ),
                      title: Text(cls.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([
                        if (cls.subject != null) cls.subject!,
                        if (cls.academicYear != null) cls.academicYear!,
                      ].join(' • ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'تعديل',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showClassDialog(existing: cls),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteClass(cls),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassDetailScreen(classModel: cls),
                          ),
                        ).then((_) => _loadClasses(silent: true));
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClassDialog(),
        icon: const Icon(Icons.add),
        label: const Text('فصل جديد'),
      ),
    );
  }
}
