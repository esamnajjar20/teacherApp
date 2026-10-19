import '../../core/utils/safe_parse.dart';
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
      id: SafeParse.string(json['id']),
      classId: SafeParse.string(json['class_id']),
      date: SafeParse.dateTimeOrNow(json['date']),
      period: SafeParse.stringOrNull(json['period']),
      notes: SafeParse.stringOrNull(json['notes']),
      deletedAt: SafeParse.dateTime(json['deleted_at']),
      createdAt: SafeParse.dateTimeOrNow(json['created_at']),
      updatedAt: SafeParse.dateTimeOrNow(json['updated_at']),
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
      id: SafeParse.string(json['id']),
      sessionId: SafeParse.string(json['session_id']),
      studentId: SafeParse.string(json['student_id']),
      status: SafeParse.string(json['status'], 'present'),
      notes: SafeParse.stringOrNull(json['notes']),
      deletedAt: SafeParse.dateTime(json['deleted_at']),
      createdAt: SafeParse.dateTimeOrNow(json['created_at']),
      updatedAt: SafeParse.dateTimeOrNow(json['updated_at']),
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
