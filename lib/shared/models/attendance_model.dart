import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

class AttendanceSessionModel extends Equatable {
  final String id;
  final String classId;
  final DateTime date;
  final String? period;
  final String? notes;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceSessionModel({
    required this.id,
    required this.classId,
    required this.date,
    this.period,
    this.notes,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionModel(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      date: DateTime.parse(json['date'] as String),
      period: json['period'] as String?,
      notes: json['notes'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, classId, date, period, notes, deletedAt, createdAt, updatedAt];
}

class AttendanceRecordModel extends Equatable {
  final String id;
  final String sessionId;
  final String studentId;
  final String status;
  final String? notes;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.status,
    this.notes,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusLabel =>
      AppConstants.attendanceStatusLabels[status] ?? status;

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      studentId: json['student_id'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  AttendanceRecordModel copyWith({
    String? status,
    String? notes,
  }) {
    return AttendanceRecordModel(
      id: id,
      sessionId: sessionId,
      studentId: studentId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      deletedAt: deletedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, sessionId, studentId, status, notes, deletedAt, createdAt, updatedAt];
}
