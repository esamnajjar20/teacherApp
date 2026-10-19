import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/attendance_calculator.dart';
import '../../../../core/utils/excel_share.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../shared/models/attendance_model.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/services/database_service.dart';
import 'package:teacher_app/core/utils/color_utils.dart';

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// تقرير حضور فصل خلال فترة: نسبة الحضور لكل طالب + تصدير Excel.
class AttendanceReportScreen extends StatefulWidget {
  final ClassModel classModel;

  const AttendanceReportScreen({super.key, required this.classModel});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final _db = DatabaseService();

  late DateTime _from;
  late DateTime _to;

  List<StudentModel> _students = [];
  List<AttendanceSessionModel> _sessions = [];
  List<AttendanceRecordModel> _records = [];
  List<AttendanceStats> _stats = [];

  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = _dayOnly(DateTime.now());
    _to = now;
    _from = DateTime(now.year, now.month, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final students = await _db.getStudentsInClass(widget.classModel.id);
      final sessions = await _db.getSessionsInRange(
        classId: widget.classModel.id,
        from: _from,
        to: _to,
      );
      final records =
          await _db.getRecordsForSessions(sessions.map((s) => s.id).toList());

      final stats = AttendanceCalculator.summarize(
        studentIds: students.map((s) => s.id).toList(),
        records: records
            .map((r) => (studentId: r.studentId, status: r.status)),
      );

      if (!mounted) return;
      setState(() {
        _students = students;
        _sessions = sessions;
        _records = records;
        _stats = stats;
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

  void _setRange(DateTime from, DateTime to) {
    _from = _dayOnly(from);
    _to = _dayOnly(to);
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    _setRange(picked.start, picked.end);
  }

  Map<String, StudentModel> get _studentById =>
      {for (final s in _students) s.id: s};

  /// الأكثر غياباً أولاً حتى يظهر من يحتاج متابعة في أعلى القائمة
  List<AttendanceStats> get _sortedStats {
    final list = List<AttendanceStats>.from(_stats);
    list.sort((a, b) {
      final pa = a.percentage;
      final pb = b.percentage;
      if (pa == null && pb == null) {
        return (_studentById[a.studentId]?.fullName ?? '')
            .compareTo(_studentById[b.studentId]?.fullName ?? '');
      }
      if (pa == null) return 1;
      if (pb == null) return -1;
      final c = pa.compareTo(pb);
      if (c != 0) return c;
      return (_studentById[a.studentId]?.fullName ?? '')
          .compareTo(_studentById[b.studentId]?.fullName ?? '');
    });
    return list;
  }

  String _pctText(double? p) => p == null ? '-' : '${p.toStringAsFixed(0)}%';

  // ============================ EXPORT ============================

  static const _codes = {
    AppConstants.present: 'ح',
    AppConstants.absent: 'غ',
    AppConstants.late: 'ت',
    AppConstants.excused: 'ع',
  };

  Future<void> _export() async {
    if (_sessions.isEmpty || _students.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      const summaryName = 'ملخص الحضور';
      const detailName = 'التفصيل اليومي';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', summaryName);
      final summary = excel[summaryName];
      final detail = excel[detailName];
      summary.isRTL = true;
      detail.isRTL = true;

      final byId = _studentById;
      final cls = widget.classModel;

      // ---- الورقة 1: الملخص ----
      summary.appendRow([TextCellValue('تقرير حضور: ${cls.name}')]);
      summary.appendRow([
        TextCellValue('من ${_fmtDate(_from)} إلى ${_fmtDate(_to)}'),
        TextCellValue('عدد الجلسات: ${_sessions.length}'),
      ]);
      summary.appendRow([
        TextCellValue(
            'نسبة الحضور = (حاضر + متأخر) ÷ (كل الجلسات - بعذر). المتأخر يُحتسب حاضراً.'),
      ]);
      summary.appendRow([]);
      summary.appendRow([
        TextCellValue('الطالب'),
        TextCellValue('حاضر'),
        TextCellValue('غائب'),
        TextCellValue('متأخر'),
        TextCellValue('بعذر'),
        TextCellValue('نسبة الحضور (%)'),
      ]);
      for (final st in _stats) {
        final p = st.percentage;
        summary.appendRow([
          TextCellValue(byId[st.studentId]?.fullName ?? ''),
          IntCellValue(st.present),
          IntCellValue(st.absent),
          IntCellValue(st.tardy),
          IntCellValue(st.excused),
          p == null
              ? TextCellValue('-')
              : DoubleCellValue(double.parse(p.toStringAsFixed(1))),
        ]);
      }
      final avg = AttendanceCalculator.classAverage(_stats);
      summary.appendRow([]);
      summary.appendRow([
        TextCellValue('متوسط الفصل'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        avg == null
            ? TextCellValue('-')
            : DoubleCellValue(double.parse(avg.toStringAsFixed(1))),
      ]);

      // ---- الورقة 2: التفصيل اليومي ----
      final lookup = <String, String>{
        for (final r in _records) '${r.sessionId}|${r.studentId}': r.status,
      };
      detail.appendRow([TextCellValue('تفصيل الحضور: ${cls.name}')]);
      detail.appendRow([
        TextCellValue('ح = حاضر   غ = غائب   ت = متأخر   ع = بعذر   - = غير مسجّل'),
      ]);
      detail.appendRow([]);
      detail.appendRow([
        TextCellValue('الطالب'),
        for (final s in _sessions)
          TextCellValue(
              s.period == null ? _fmtDate(s.date) : '${_fmtDate(s.date)} (${s.period})'),
      ]);
      for (final st in _students) {
        detail.appendRow([
          TextCellValue(st.fullName),
          for (final s in _sessions)
            TextCellValue(_codes[lookup['${s.id}|${st.id}']] ?? '-'),
        ]);
      }

      await shareExcel(
        excel,
        baseName: 'attendance_${cls.name}',
        text: 'تقرير حضور ${cls.name}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تجهيز الملف'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في التصدير: ${friendlyError(e)}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ============================ UI ============================

  @override
  Widget build(BuildContext context) {
    final canExport = !_isLoading && !_isExporting && _sessions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('تقرير الحضور - ${widget.classModel.name}'),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'تصدير Excel',
              icon: const Icon(Icons.ios_share),
              onPressed: canExport ? _export : null,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildRangeBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildRangeBar() {
    final now = _dayOnly(DateTime.now());
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickRange,
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'من ${_fmtDate(_from)} إلى ${_fmtDate(_to)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Text('تغيير'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('هذا الشهر'),
                onPressed: () =>
                    _setRange(DateTime(now.year, now.month, 1), now),
              ),
              ActionChip(
                label: const Text('آخر 30 يوماً'),
                onPressed: () =>
                    _setRange(now.subtract(const Duration(days: 29)), now),
              ),
              ActionChip(
                label: const Text('كل الفترة'),
                onPressed: () => _setRange(DateTime(2020), now),
              ),
            ],
          ),
        ],
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
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    if (_students.isEmpty) {
      return const Center(child: Text('لا يوجد طلاب في هذا الفصل'));
    }
    if (_sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد جلسات حضور في هذه الفترة',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final avg = AttendanceCalculator.classAverage(_stats);
    final atRisk =
        _stats.where((s) => AttendanceCalculator.isBelowThreshold(s.percentage)).length;
    final sorted = _sortedStats;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _summaryCard('الجلسات', '${_sessions.length}', Colors.blue),
              const SizedBox(width: 8),
              _summaryCard('متوسط الحضور', _pctText(avg), Colors.green),
              const SizedBox(width: 8),
              _summaryCard(
                'أقل من ${formatNumber(AttendanceCalculator.warningThreshold)}%',
                '$atRisk',
                atRisk > 0 ? Colors.red : Colors.grey,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final st = sorted[i];
              final name = _studentById[st.studentId]?.fullName ?? '';
              final p = st.percentage;
              final low = AttendanceCalculator.isBelowThreshold(p);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'حاضر ${st.present}  •  غائب ${st.absent}  •  متأخر ${st.tardy}  •  بعذر ${st.excused}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (p == null
                              ? Colors.grey
                              : (low ? Colors.red : Colors.green))
                          .soft(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _pctText(p),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: p == null
                            ? Colors.grey
                            : (low ? Colors.red : Colors.green.shade700),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.soft(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
