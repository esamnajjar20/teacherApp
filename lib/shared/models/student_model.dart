import 'package:equatable/equatable.dart';

class StudentModel extends Equatable {
  final String id;
  final String teacherId;
  final String fullName;
  final String? studentCode;
  final String? parentPhone;
  final String? notes;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentModel({
    required this.id,
    required this.teacherId,
    required this.fullName,
    this.studentCode,
    this.parentPhone,
    this.notes,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String,
      fullName: json['full_name'] as String,
      studentCode: json['student_code'] as String?,
      parentPhone: json['parent_phone'] as String?,
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
      'teacher_id': teacherId,
      'full_name': fullName,
      'student_code': studentCode,
      'parent_phone': parentPhone,
      'notes': notes,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StudentModel copyWith({
    String? id,
    String? teacherId,
    String? fullName,
    String? studentCode,
    String? parentPhone,
    String? notes,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      fullName: fullName ?? this.fullName,
      studentCode: studentCode ?? this.studentCode,
      parentPhone: parentPhone ?? this.parentPhone,
      notes: notes ?? this.notes,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        teacherId,
        fullName,
        studentCode,
        parentPhone,
        notes,
        deletedAt,
        createdAt,
        updatedAt,
      ];
}
