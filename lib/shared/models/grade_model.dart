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
      id: json['id'] as String,
      classId: json['class_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      weight: (json['weight'] as num).toDouble(),
      maxScore: (json['max_score'] as num).toDouble(),
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      isActive: json['is_active'] as bool? ?? true,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'name': name,
      'type': type,
      'weight': weight,
      'max_score': maxScore,
      'date': date?.toIso8601String().split('T').first,
      'is_active': isActive,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
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
      id: json['id'] as String,
      assessmentId: json['assessment_id'] as String,
      studentId: json['student_id'] as String,
      rawScore: json['raw_score'] != null
          ? (json['raw_score'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assessment_id': assessmentId,
      'student_id': studentId,
      'raw_score': rawScore,
      'notes': notes,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
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
      id: json['id'] as String,
      classId: json['class_id'] as String,
      gradingScale: (json['grading_scale'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      missingGradePolicy: json['missing_grade_policy'] as String? ?? 'exclude',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'grading_scale': gradingScale,
      'missing_grade_policy': missingGradePolicy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props =>
      [id, classId, gradingScale, missingGradePolicy, createdAt, updatedAt];
}
