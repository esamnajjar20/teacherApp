import '../../core/utils/safe_parse.dart';
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
      id: SafeParse.string(json['id']),
      teacherId: SafeParse.string(json['teacher_id']),
      fullName: SafeParse.string(json['full_name']),
      studentCode: SafeParse.stringOrNull(json['student_code']),
      parentPhone: SafeParse.stringOrNull(json['parent_phone']),
      notes: SafeParse.stringOrNull(json['notes']),
      deletedAt: SafeParse.dateTime(json['deleted_at']),
      createdAt: SafeParse.dateTimeOrNow(json['created_at']),
      updatedAt: SafeParse.dateTimeOrNow(json['updated_at']),
    );
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
