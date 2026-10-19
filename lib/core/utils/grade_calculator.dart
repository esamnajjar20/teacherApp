import '../../shared/models/grade_model.dart';

/// حاسبة المعدلات حسب منطق العمل المتفق عليه
class GradeCalculator {
  static const List<Map<String, dynamic>> defaultScale = [
    {'min': 90, 'grade': 'ممتاز'},
    {'min': 80, 'grade': 'جيد جداً'},
    {'min': 70, 'grade': 'جيد'},
    {'min': 60, 'grade': 'مقبول'},
    {'min': 0, 'grade': 'ضعيف'},
  ];

  static List<StudentResult> classResults({
    required List<String> studentIds,
    required List<AssessmentModel> assessments,
    required List<GradeModel> grades,
    required String policy,
    required List<Map<String, dynamic>> scale,
  }) {
    final list = <StudentResult>[];
    for (final id in studentIds) {
      final items = <({AssessmentModel assessment, GradeModel? grade})>[];
      for (final a in assessments) {
        if (!a.isActive) continue;
        final g = grades
            .where((g) => g.assessmentId == a.id && g.studentId == id)
            .firstOrNull;
        items.add((assessment: a, grade: g));
      }

      final avg = calculateFinalAverage(items: items, policy: policy);
      final letter = avg == null ? null : getLetterGrade(avg, scale);
      list.add(StudentResult(studentId: id, average: avg, letter: letter));
    }

    final sorted = list.where((r) => r.average != null).toList()
      ..sort((a, b) => b.average!.compareTo(a.average!));
    for (var i = 0; i < sorted.length; i++) {
      final originalIndex =
          list.indexWhere((r) => r.studentId == sorted[i].studentId);
      list[originalIndex] = StudentResult(
        studentId: list[originalIndex].studentId,
        average: list[originalIndex].average,
        letter: list[originalIndex].letter,
        rank: i + 1,
      );
    }
    return list;
  }

  /// حساب المعدل النهائي لطالب
  /// [grades] قائمة درجات الطالب مع تقييماتها
  /// [policy] 'exclude' أو 'zero'
  static double? calculateFinalAverage({
    required List<({AssessmentModel assessment, GradeModel? grade})> items,
    required String policy,
  }) {
    double totalWeighted = 0;
    double totalWeight = 0;

    for (final item in items) {
      final assessment = item.assessment;
      final grade = item.grade;

      if (!assessment.isActive) continue;

      if (grade?.rawScore == null) {
        if (policy == 'zero') {
          // احتساب صفر
          totalWeight += assessment.weight;
        }
        // exclude → نتخطى التقييم
        continue;
      }

      final weighted = grade!.weightedScore(assessment.maxScore, assessment.weight);
      if (weighted != null) {
        totalWeighted += weighted;
        totalWeight += assessment.weight;
      }
    }

    if (totalWeight == 0) return null;
    return totalWeighted / totalWeight * 100; // نرجّع نسبة من 100
  }

  /// تحويل النسبة إلى تقدير حسب السلم.
  /// يتعامل بأمان مع مدخلات تالفة (min = null، grade = null، scale فارغ).
  static String? getLetterGrade(
    double percentage,
    List<Map<String, dynamic>> scale,
  ) {
    final valid = <MapEntry<num, String?>>[];
    for (final entry in scale) {
      final minVal = entry['min'];
      if (minVal is! num) continue;
      final gradeVal = entry['grade'];
      valid.add(MapEntry(minVal, gradeVal is String ? gradeVal : null));
    }
    if (valid.isEmpty) return null;

    valid.sort((a, b) => b.key.compareTo(a.key));
    for (final e in valid) {
      if (percentage >= e.key) return e.value;
    }
    return null;
  }
}


class StudentResult {
  final String studentId;
  final double? average;
  final String? letter;
  final int? rank;

  StudentResult({
    required this.studentId,
    this.average,
    this.letter,
    this.rank,
  });
}
