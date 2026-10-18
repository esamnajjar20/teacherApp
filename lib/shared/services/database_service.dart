import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../main.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/grade_model.dart';

/// طبقة خدمة البيانات — كل عمليات Supabase تمر من هنا
class DatabaseService {
  final _uuid = const Uuid();

  String? get _userId => supabase.auth.currentUser?.id;

  // ==================== CLASSES ====================

  Future<List<ClassModel>> getClasses() async {
    final response = await supabase
        .from('classes')
        .select()
        .eq('teacher_id', _userId!)
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
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final data = {
      'id': id,
      'teacher_id': _userId,
      'name': name,
      'subject': subject,
      'academic_year': academicYear,
      'created_at': now,
      'updated_at': now,
    };
    await supabase.from('classes').insert(data);
    return ClassModel.fromJson(data);
  }

  Future<void> softDeleteClass(String id) async {
    await supabase.from('classes').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ==================== STUDENTS ====================

  Future<List<StudentModel>> getStudents() async {
    final response = await supabase
        .from('students')
        .select()
        .eq('teacher_id', _userId!)
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
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final data = {
      'id': id,
      'teacher_id': _userId,
      'full_name': fullName,
      'student_code': studentCode,
      'parent_phone': parentPhone,
      'created_at': now,
      'updated_at': now,
    };
    await supabase.from('students').insert(data);
    return StudentModel.fromJson(data);
  }

  Future<void> softDeleteStudent(String id) async {
    await supabase.from('students').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ==================== ENROLLMENTS ====================

  Future<List<StudentModel>> getStudentsInClass(String classId) async {
    final response = await supabase
        .from('enrollments')
        .select('student_id, students(*)')
        .eq('class_id', classId)
        .eq('is_active', true)
        .isFilter('deleted_at', null);

    return (response as List).map((e) {
      final studentJson = e['students'] as Map<String, dynamic>;
      return StudentModel.fromJson(studentJson);
    }).toList();
  }

  Future<void> enrollStudent({
    required String classId,
    required String studentId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await supabase.from('enrollments').insert({
      'id': id,
      'class_id': classId,
      'student_id': studentId,
      'enrollment_date': DateTime.now().toIso8601String().split('T').first,
      'is_active': true,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> unenrollStudent({
    required String classId,
    required String studentId,
  }) async {
    await supabase
        .from('enrollments')
        .update({
          'is_active': false,
          'left_date': DateTime.now().toIso8601String().split('T').first,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('class_id', classId)
        .eq('student_id', studentId);
  }

  // ==================== ATTENDANCE ====================

  Future<List<AttendanceSessionModel>> getSessionsForClass(String classId) async {
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

  Future<AttendanceSessionModel> createSession({
    required String classId,
    required DateTime date,
    String? period,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final data = {
      'id': id,
      'class_id': classId,
      'date': date.toIso8601String().split('T').first,
      'period': period,
      'notes': notes,
      'created_at': now,
      'updated_at': now,
    };
    await supabase.from('attendance_sessions').insert(data);
    return AttendanceSessionModel.fromJson(data);
  }

  Future<List<AttendanceRecordModel>> getRecordsForSession(String sessionId) async {
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
    final now = DateTime.now().toIso8601String();
    final rows = records.map((r) {
      return {
        'id': _uuid.v4(),
        'session_id': sessionId,
        'student_id': r.studentId,
        'status': r.status,
        'created_at': now,
        'updated_at': now,
      };
    }).toList();

    // Upsert: إذا السجل موجود يُحدَّث، وإلا يُضاف
    await supabase.from('attendance_records').upsert(
      rows,
      onConflict: 'session_id, student_id',
    );
  }

  Future<void> updateAttendanceRecord({
    required String recordId,
    required String status,
  }) async {
    await supabase.from('attendance_records').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
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
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final data = {
      'id': id,
      'class_id': classId,
      'name': name,
      'type': type,
      'weight': weight,
      'max_score': maxScore,
      'date': date?.toIso8601String().split('T').first,
      'is_active': true,
      'created_at': now,
      'updated_at': now,
    };
    await supabase.from('assessments').insert(data);
    return AssessmentModel.fromJson(data);
  }

  Future<void> softDeleteAssessment(String id) async {
    await supabase.from('assessments').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
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

  Future<void> saveGrades({
    required String assessmentId,
    required List<({String studentId, double? rawScore})> grades,
  }) async {
    final now = DateTime.now().toIso8601String();
    final rows = grades.map((g) {
      return {
        'id': _uuid.v4(),
        'assessment_id': assessmentId,
        'student_id': g.studentId,
        'raw_score': g.rawScore,
        'created_at': now,
        'updated_at': now,
      };
    }).toList();

    await supabase.from('grades').upsert(
      rows,
      onConflict: 'assessment_id, student_id',
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
    final existing = await getGradeSettings(classId);
    final now = DateTime.now().toIso8601String();

    if (existing != null) {
      await supabase.from('grade_settings').update({
        'grading_scale': gradingScale,
        'missing_grade_policy': missingGradePolicy,
        'updated_at': now,
      }).eq('id', existing.id);
    } else {
      await supabase.from('grade_settings').insert({
        'id': _uuid.v4(),
        'class_id': classId,
        'grading_scale': gradingScale,
        'missing_grade_policy': missingGradePolicy,
        'created_at': now,
        'updated_at': now,
      });
    }
  }
}
