import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/supabase_client.dart';
import '../local/local_database.dart';
import '../models/attendance_model.dart';
import '../models/class_model.dart';
import '../models/grade_model.dart';
import '../models/student_model.dart';
import 'sync_service.dart';

/// طبقة البيانات (Offline-First).
///
/// كل القراءة والكتابة تتم على قاعدة SQLite المحلية فقط، فتعمل بدون إنترنت.
/// كل تعديل يُعلَّم dirty=1 ثم يرفعه [SyncService] للسيرفر عند توفر الاتصال.
class DatabaseService {
  final _uuid = const Uuid();

  Future<Database> get _db => LocalDatabase.instance.open();

  /// معرّف المعلم الحالي (من الجلسة المحفوظة، يعمل بدون إنترنت)
  String get _uid {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw StateError('انتهت الجلسة، سجّل الدخول من جديد');
    }
    return id;
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _dec(String table, Map<String, Object?> row) =>
      LocalDatabase.decode(table, row);

  void _changed() => SyncService.instance.notifyLocalChange();

  /// إدراج صف جديد معلَّم للرفع
  Future<void> _insert(
    DatabaseExecutor ex,
    String table,
    Map<String, Object?> values,
  ) async {
    final now = _nowIso();
    await ex.insert(table, {
      ...values,
      'created_at': now,
      'updated_at': now,
      'dirty': 1,
    });
  }

  /// تحديث صفوف وتعليمها للرفع
  Future<void> _update(
    DatabaseExecutor ex,
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> args,
  }) async {
    await ex.update(
      table,
      {...values, 'updated_at': _nowIso(), 'dirty': 1},
      where: where,
      whereArgs: args,
    );
  }

  /// إدراج أو تحديث حسب المفتاح الطبيعي. لا يعلّم الصف dirty إن لم تتغير القيم
  /// (حتى لا نكتب فوق تعديلات الأجهزة الأخرى بلا داعٍ).
  Future<void> _upsertByKey(
    DatabaseExecutor ex,
    String table,
    Map<String, Object?> key,
    Map<String, Object?> values,
  ) async {
    final where = key.keys.map((k) => '$k=?').join(' AND ');
    final existing = await ex.query(
      table,
      where: where,
      whereArgs: key.values.toList(),
      limit: 1,
    );

    if (existing.isEmpty) {
      await _insert(ex, table, {'id': _uuid.v4(), ...key, ...values});
      return;
    }

    final row = existing.first;
    final changed = values.entries.any((e) => row[e.key] != e.value);
    if (!changed) return;
    await _update(ex, table, values, where: 'id=?', args: [row['id']]);
  }

  // ==================== CLASSES ====================

  Future<List<ClassModel>> getClasses() async {
    final db = await _db;
    final rows = await db.query(
      'classes',
      where: 'teacher_id=? AND deleted_at IS NULL',
      whereArgs: [_uid],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => ClassModel.fromJson(_dec('classes', r))).toList();
  }

  Future<ClassModel> createClass({
    required String name,
    String? subject,
    String? academicYear,
  }) async {
    final db = await _db;
    final id = _uuid.v4();
    await _insert(db, 'classes', {
      'id': id,
      'teacher_id': _uid,
      'name': name,
      'subject': subject,
      'academic_year': academicYear,
      'is_archived': 0,
    });
    _changed();
    final row = (await db.query('classes', where: 'id=?', whereArgs: [id])).first;
    return ClassModel.fromJson(_dec('classes', row));
  }

  Future<void> softDeleteClass(String id) async {
    final db = await _db;
    await _update(db, 'classes', {'deleted_at': _nowIso()},
        where: 'id=?', args: [id]);
    _changed();
  }

  // ==================== STUDENTS ====================

  Future<List<StudentModel>> getStudents() async {
    final db = await _db;
    final rows = await db.query(
      'students',
      where: 'teacher_id=? AND deleted_at IS NULL',
      whereArgs: [_uid],
      orderBy: 'full_name',
    );
    return rows.map((r) => StudentModel.fromJson(_dec('students', r))).toList();
  }

  Future<StudentModel> createStudent({
    required String fullName,
    String? studentCode,
    String? parentPhone,
  }) async {
    final db = await _db;
    final id = _uuid.v4();
    await _insert(db, 'students', {
      'id': id,
      'teacher_id': _uid,
      'full_name': fullName,
      'student_code': studentCode,
      'parent_phone': parentPhone,
    });
    _changed();
    final row = (await db.query('students', where: 'id=?', whereArgs: [id])).first;
    return StudentModel.fromJson(_dec('students', row));
  }

  Future<void> softDeleteStudent(String id) async {
    final db = await _db;
    await _update(db, 'students', {'deleted_at': _nowIso()},
        where: 'id=?', args: [id]);
    _changed();
  }

  // ==================== ENROLLMENTS ====================

  /// طلاب الفصل (النشطون وغير المحذوفين) مرتبون بالاسم
  Future<List<StudentModel>> getStudentsInClass(String classId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.* FROM students s
      JOIN enrollments e ON e.student_id = s.id
      WHERE e.class_id = ?
        AND e.is_active = 1
        AND e.deleted_at IS NULL
        AND s.deleted_at IS NULL
      ORDER BY s.full_name
    ''', [classId]);
    return rows.map((r) => StudentModel.fromJson(_dec('students', r))).toList();
  }

  /// يضيف الطالب للفصل، أو يعيد تفعيل تسجيله القديم.
  Future<void> enrollStudent({
    required String classId,
    required String studentId,
  }) async {
    final db = await _db;
    final existing = await db.query(
      'enrollments',
      where: 'class_id=? AND student_id=?',
      whereArgs: [classId, studentId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await _insert(db, 'enrollments', {
        'id': _uuid.v4(),
        'class_id': classId,
        'student_id': studentId,
        'enrollment_date': _dateOnly(DateTime.now()),
        'is_active': 1,
      });
    } else {
      final row = existing.first;
      final alreadyActive = row['is_active'] == 1 && row['deleted_at'] == null;
      if (alreadyActive) return;
      await _update(
        db,
        'enrollments',
        {
          'is_active': 1,
          'left_date': null,
          'deleted_at': null,
          'enrollment_date': _dateOnly(DateTime.now()),
        },
        where: 'id=?',
        args: [row['id']],
      );
    }
    _changed();
  }

  Future<void> unenrollStudent({
    required String classId,
    required String studentId,
  }) async {
    final db = await _db;
    await _update(
      db,
      'enrollments',
      {'is_active': 0, 'left_date': _dateOnly(DateTime.now())},
      where: 'class_id=? AND student_id=?',
      args: [classId, studentId],
    );
    _changed();
  }

  // ==================== ATTENDANCE ====================

  Future<List<AttendanceSessionModel>> getSessionsForClass(
      String classId) async {
    final db = await _db;
    final rows = await db.query(
      'attendance_sessions',
      where: 'class_id=? AND deleted_at IS NULL',
      whereArgs: [classId],
      orderBy: 'date DESC',
    );
    return rows
        .map((r) =>
            AttendanceSessionModel.fromJson(_dec('attendance_sessions', r)))
        .toList();
  }

  Future<AttendanceSessionModel?> findSession({
    required String classId,
    required DateTime date,
    String? period,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'attendance_sessions',
      where:
          'class_id=? AND date=? AND deleted_at IS NULL AND ${period == null ? 'period IS NULL' : 'period=?'}',
      whereArgs: [classId, _dateOnly(date), if (period != null) period],
      orderBy: 'created_at',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AttendanceSessionModel.fromJson(
        _dec('attendance_sessions', rows.first));
  }

  /// يرجع جلسة اليوم إن وُجدت وإلا ينشئها.
  Future<AttendanceSessionModel> getOrCreateSession({
    required String classId,
    required DateTime date,
    String? period,
    String? notes,
  }) async {
    final existing =
        await findSession(classId: classId, date: date, period: period);
    if (existing != null) return existing;

    final db = await _db;
    final id = _uuid.v4();
    await _insert(db, 'attendance_sessions', {
      'id': id,
      'class_id': classId,
      'date': _dateOnly(date),
      'period': period,
      'notes': notes,
    });
    _changed();
    final row = (await db
            .query('attendance_sessions', where: 'id=?', whereArgs: [id]))
        .first;
    return AttendanceSessionModel.fromJson(_dec('attendance_sessions', row));
  }

  Future<List<AttendanceRecordModel>> getRecordsForSession(
      String sessionId) async {
    final db = await _db;
    final rows = await db.query(
      'attendance_records',
      where: 'session_id=? AND deleted_at IS NULL',
      whereArgs: [sessionId],
    );
    return rows
        .map((r) =>
            AttendanceRecordModel.fromJson(_dec('attendance_records', r)))
        .toList();
  }

  Future<void> saveAttendanceRecords({
    required String sessionId,
    required List<({String studentId, String status})> records,
  }) async {
    if (records.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final r in records) {
        await _upsertByKey(
          txn,
          'attendance_records',
          {'session_id': sessionId, 'student_id': r.studentId},
          {'status': r.status, 'deleted_at': null},
        );
      }
    });
    _changed();
  }

  Future<void> updateAttendanceRecord({
    required String recordId,
    required String status,
  }) async {
    final db = await _db;
    await _update(db, 'attendance_records', {'status': status},
        where: 'id=?', args: [recordId]);
    _changed();
  }

  // ==================== ASSESSMENTS & GRADES ====================

  Future<List<AssessmentModel>> getAssessments(String classId) async {
    final db = await _db;
    final rows = await db.query(
      'assessments',
      where: 'class_id=? AND deleted_at IS NULL',
      whereArgs: [classId],
      orderBy: 'created_at',
    );
    return rows
        .map((r) => AssessmentModel.fromJson(_dec('assessments', r)))
        .toList();
  }

  Future<AssessmentModel> createAssessment({
    required String classId,
    required String name,
    String? type,
    required double weight,
    required double maxScore,
    DateTime? date,
  }) async {
    final db = await _db;
    final id = _uuid.v4();
    await _insert(db, 'assessments', {
      'id': id,
      'class_id': classId,
      'name': name,
      'type': type,
      'weight': weight,
      'max_score': maxScore,
      'date': date == null ? null : _dateOnly(date),
      'is_active': 1,
    });
    _changed();
    final row =
        (await db.query('assessments', where: 'id=?', whereArgs: [id])).first;
    return AssessmentModel.fromJson(_dec('assessments', row));
  }

  Future<void> softDeleteAssessment(String id) async {
    final db = await _db;
    await _update(db, 'assessments', {'deleted_at': _nowIso()},
        where: 'id=?', args: [id]);
    _changed();
  }

  Future<List<GradeModel>> getGradesForAssessment(String assessmentId) async {
    return getGradesForAssessments([assessmentId]);
  }

  Future<List<GradeModel>> getGradesForAssessments(
      List<String> assessmentIds) async {
    if (assessmentIds.isEmpty) return [];
    final db = await _db;
    final marks = List.filled(assessmentIds.length, '?').join(',');
    final rows = await db.query(
      'grades',
      where: 'assessment_id IN ($marks) AND deleted_at IS NULL',
      whereArgs: assessmentIds,
    );
    return rows.map((r) => GradeModel.fromJson(_dec('grades', r))).toList();
  }

  Future<void> saveGrades({
    required String assessmentId,
    required List<({String studentId, double? rawScore})> grades,
  }) async {
    if (grades.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      for (final g in grades) {
        await _upsertByKey(
          txn,
          'grades',
          {'assessment_id': assessmentId, 'student_id': g.studentId},
          {'raw_score': g.rawScore, 'deleted_at': null},
        );
      }
    });
    _changed();
  }

  Future<GradeSettingsModel?> getGradeSettings(String classId) async {
    final db = await _db;
    final rows = await db.query(
      'grade_settings',
      where: 'class_id=?',
      whereArgs: [classId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GradeSettingsModel.fromJson(_dec('grade_settings', rows.first));
  }

  Future<void> saveGradeSettings({
    required String classId,
    required List<Map<String, dynamic>> gradingScale,
    required String missingGradePolicy,
  }) async {
    final db = await _db;
    await _upsertByKey(
      db,
      'grade_settings',
      {'class_id': classId},
      {
        'grading_scale': jsonEncode(gradingScale),
        'missing_grade_policy': missingGradePolicy,
      },
    );
    _changed();
  }
}
