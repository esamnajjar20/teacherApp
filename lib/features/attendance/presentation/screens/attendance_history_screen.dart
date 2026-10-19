import 'package:flutter/material.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/sync_refresh_mixin.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';
import 'take_attendance_screen.dart';

const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String _fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// سجل جلسات الحضور السابقة لفصل: فتح جلسة لتعديلها أو حذفها.
class AttendanceHistoryScreen extends StatefulWidget {
  final ClassModel classModel;

  const AttendanceHistoryScreen({super.key, required this.classModel});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SyncRefreshMixin {
  final _db = DatabaseService();
  List<SessionSummary> _sessions = [];
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
      final list = await _db.getSessionSummaries(widget.classModel.id);
      if (!mounted) return;
      setState(() {
        _sessions = list;
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

  Future<void> _open({DateTime? date}) async {
    try {
      final students = await _db.getStudentsInClass(widget.classModel.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TakeAttendanceScreen(
            classModel: widget.classModel,
            students: students,
            initialDate: date,
          ),
        ),
      );
      _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(SessionSummary s) async {
    final confirm = await confirmDelete(
      context,
      title: 'حذف جلسة الحضور',
      message:
          'سيُحذف حضور يوم ${_fmtDate(s.session.date)} (${s.total} طالب) '
          'ويختفي من التقارير ونسب الحضور.\n'
          'يمكنك تسجيل حضور ذلك اليوم من جديد لاحقاً.',
    );
    if (!confirm || !mounted) return;
    try {
      await _db.softDeleteSession(s.session.id);
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
    return Scaffold(
      appBar: AppBar(title: Text('سجل حضور ${widget.classModel.name}')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('حضور اليوم'),
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
    if (_sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_outlined,
        title: 'لا توجد جلسات حضور بعد',
        subtitle: 'اضغط «حضور اليوم» لتسجيل أول جلسة',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: _sessions.length,
        itemBuilder: (context, i) {
          final s = _sessions[i];
          final d = s.session.date;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _open(date: d),
              title: Text(
                '${_weekdays[d.weekday - 1]}  ${_fmtDate(d)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'حاضر ${s.present} • غائب ${s.absent} • متأخر ${s.tardy} • بعذر ${s.excused}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تعديل الحضور',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _open(date: d),
                  ),
                  IconButton(
                    tooltip: 'حذف الجلسة',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(s),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
