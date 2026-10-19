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

      double totalWeighted = 0;
      double totalWeight = 0;
      for (final item in items) {
        final assessment = item.assessment;
        final grade = item.grade;
        if (grade?.rawScore == null) {
          if (policy == 'zero') totalWeight += assessment.weight;
          continue;
        }
        final weighted =
            grade!.weightedScore(assessment.maxScore, assessment.weight);
        if (weighted != null) {
          totalWeighted += weighted;
          totalWeight += assessment.weight;
        }
      }

      final avg = totalWeight == 0 ? null : (totalWeighted / totalWeight * 100);
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

  /// تحويل النسبة إلى تقدير حسب السلم
  static String? getLetterGrade(
    double percentage,
    List<Map<String, dynamic>> scale,
  ) {
    // scale مثال: [{"min": 90, "grade": "A"}, {"min": 80, "grade": "B"}, ...]
    final sorted = List<Map<String, dynamic>>.from(scale)
      ..sort((a, b) => (b['min'] as num).compareTo(a['min'] as num));

    for (final entry in sorted) {
      if (percentage >= (entry['min'] as num)) {
        return entry['grade'] as String?;
      }
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
