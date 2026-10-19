import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/grade_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/services/database_service.dart';

String _deletedOn(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return 'حُذف في ${l.year}/${l.month.toString().padLeft(2, '0')}/${l.day.toString().padLeft(2, '0')}';
}

/// سلة المحذوفات: استعادة الفصول والطلاب والتقييمات المحذوفة.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with SyncRefreshMixin {
  final _db = DatabaseService();
  List<ClassModel> _classes = [];
  List<StudentModel> _students = [];
  List<({AssessmentModel assessment, String className})> _assessments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> reloadSilently() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final classes = await _db.getDeletedClasses();
      final students = await _db.getDeletedStudents();
      final assessments = await _db.getDeletedAssessments();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _students = students;
        _assessments = assessments;
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

  Future<void> _restore(Future<void> Function() action, String doneMessage) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(doneMessage), backgroundColor: Colors.green),
      );
      _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سلة المحذوفات'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'الفصول (${_classes.length})'),
              Tab(text: 'الطلاب (${_students.length})'),
              Tab(text: 'التقييمات (${_assessments.length})'),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    return TabBarView(
      children: [
        _list(
          count: _classes.length,
          builder: (i) {
            final c = _classes[i];
            return _tile(
              title: c.name,
              subtitle: [
                if (c.subject != null) c.subject!,
                _deletedOn(c.deletedAt),
              ].where((e) => e.isNotEmpty).join(' • '),
              onRestore: () => _restore(
                () => _db.restoreClass(c.id),
                'تمت استعادة الفصل بطلابه وحضوره ودرجاته',
              ),
            );
          },
        ),
        _list(
          count: _students.length,
          builder: (i) {
            final s = _students[i];
            return _tile(
              title: s.fullName,
              subtitle: [
                if (s.studentCode != null) 'الرقم: ${s.studentCode}',
                _deletedOn(s.deletedAt),
              ].where((e) => e.isNotEmpty).join(' • '),
              onRestore: () => _restore(
                () => _db.restoreStudent(s.id),
                'تمت استعادة الطالب',
              ),
            );
          },
        ),
        _list(
          count: _assessments.length,
          builder: (i) {
            final a = _assessments[i];
            return _tile(
              title: a.assessment.name,
              subtitle:
                  '${a.className} • من ${formatNumber(a.assessment.maxScore)} • ${_deletedOn(a.assessment.deletedAt)}',
              onRestore: () => _restore(
                () => _db.restoreAssessment(a.assessment.id),
                'تمت استعادة التقييم بدرجاته',
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _list({required int count, required Widget Function(int) builder}) {
    if (count == 0) {
      return const EmptyState(
        icon: Icons.delete_outline,
        title: 'لا يوجد شيء هنا',
        subtitle: 'ما تحذفه يظهر هنا ويمكنك استعادته',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: count,
        itemBuilder: (context, i) => builder(i),
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required VoidCallback onRestore,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: TextButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore),
          label: const Text('استعادة'),
        ),
      ),
    );
  }
}
