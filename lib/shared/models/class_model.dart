import 'package:equatable/equatable.dart';

class ClassModel extends Equatable {
  final String id;
  final String teacherId;
  final String name;
  final String? subject;
  final String? academicYear;
  final bool isArchived;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClassModel({
    required this.id,
    required this.teacherId,
    required this.name,
    this.subject,
    this.academicYear,
    this.isArchived = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String,
      name: json['name'] as String,
      subject: json['subject'] as String?,
      academicYear: json['academic_year'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
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
      'teacher_id': teacherId,
      'name': name,
      'subject': subject,
      'academic_year': academicYear,
      'is_archived': isArchived,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ClassModel copyWith({
    String? id,
    String? teacherId,
    String? name,
    String? subject,
    String? academicYear,
    bool? isArchived,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      academicYear: academicYear ?? this.academicYear,
      isArchived: isArchived ?? this.isArchived,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        teacherId,
        name,
        subject,
        academicYear,
        isArchived,
        deletedAt,
        createdAt,
        updatedAt,
      ];
}
