import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/supabase_client.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/grade_model.dart';

/// طبقة خدمة البيانات — كل عمليات Supabase تمر من هنا
class DatabaseService {
  final _uuid = const Uuid();

  /// معرّف المعلم الحالي. يرمي خطأً واضحاً بدل null!
  String get _uid {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw StateError('انتهت الجلسة، سجّل الدخول من جديد');
    }
    return id;
  }

  /// الوقت الحالي بصيغة UTC — ضروري لأن أعمدة TIMESTAMPTZ
  /// تفسّر النص بدون منطقة زمنية على أنه UTC (يسبب إزاحة بالساعات).
  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// تاريخ فقط بصيغة yyyy-MM-dd (بدون إزاحة زمنية)
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ==================== CLASSES ====================

  Future<List<ClassModel>> getClasses() async {
    final response = await supabase
        .from('classes')
        .select()
        .eq('teacher_id', _uid)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClassModel> createClass({
    required String name,
    String? subject,
    String? academicYear,
  }) async {
    final row = await supabase
        .from('classes')
        .insert({
          'id': _uuid.v4(),
          'teacher_id': _uid,
          'name': name,
          'subject': subject,
          'academic_year': academicYear,
        })
        .select()
        .single();
    return ClassModel.fromJson(row);
  }

  Future<void> softDeleteClass(String id) async {
    final now = _nowIso();
    await supabase
        .from('classes')
        .update({'deleted_at': now, 'updated_at': now})
        .eq('id', id)
        .eq('teacher_id', _uid);
  }

  // ==================== STUDENTS ====================

  Future<List<StudentModel>> getStudents() async {
    final response = await supabase
        .from('students')
        .select()
        .eq('teacher_id', _uid)
        .isFilter('deleted_at', null)
        .order('full_name');
    return (response as List)
        .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StudentModel> createStudent({
    required String fullName,
    String? studentCode,
    String? parentPhone,
  }) async {
    final row = await supabase
        .from('students')
        .insert({
          'id': _uuid.v4(),
          'teacher_id': _uid,
          'full_name': fullName,
          'student_code': studentCode,
          'parent_phone': parentPhone,
        })
        .select()
        .single();
    return StudentModel.fromJson(row);
  }

  Future<void> softDeleteStudent(String id) async {
    final now = _nowIso();
    await supabase
        .from('students')
        .update({'deleted_at': now, 'updated_at': now})
        .eq('id', id)
        .eq('teacher_id', _uid);
  }

  // ==================== ENROLLMENTS ====================

  /// طلاب الفصل (النشطون وغير المحذوفين) مرتبون بالاسم
  Future<List<StudentModel>> getStudentsInClass(String classId) async {
    final response = await supabase
        .from('enrollments')
        .select('student_id, students(*)')
        .eq('class_id', classId)
        .eq('is_active', true)
        .isFilter('deleted_at', null);

    final students = <StudentModel>[];
    for (final e in response as List) {
      final json = (e as Map<String, dynamic>)['students'];
      if (json == null) continue;
      final student = StudentModel.fromJson(json as Map<String, dynamic>);
      if (student.isDeleted) continue; // الطالب المحذوف لا يظهر
      students.add(student);
    }
    students.sort((a, b) => a.fullName.compareTo(b.fullName));
    return students;
  }

  /// يضيف الطالب للفصل، أو يعيد تفعيل تسجيله القديم.
  /// (القيد UNIQUE(class_id, student_id) يمنع INSERT ثانٍ بعد الإزالة.)
  Future<void> enrollStudent({
    required String classId,
    required String studentId,
  }) async {
    await supabase.from('enrollments').upsert(
      {
        'class_id': classId,
        'student_id': studentId,
        'enrollment_date': _dateOnly(DateTime.now()),
        'is_active': true,
        'left_date': null,
        'deleted_at': null,
        'updated_at': _nowIso(),
      },
      onConflict: 'class_id,student_id',
    );
  }

  Future<void> unenrollStudent({
    required String classId,
    required String studentId,
  }) async {
    await supabase
        .from('enrollments')
        .update({
          'is_active': false,
          'left_date': _dateOnly(DateTime.now()),
          'updated_at': _nowIso(),
        })
        .eq('class_id', classId)
        .eq('student_id', studentId);
  }

  // ==================== ATTENDANCE ====================

  Future<List<AttendanceSessionModel>> getSessionsForClass(
      String classId) async {
    final response = await supabase
        .from('attendance_sessions')
        .select()
        .eq('class_id', classId)
        .isFilter('deleted_at', null)
        .order('date', ascending: false);
    return (response as List)
        .map((e) => AttendanceSessionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceSessionModel?> findSession({
    required String classId,
    required DateTime date,
    String? period,
  }) async {
    var query = supabase
        .from('attendance_sessions')
        .select()
        .eq('class_id', classId)
        .eq('date', _dateOnly(date))
        .isFilter('deleted_at', null);

    query = period == null
        ? query.isFilter('period', null)
        : query.eq('period', period);

    final row = await query.maybeSingle();
    return row == null ? null : AttendanceSessionModel.fromJson(row);
  }

  /// يرجع جلسة اليوم إن وُجدت وإلا ينشئها.
  /// (الفهرس uq_daily_attendance يمنع جلستين لنفس الفصل واليوم.)
  Future<AttendanceSessionModel> getOrCreateSession({
    required String classId,
    required DateTime date,
    String? period,
    String? notes,
  }) async {
    final existing =
        await findSession(classId: classId, date: date, period: period);
    if (existing != null) return existing;

    try {
      final row = await supabase
          .from('attendance_sessions')
          .insert({
            'id': _uuid.v4(),
            'class_id': classId,
            'date': _dateOnly(date),
            'period': period,
            'notes': notes,
          })
          .select()
          .single();
      return AttendanceSessionModel.fromJson(row);
    } on PostgrestException catch (e) {
      // سباق: جلسة أُنشئت للتو من جهاز آخر
      if (e.code == '23505') {
        final again =
            await findSession(classId: classId, date: date, period: period);
        if (again != null) return again;
      }
      rethrow;
    }
  }

  Future<List<AttendanceRecordModel>> getRecordsForSession(
      String sessionId) async {
    final response = await supabase
        .from('attendance_records')
        .select()
        .eq('session_id', sessionId)
        .isFilter('deleted_at', null);
    return (response as List)
        .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAttendanceRecords({
    required String sessionId,
    required List<({String studentId, String status})> records,
  }) async {
    if (records.isEmpty) return;
    final now = _nowIso();

    // لا نرسل id/created_at: عند التعارض يبقى السجل القديم بمعرّفه
    // وتاريخ إنشائه، وعند الإدراج الجديد تُولّدها قاعدة البيانات.
    final rows = records
        .map((r) => {
              'session_id': sessionId,
              'student_id': r.studentId,
              'status': r.status,
              'deleted_at': null,
              'updated_at': now,
            })
        .toList();

    await supabase.from('attendance_records').upsert(
          rows,
          onConflict: 'session_id,student_id',
        );
  }

  Future<void> updateAttendanceRecord({
    required String recordId,
    required String status,
  }) async {
    await supabase.from('attendance_records').update({
      'status': status,
      'updated_at': _nowIso(),
    }).eq('id', recordId);
  }

  // ==================== ASSESSMENTS & GRADES ====================

  Future<List<AssessmentModel>> getAssessments(String classId) async {
    final response = await supabase
        .from('assessments')
        .select()
        .eq('class_id', classId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return (response as List)
        .map((e) => AssessmentModel.fromJson(e as Map<String, dynamic>))
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
    final row = await supabase
        .from('assessments')
        .insert({
          'id': _uuid.v4(),
          'class_id': classId,
          'name': name,
          'type': type,
          'weight': weight,
          'max_score': maxScore,
          'date': date == null ? null : _dateOnly(date),
          'is_active': true,
        })
        .select()
        .single();
    return AssessmentModel.fromJson(row);
  }

  Future<void> softDeleteAssessment(String id) async {
    final now = _nowIso();
    await supabase
        .from('assessments')
        .update({'deleted_at': now, 'updated_at': now}).eq('id', id);
  }

  Future<List<GradeModel>> getGradesForAssessment(String assessmentId) async {
    final response = await supabase
        .from('grades')
        .select()
        .eq('assessment_id', assessmentId)
        .isFilter('deleted_at', null);
    return (response as List)
        .map((e) => GradeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// درجات عدة تقييمات بطلب واحد (بدل طلب لكل تقييم)
  Future<List<GradeModel>> getGradesForAssessments(
      List<String> assessmentIds) async {
    if (assessmentIds.isEmpty) return [];
    final response = await supabase
        .from('grades')
        .select()
        .inFilter('assessment_id', assessmentIds)
        .isFilter('deleted_at', null);
    return (response as List)
        .map((e) => GradeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveGrades({
    required String assessmentId,
    required List<({String studentId, double? rawScore})> grades,
  }) async {
    if (grades.isEmpty) return;
    final now = _nowIso();

    final rows = grades
        .map((g) => {
              'assessment_id': assessmentId,
              'student_id': g.studentId,
              'raw_score': g.rawScore,
              'deleted_at': null,
              'updated_at': now,
            })
        .toList();

    await supabase.from('grades').upsert(
          rows,
          onConflict: 'assessment_id,student_id',
        );
  }

  Future<GradeSettingsModel?> getGradeSettings(String classId) async {
    final response = await supabase
        .from('grade_settings')
        .select()
        .eq('class_id', classId)
        .maybeSingle();
    if (response == null) return null;
    return GradeSettingsModel.fromJson(response);
  }

  Future<void> saveGradeSettings({
    required String classId,
    required List<Map<String, dynamic>> gradingScale,
    required String missingGradePolicy,
  }) async {
    await supabase.from('grade_settings').upsert(
      {
        'class_id': classId,
        'grading_scale': gradingScale,
        'missing_grade_policy': missingGradePolicy,
        'updated_at': _nowIso(),
      },
      onConflict: 'class_id',
    );
  }
}
