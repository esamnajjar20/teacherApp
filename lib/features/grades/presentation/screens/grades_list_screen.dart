import 'package:flutter/material.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';
import 'assessments_screen.dart';
import 'package:teacher_app/core/utils/color_utils.dart';

class GradesListScreen extends StatefulWidget {
  const GradesListScreen({super.key});

  @override
  State<GradesListScreen> createState() => _GradesListScreenState();
}

class _GradesListScreenState extends State<GradesListScreen>
    with SyncRefreshMixin {
  final _db = DatabaseService();
  List<ClassModel> _classes = [];
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
      final list = await _db.getClasses();
      if (!mounted) return;
      setState(() {
        _classes = list;
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

  /// يفتح تقييمات الفصل مباشرة (بدل المرور بشاشة تفاصيل الفصل)
  Future<void> _openGrades(ClassModel cls) async {
    try {
      final students = await _db.getStudentsInClass(cls.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentsScreen(
            classModel: cls,
            students: students,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grade_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('لا توجد فصول', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(
                    'أنشئ فصلاً أولاً من تبويب الفصول',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final cls = _classes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.soft(0.15),
                        child: const Icon(Icons.grade, color: Colors.amber),
                      ),
                      title: Text(cls.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(cls.subject ?? 'اضغط لإدارة الدرجات'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _openGrades(cls),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
