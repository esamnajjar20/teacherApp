/// حساب إحصائيات الحضور لكل طالب.
class AttendanceStats {
  final String studentId;
  final int present;
  final int absent;
  final int tardy;
  final int excused;

  const AttendanceStats({
    required this.studentId,
    this.present = 0,
    this.absent = 0,
    this.tardy = 0,
    this.excused = 0,
  });

  /// نسبة الحضور = (حاضر + متأخر) ÷ (كل الجلسات − بعذر) × 100
  double? get percentage {
    final total = present + absent + tardy + excused;
    if (total == 0) return null;
    final denominator = total - excused;
    if (denominator == 0) return null;
    return ((present + tardy) / denominator) * 100;
  }
}

class AttendanceCalculator {
  /// نسبة الحضور التي تحتها يُنبَّه إلى الطالب.
  static const double warningThreshold = 75.0;

  static List<AttendanceStats> summarize({
    required List<String> studentIds,
    required Iterable<({String studentId, String status})> records,
  }) {
    final map = <String, Map<String, int>>{
      for (final id in studentIds)
        id: {'present': 0, 'absent': 0, 'late': 0, 'excused': 0},
    };

    for (final r in records) {
      final entry = map[r.studentId];
      if (entry == null) continue;
      if (entry.containsKey(r.status)) {
        entry[r.status] = entry[r.status]! + 1;
      }
    }

    return map.entries.map((e) => AttendanceStats(
          studentId: e.key,
          present: e.value['present']!,
          absent: e.value['absent']!,
          tardy: e.value['late']!,
          excused: e.value['excused']!,
        )).toList();
  }

  static double? classAverage(List<AttendanceStats> stats) {
    final valid = stats.map((s) => s.percentage).whereType<double>().toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  static bool isBelowThreshold(double? percentage) {
    if (percentage == null) return false;
    return percentage < warningThreshold;
  }
}
