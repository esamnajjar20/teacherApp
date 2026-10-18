import '../../shared/models/grade_model.dart';

/// حاسبة المعدلات حسب منطق العمل المتفق عليه
class GradeCalculator {
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
