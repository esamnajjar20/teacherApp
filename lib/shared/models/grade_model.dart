import '../../core/utils/safe_parse.dart';
import 'package:equatable/equatable.dart';

class AssessmentModel extends Equatable {
  final String id;
  final String classId;
  final String name;
  final String? type;
  final double weight;
  final double maxScore;
  final DateTime? date;
  final bool isActive;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssessmentModel({
    required this.id,
    required this.classId,
    required this.name,
    this.type,
    required this.weight,
    required this.maxScore,
    this.date,
    this.isActive = true,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssessmentModel.fromJson(Map<String, dynamic> json) {
    return AssessmentModel(
      id: SafeParse.string(json['id']),
      classId: SafeParse.string(json['class_id']),
      name: SafeParse.string(json['name']),
      type: SafeParse.stringOrNull(json['type']),
      weight: SafeParse.doubleOr(json['weight'], 0.0),
      maxScore: SafeParse.doubleOr(json['max_score'], 100.0),
      date: SafeParse.dateTime(json['date']),
      isActive: SafeParse.boolOr(json['is_active'], true),
      deletedAt: SafeParse.dateTime(json['deleted_at']),
      createdAt: SafeParse.dateTimeOrNow(json['created_at']),
      updatedAt: SafeParse.dateTimeOrNow(json['updated_at']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        classId,
        name,
        type,
        weight,
        maxScore,
        date,
        isActive,
        deletedAt,
        createdAt,
        updatedAt,
      ];
}

class GradeModel extends Equatable {
  final String id;
  final String assessmentId;
  final String studentId;
  final double? rawScore;
  final String? notes;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GradeModel({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    this.rawScore,
    this.notes,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// النسبة المئوية = (الدرجة الخام ÷ الدرجة العظمى) × 100
  double? percentage(double maxScore) {
    if (rawScore == null || maxScore <= 0) return null;
    return (rawScore! / maxScore) * 100;
  }

  /// الدرجة المرجحة = (الدرجة الخام ÷ الدرجة العظمى) × الوزن
  double? weightedScore(double maxScore, double weight) {
    if (rawScore == null || maxScore <= 0) return null;
    return (rawScore! / maxScore) * weight;
  }

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      id: SafeParse.string(json['id']),
      assessmentId: SafeParse.string(json['assessment_id']),
      studentId: SafeParse.string(json['student_id']),
      rawScore: SafeParse.doubleOrNull(json['raw_score']),
      notes: SafeParse.stringOrNull(json['notes']),
      deletedAt: SafeParse.dateTime(json['deleted_at']),
      createdAt: SafeParse.dateTimeOrNow(json['created_at']),
      updatedAt: SafeParse.dateTimeOrNow(json['updated_at']),
    );
  }

  GradeModel copyWith({
    double? rawScore,
    String? notes,
  }) {
    return GradeModel(
      id: id,
      assessmentId: assessmentId,
      studentId: studentId,
      rawScore: rawScore ?? this.rawScore,
      notes: notes ?? this.notes,
      deletedAt: deletedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, assessmentId, studentId, rawScore, notes, deletedAt, createdAt, updatedAt];
}

class GradeSettingsModel extends Equatable {
  final String id;
  final String classId;
  final List<Map<String, dynamic>> gradingScale;
  final String missingGradePolicy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GradeSettingsModel({
    required this.id,
    required this.classId,
    required this.gradingScale,
    this.missingGradePolicy = 'exclude',
    required this.createdAt,
    required this.updatedAt,
  });

  factory GradeSettingsModel.fromJson(Map<String, dynamic> json) {
    return GradeSettingsModel(
      id: SafeParse.string(json['id']),
      classId: SafeParse.string(json['class_id']),
      gradingScale: (json['grading_scale'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      missingGradePolicy:
          SafeParse.string(json['missing_grade_policy'], 'exclude'),
      createdAt: SafeParse.dateTimeOrNow(json['created_at']),
      updatedAt: SafeParse.dateTimeOrNow(json['updated_at']),
    );
  }

  @override
  List<Object?> get props =>
      [id, classId, gradingScale, missingGradePolicy, createdAt, updatedAt];
}
