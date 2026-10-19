import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/supabase_client.dart';
import '../../core/utils/number_utils.dart';
import '../local/local_database.dart';
import '../models/attendance_model.dart';
import '../models/class_model.dart';
import '../models/grade_model.dart';
import '../models/student_model.dart';
import 'sync_service.dart';

/// ملخص جلسة حضور (لقائمة سجل الحضور).
class SessionSummary {
  final AttendanceSessionModel session;
  final int present;
  final int absent;
  final int tardy;
  final int excused;

  const SessionSummary({
    required this.session,
    required this.present,
    required this.absent,
    required this.tardy,
    required this.excused,
  });

  int get total => present + absent + tardy + excused;
}

/// نتيجة إضافة طلاب دفعة واحدة.
class BulkStudentsResult {
  /// طلاب جدد أُنشئوا
  final int created;

  /// صفوف طابق رقمها طالباً موجوداً فاستُخدم بدل إنشاء مكرر
  final int matchedExisting;

  /// صفوف تُجوهلت (اسم فارغ أو رقم مكرر داخل نفس الدفعة)
  final int skipped;

  /// عدد من سُجّلوا في الفصل (إن طُلب التسجيل)
  final int enrolled;

  const BulkStudentsResult({
    required this.created,
    required this.matchedExisting,
    required this.skipped,
    required this.enrolled,
  });
}

/// طبقة البيانات (Offline-First).
///
/// كل القراءة والكتابة تتم على قاعدة SQLite المحلية فقط، فتعمل بدون إنترنت.
/// كل تعديل يُعلَّم dirty=1 ثم يرفعه [SyncService] للسيرفر عند توفر الاتصال.
class DatabaseService {
  /// [userId] للاختبارات فقط؛ في التطبيق يؤخذ المعرّف من جلسة Supabase.
  DatabaseService({String Function()? userId}) : _userIdProvider = userId;

  final String Function()? _userIdProvider;
  final _uuid = const Uuid();

  Future<Database> get _db => LocalDatabase.instance.open();

  /// معرّف المعلم الحالي (من الجلسة المحفوظة، يعمل بدون إنترنت)
  String get _uid {
    final provider = _userIdProvider;
    if (provider != null) return provider();
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

  Future<void> updateClass({
    required String id,
    required String name,
    String? subject,
    String? academicYear,
  }) async {
    final db = await _db;
    await _update(
      db,
      'classes',
      {'name': name, 'subject': subject, 'academic_year': academicYear},
      where: 'id=?',
      args: [id],
    );
    _changed();
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

  Future<StudentModel?> getStudentById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'students',
      where: 'id=? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StudentModel.fromJson(_dec('students', rows.first));
  }

  /// هل رقم الطالب مستخدم لطالب آخر (غير محذوف) عند نفس المعلم؟
  Future<bool> studentCodeExists(String code, {String? excludeId}) async {
    final db = await _db;
    final rows = await db.query(
      'students',
      columns: ['id'],
      where:
          'teacher_id=? AND student_code=? AND deleted_at IS NULL${excludeId == null ? '' : ' AND id<>?'}',
      whereArgs: [_uid, code, if (excludeId != null) excludeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<StudentModel> createStudent({
    required String fullName,
    String? studentCode,
    String? parentPhone,
  }) async {
    if (studentCode != null && await studentCodeExists(studentCode)) {
      throw StateError('رقم الطالب "$studentCode" مستخدم لطالب آخر');
    }
    final db = await _db;
    final id = _uuid.v4();
    try {
      await _insert(db, 'students', {
        'id': id,
        'teacher_id': _uid,
        'full_name': fullName,
        'student_code': studentCode,
        'parent_phone': parentPhone,
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw StateError('رقم الطالب "$studentCode" مستخدم لطالب آخر');
      }
      rethrow;
    }
    _changed();
    final row = (await db.query('students', where: 'id=?', whereArgs: [id])).first;
    return StudentModel.fromJson(_dec('students', row));
  }

  Future<void> updateStudent({
    required String id,
    required String fullName,
    String? studentCode,
    String? parentPhone,
  }) async {
    if (studentCode != null &&
        await studentCodeExists(studentCode, excludeId: id)) {
      throw StateError('رقم الطالب "$studentCode" مستخدم لطالب آخر');
    }
    final db = await _db;
    try {
      await _update(
        db,
        'students',
        {
          'full_name': fullName,
          'student_code': studentCode,
          'parent_phone': parentPhone,
        },
        where: 'id=?',
        args: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw StateError('رقم الطالب "$studentCode" مستخدم لطالب آخر');
      }
      rethrow;
    }
    _changed();
  }

  Future<void> softDeleteStudent(String id) async {
    final db = await _db;
    await _update(db, 'students', {'deleted_at': _nowIso()},
        where: 'id=?', args: [id]);
    _changed();
  }

  // ==================== STUDENT DETAIL ====================

  /// الفصول التي الطالب مسجَّل فيها حالياً
  Future<List<ClassModel>> getClassesOfStudent(String studentId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT c.* FROM classes c
      JOIN enrollments e ON e.class_id = c.id
      WHERE e.student_id = ?
        AND e.is_active = 1
        AND e.deleted_at IS NULL
        AND c.deleted_at IS NULL
        AND c.teacher_id = ?
      ORDER BY c.name
    ''', [studentId, _uid]);
    return rows.map((r) => ClassModel.fromJson(_dec('classes', r))).toList();
  }

  /// سجلات حضور طالب في فصل (كل الفترات)
  Future<List<AttendanceRecordModel>> getAttendanceRecordsForStudent({
    required String studentId,
    required String classId,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT r.* FROM attendance_records r
      JOIN attendance_sessions s ON s.id = r.session_id
      WHERE r.student_id = ?
        AND s.class_id = ?
        AND r.deleted_at IS NULL
        AND s.deleted_at IS NULL
    ''', [studentId, classId]);
    return rows
        .map((r) =>
            AttendanceRecordModel.fromJson(_dec('attendance_records', r)))
        .toList();
  }

  // ==================== ENROLLMENTS ====================

  /// طلاب الفصل (النشطون وغير المحذوفين) مرتبون بالاسم
  Future<List<StudentModel>> getStudentsInClass(String classId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.* FROM students s
      JOIN enrollments e ON e.student_id = s.id
      JOIN classes c ON c.id = e.class_id
      WHERE e.class_id = ?
        AND e.is_active = 1
        AND e.deleted_at IS NULL
        AND s.deleted_at IS NULL
        AND c.deleted_at IS NULL
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
    final changed = await _enrollIn(db, classId, studentId);
    if (changed) _changed();
  }

  /// يرجع true إن تغيّر شيء (تسجيل جديد أو إعادة تفعيل).
  Future<bool> _enrollIn(
    DatabaseExecutor ex,
    String classId,
    String studentId,
  ) async {
    final existing = await ex.query(
      'enrollments',
      where: 'class_id=? AND student_id=?',
      whereArgs: [classId, studentId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await _insert(ex, 'enrollments', {
        'id': _uuid.v4(),
        'class_id': classId,
        'student_id': studentId,
        'enrollment_date': _dateOnly(DateTime.now()),
        'is_active': 1,
      });
      return true;
    }

    final row = existing.first;
    final alreadyActive = row['is_active'] == 1 && row['deleted_at'] == null;
    if (alreadyActive) return false;
    await _update(
      ex,
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
    return true;
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

  /// جلسات الفصل بين تاريخين (شاملين) مرتبة من الأقدم للأحدث.
  Future<List<AttendanceSessionModel>> getSessionsInRange({
    required String classId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'attendance_sessions',
      where: 'class_id=? AND deleted_at IS NULL AND date>=? AND date<=?',
      whereArgs: [classId, _dateOnly(from), _dateOnly(to)],
      orderBy: 'date, period, created_at',
    );
    return rows
        .map((r) =>
            AttendanceSessionModel.fromJson(_dec('attendance_sessions', r)))
        .toList();
  }

  /// سجلات الحضور لمجموعة جلسات (على دفعات لتفادي حد متغيرات SQLite).
  Future<List<AttendanceRecordModel>> getRecordsForSessions(
      List<String> sessionIds) async {
    if (sessionIds.isEmpty) return [];
    final db = await _db;
    final result = <AttendanceRecordModel>[];
    const chunk = 500;
    for (var i = 0; i < sessionIds.length; i += chunk) {
      final part = sessionIds.sublist(
          i, i + chunk > sessionIds.length ? sessionIds.length : i + chunk);
      final marks = List.filled(part.length, '?').join(',');
      final rows = await db.query(
        'attendance_records',
        where: 'session_id IN ($marks) AND deleted_at IS NULL',
        whereArgs: part,
      );
      result.addAll(rows
          .map((r) =>
              AttendanceRecordModel.fromJson(_dec('attendance_records', r))));
    }
    return result;
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

  // ==================== BULK STUDENTS ====================

  /// إضافة طلاب دفعة واحدة (من نص ملصوق أو ملف Excel).
  ///
  /// - الصف بلا اسم يُتجاهل.
  /// - الصف الذي رقمه يطابق طالباً موجوداً لا يُنشأ مكرراً، بل يُستخدم الطالب
  ///   الموجود (ويُسجَّل في الفصل إن طُلب).
  /// - تكرار الرقم داخل نفس الدفعة يُتجاهل بعد أول ظهور.
  /// كل شيء في معاملة واحدة، فإما أن ينجح كله أو لا يُحفظ شيء.
  Future<BulkStudentsResult> createStudentsBulk({
    required List<({String fullName, String? studentCode, String? parentPhone})>
        rows,
    String? enrollInClassId,
  }) async {
    final db = await _db;
    final uid = _uid;
    var created = 0;
    var matched = 0;
    var skipped = 0;
    var enrolled = 0;
    final seenCodes = <String>{};

    await db.transaction((txn) async {
      for (final r in rows) {
        final name = r.fullName.trim();
        final code = (r.studentCode == null || r.studentCode!.trim().isEmpty)
            ? null
            : r.studentCode!.trim();
        final phone = (r.parentPhone == null || r.parentPhone!.trim().isEmpty)
            ? null
            : r.parentPhone!.trim();

        if (name.isEmpty) {
          skipped++;
          continue;
        }

        String studentId;
        if (code != null) {
          if (!seenCodes.add(code)) {
            skipped++;
            continue;
          }
          final owner = await txn.query(
            'students',
            columns: ['id'],
            where: 'teacher_id=? AND student_code=? AND deleted_at IS NULL',
            whereArgs: [uid, code],
            limit: 1,
          );
          if (owner.isNotEmpty) {
            studentId = owner.first['id'] as String;
            matched++;
          } else {
            studentId = _uuid.v4();
            await _insert(txn, 'students', {
              'id': studentId,
              'teacher_id': uid,
              'full_name': name,
              'student_code': code,
              'parent_phone': phone,
            });
            created++;
          }
        } else {
          studentId = _uuid.v4();
          await _insert(txn, 'students', {
            'id': studentId,
            'teacher_id': uid,
            'full_name': name,
            'student_code': null,
            'parent_phone': phone,
          });
          created++;
        }

        if (enrollInClassId != null) {
          if (await _enrollIn(txn, enrollInClassId, studentId)) enrolled++;
        }
      }
    });

    if (created > 0 || enrolled > 0) _changed();
    return BulkStudentsResult(
      created: created,
      matchedExisting: matched,
      skipped: skipped,
      enrolled: enrolled,
    );
  }

  // ==================== DELETE IMPACT ====================

  Future<int> _count(String sql, List<Object?> args) async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  /// ما الذي سيختفي عند حذف فصل (لتحذير المعلم قبل الحذف).
  Future<({int students, int sessions, int assessments})> classDeletionImpact(
      String classId) async {
    final students = await _count('''
      SELECT COUNT(*) FROM enrollments e
      JOIN students s ON s.id = e.student_id
      WHERE e.class_id = ? AND e.is_active = 1
        AND e.deleted_at IS NULL AND s.deleted_at IS NULL
    ''', [classId]);
    final sessions = await _count(
        'SELECT COUNT(*) FROM attendance_sessions WHERE class_id=? AND deleted_at IS NULL',
        [classId]);
    final assessments = await _count(
        'SELECT COUNT(*) FROM assessments WHERE class_id=? AND deleted_at IS NULL',
        [classId]);
    return (students: students, sessions: sessions, assessments: assessments);
  }

  /// ما الذي سيختفي عند حذف طالب.
  Future<({int classes, int records, int grades})> studentDeletionImpact(
      String studentId) async {
    final classes = await _count('''
      SELECT COUNT(*) FROM enrollments e
      JOIN classes c ON c.id = e.class_id
      WHERE e.student_id = ? AND e.is_active = 1
        AND e.deleted_at IS NULL AND c.deleted_at IS NULL
    ''', [studentId]);
    final records = await _count('''
      SELECT COUNT(*) FROM attendance_records r
      JOIN attendance_sessions s ON s.id = r.session_id
      WHERE r.student_id = ? AND r.deleted_at IS NULL AND s.deleted_at IS NULL
    ''', [studentId]);
    final grades = await _count('''
      SELECT COUNT(*) FROM grades g
      JOIN assessments a ON a.id = g.assessment_id
      WHERE g.student_id = ? AND g.deleted_at IS NULL
        AND g.raw_score IS NOT NULL AND a.deleted_at IS NULL
    ''', [studentId]);
    return (classes: classes, records: records, grades: grades);
  }

  // ==================== TRASH (RESTORE) ====================

  Future<List<ClassModel>> getDeletedClasses() async {
    final db = await _db;
    final rows = await db.query(
      'classes',
      where: 'teacher_id=? AND deleted_at IS NOT NULL',
      whereArgs: [_uid],
      orderBy: 'deleted_at DESC',
    );
    return rows.map((r) => ClassModel.fromJson(_dec('classes', r))).toList();
  }

  Future<List<StudentModel>> getDeletedStudents() async {
    final db = await _db;
    final rows = await db.query(
      'students',
      where: 'teacher_id=? AND deleted_at IS NOT NULL',
      whereArgs: [_uid],
      orderBy: 'deleted_at DESC',
    );
    return rows.map((r) => StudentModel.fromJson(_dec('students', r))).toList();
  }

  /// التقييمات المحذوفة لفصول غير محذوفة (مع اسم الفصل).
  Future<List<({AssessmentModel assessment, String className})>>
      getDeletedAssessments() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT a.*, c.name AS class_name FROM assessments a
      JOIN classes c ON c.id = a.class_id
      WHERE a.deleted_at IS NOT NULL
        AND c.deleted_at IS NULL
        AND c.teacher_id = ?
      ORDER BY a.deleted_at DESC
    ''', [_uid]);
    return rows
        .map((r) => (
              assessment: AssessmentModel.fromJson(_dec('assessments', r)),
              className: '${r['class_name']}',
            ))
        .toList();
  }

  Future<void> restoreClass(String id) async {
    final db = await _db;
    await _update(db, 'classes', {'deleted_at': null},
        where: 'id=?', args: [id]);
    _changed();
  }

  Future<void> restoreStudent(String id) async {
    final db = await _db;
    final row = (await db.query('students',
            columns: ['student_code'], where: 'id=?', whereArgs: [id], limit: 1))
        .firstOrNull;
    final code = row?['student_code'] as String?;
    if (code != null && await studentCodeExists(code, excludeId: id)) {
      throw StateError(
          'لا يمكن الاستعادة: رقم الطالب "$code" مستخدم الآن لطالب آخر');
    }
    await _update(db, 'students', {'deleted_at': null},
        where: 'id=?', args: [id]);
    _changed();
  }

  Future<void> restoreAssessment(String id) async {
    final db = await _db;
    await _update(db, 'assessments', {'deleted_at': null},
        where: 'id=?', args: [id]);
    _changed();
  }

  // ==================== ATTENDANCE HISTORY ====================

  /// جلسات الفصل (الأحدث أولاً) مع عدد كل حالة، لعرض سجل الحضور.
  Future<List<SessionSummary>> getSessionSummaries(String classId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.*,
        COALESCE(SUM(CASE WHEN r.status = 'present' THEN 1 ELSE 0 END), 0) AS present_count,
        COALESCE(SUM(CASE WHEN r.status = 'absent' THEN 1 ELSE 0 END), 0) AS absent_count,
        COALESCE(SUM(CASE WHEN r.status = 'late' THEN 1 ELSE 0 END), 0) AS late_count,
        COALESCE(SUM(CASE WHEN r.status = 'excused' THEN 1 ELSE 0 END), 0) AS excused_count
      FROM attendance_sessions s
      LEFT JOIN attendance_records r
        ON r.session_id = s.id AND r.deleted_at IS NULL
      WHERE s.class_id = ? AND s.deleted_at IS NULL
      GROUP BY s.id
      ORDER BY s.date DESC, s.created_at DESC
    ''', [classId]);
    return rows
        .map((r) => SessionSummary(
              session:
                  AttendanceSessionModel.fromJson(_dec('attendance_sessions', r)),
              present: (r['present_count'] as int?) ?? 0,
              absent: (r['absent_count'] as int?) ?? 0,
              tardy: (r['late_count'] as int?) ?? 0,
              excused: (r['excused_count'] as int?) ?? 0,
            ))
        .toList();
  }

  /// حذف جلسة حضور (soft delete). سجلاتها تختفي من كل التقارير تبعاً لها.
  Future<void> softDeleteSession(String id) async {
    final db = await _db;
    await _update(db, 'attendance_sessions', {'deleted_at': _nowIso()},
        where: 'id=?', args: [id]);
    _changed();
  }

  // ==================== ASSESSMENT EDIT ====================

  /// تعديل تقييم. يرفض تصغير الدرجة العظمى تحت أعلى درجة مُدخلة فعلاً،
  /// حتى لا تصبح درجات الطلاب أكبر من العظمى.
  Future<void> updateAssessment({
    required String id,
    required String name,
    String? type,
    required double weight,
    required double maxScore,
    DateTime? date,
    required bool isActive,
  }) async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT MAX(raw_score) AS m FROM grades
      WHERE assessment_id = ? AND deleted_at IS NULL AND raw_score IS NOT NULL
    ''', [id]);
    final highest = r.isEmpty ? null : r.first['m'];
    if (highest is num && highest > maxScore) {
      throw StateError(
          'توجد درجة (${formatNumber(highest)}) أكبر من الدرجة العظمى الجديدة، عدّل الدرجات أولاً');
    }
    await _update(
      db,
      'assessments',
      {
        'name': name,
        'type': type,
        'weight': weight,
        'max_score': maxScore,
        'date': date == null ? null : _dateOnly(date),
        'is_active': isActive ? 1 : 0,
      },
      where: 'id=?',
      args: [id],
    );
    _changed();
  }
}
