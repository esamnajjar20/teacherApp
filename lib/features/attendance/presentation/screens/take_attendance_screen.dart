import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/models/student_model.dart';
import '../../../../shared/services/database_service.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final ClassModel classModel;
  final List<StudentModel> students;

  const TakeAttendanceScreen({
    super.key,
    required this.classModel,
    required this.students,
  });

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final _db = DatabaseService();
  late Map<String, String> _statusMap; // studentId -> status
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // الافتراضي = حاضر لكل الطلاب
    _statusMap = {
      for (final s in widget.students) s.id: AppConstants.present,
    };
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.present:
        return Colors.green;
      case AppConstants.absent:
        return Colors.red;
      case AppConstants.late:
        return Colors.orange;
      case AppConstants.excused:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case AppConstants.present:
        return Icons.check_circle;
      case AppConstants.absent:
        return Icons.cancel;
      case AppConstants.late:
        return Icons.access_time;
      case AppConstants.excused:
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  void _cycleStatus(String studentId) {
    final current = _statusMap[studentId] ?? AppConstants.present;
    final order = [
      AppConstants.present,
      AppConstants.absent,
      AppConstants.late,
      AppConstants.excused,
    ];
    final nextIndex = (order.indexOf(current) + 1) % order.length;
    setState(() {
      _statusMap[studentId] = order[nextIndex];
    });
  }

  Future<void> _save() async {
    if (widget.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب في الفصل')),
      );
      return;
    }

    // منع تسجيل حضور لتاريخ مستقبلي
    final today = DateTime.now();
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final now = DateTime(today.year, today.month, today.day);
    if (selected.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تسجيل حضور لتاريخ مستقبلي'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final session = await _db.createSession(
        classId: widget.classModel.id,
        date: _selectedDate,
      );

      await _db.saveAttendanceRecords(
        sessionId: session.id,
        records: _statusMap.entries
            .map((e) => (studentId: e.key, status: e.value))
            .toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الحضور بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount =
        _statusMap.values.where((s) => s == AppConstants.present).length;
    final absentCount =
        _statusMap.values.where((s) => s == AppConstants.absent).length;
    final lateCount =
        _statusMap.values.where((s) => s == AppConstants.late).length;
    final excusedCount =
        _statusMap.values.where((s) => s == AppConstants.excused).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الحضور'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط التاريخ + الملخص
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            child: Column(
              children: [
                InkWell(
                  onTap: _pickDate,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryChip(label: 'حاضر', count: presentCount, color: Colors.green),
                    _SummaryChip(label: 'غائب', count: absentCount, color: Colors.red),
                    _SummaryChip(label: 'متأخر', count: lateCount, color: Colors.orange),
                    _SummaryChip(label: 'بعذر', count: excusedCount, color: Colors.blue),
                  ],
                ),
              ],
            ),
          ),
          // قائمة الطلاب
          Expanded(
            child: widget.students.isEmpty
                ? const Center(child: Text('لا يوجد طلاب في الفصل'))
                : ListView.builder(
                    itemCount: widget.students.length,
                    itemBuilder: (context, index) {
                      final student = widget.students[index];
                      final status = _statusMap[student.id] ?? AppConstants.present;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(status).withOpacity(0.15),
                          child: Icon(
                            _statusIcon(status),
                            color: _statusColor(status),
                          ),
                        ),
                        title: Text(
                          student.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          AppConstants.attendanceStatusLabels[status] ?? status,
                          style: TextStyle(color: _statusColor(status)),
                        ),
                        trailing: Icon(
                          Icons.touch_app,
                          color: Colors.grey[400],
                        ),
                        onTap: () => _cycleStatus(student.id),
                      );
                    },
                  ),
          ),
          // تلميح
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Text(
              'اضغط على الطالب لتغيير الحالة (حاضر → غائب → متأخر → بعذر)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}
