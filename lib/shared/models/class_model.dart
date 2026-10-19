import '../../core/utils/safe_parse.dart';
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
      id: SafeParse.string(json['id']),
      teacherId: SafeParse.string(json['teacher_id']),
      name: SafeParse.string(json['name']),
      subject: SafeParse.stringOrNull(json['subject']),
      academicYear: SafeParse.stringOrNull(json['academic_year']),
      isArchived: SafeParse.boolOr(json['is_archived']),
      deletedAt: SafeParse.dateTime(json['deleted_at']),
      createdAt: SafeParse.dateTimeOrNow(json['created_at']),
      updatedAt: SafeParse.dateTimeOrNow(json['updated_at']),
    );
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
