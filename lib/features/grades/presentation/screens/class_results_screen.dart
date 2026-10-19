import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/grade_calculator.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';

class ClassResultsScreen extends StatefulWidget {
  final ClassModel classModel;
  const ClassResultsScreen({super.key, required this.classModel});

  @override
  State<ClassResultsScreen> createState() => _ClassResultsScreenState();
}

class _ClassResultsScreenState extends State<ClassResultsScreen>
    with SyncRefreshMixin {
  final _db = DatabaseService();
  bool _isLoading = true;
  String? _error;
  List<({String name, double? average, String? letter, int? rank})> _rows = [];

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
      final students = await _db.getStudentsInClass(widget.classModel.id);
      final assessments = (await _db.getAssessments(widget.classModel.id))
          .where((a) => a.isActive)
          .toList();
      final grades = await _db
          .getGradesForAssessments(assessments.map((a) => a.id).toList());
      final settings = await _db.getGradeSettings(widget.classModel.id);
      final scale = (settings == null || settings.gradingScale.isEmpty)
          ? GradeCalculator.defaultScale
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : settings.gradingScale;

      final results = GradeCalculator.classResults(
        studentIds: students.map((s) => s.id).toList(),
        assessments: assessments,
        grades: grades,
        policy: settings?.missingGradePolicy ?? 'exclude',
        scale: scale,
      );

      final names = {for (final s in students) s.id: s.fullName};
      final list = results
          .map((r) => (
                name: names[r.studentId] ?? '',
                average: r.average,
                letter: r.letter,
                rank: r.rank,
              ))
          .toList()
        ..sort((a, b) {
          if (a.rank == null && b.rank == null) return a.name.compareTo(b.name);
          if (a.rank == null) return 1;
          if (b.rank == null) return -1;
          return a.rank!.compareTo(b.rank!);
        });

      if (!mounted) return;
      setState(() {
        _rows = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('نتائج ${widget.classModel.name}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _rows.isEmpty
                  ? const Center(child: Text('لا يوجد طلاب في هذا الفصل'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(r.rank?.toString() ?? '-'),
                            ),
                            title: Text(r.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(r.letter ?? 'بلا تقدير'),
                            trailing: Text(
                              r.average == null
                                  ? '-'
                                  : '${r.average!.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
