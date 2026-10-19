import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:teacher_app/shared/local/local_database.dart';
import 'package:teacher_app/shared/services/database_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseService svc;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: LocalDatabase.createSchema,
        singleInstance: false,
      ),
    );
    LocalDatabase.instance.useDatabaseForTesting(db);
    svc = DatabaseService(userId: () => 'teacher-1');
  });

  tearDown(() async {
    LocalDatabase.instance.useDatabaseForTesting(null);
    await db.close();
  });

  Future<int> dirtyCount(String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table WHERE dirty=1');
    return rows.first['n'] as int;
  }

  group('الطلاب', () {
    test('رقم الطالب لا يتكرر', () async {
      final a = await svc.createStudent(fullName: 'أحمد', studentCode: '1');
      await expectLater(
        svc.createStudent(fullName: 'سارة', studentCode: '1'),
        throwsA(isA<StateError>()),
      );
      // نفس الطالب يحتفظ برقمه عند التعديل
      await svc.updateStudent(id: a.id, fullName: 'أحمد علي', studentCode: '1');
      expect((await svc.getStudents()).single.fullName, 'أحمد علي');
    });

    test('أي كتابة تعلّم السجل للرفع (dirty)', () async {
      await svc.createStudent(fullName: 'أحمد');
      expect(await dirtyCount('students'), 1);
    });

    test('إضافة دفعة واحدة: مكرر داخل الدفعة، موجود مسبقاً، بلا اسم', () async {
      await svc.createStudent(fullName: 'قديم', studentCode: '1');
      final cls = await svc.createClass(name: 'فصل');

      final r = await svc.createStudentsBulk(
        rows: [
          (fullName: 'جديد', studentCode: '2', parentPhone: null),
          (fullName: 'تكرار', studentCode: '2', parentPhone: null),
          (fullName: 'نفس القديم', studentCode: '1', parentPhone: null),
          (fullName: '', studentCode: '3', parentPhone: null),
          (fullName: 'بلا رقم', studentCode: null, parentPhone: '059'),
        ],
        enrollInClassId: cls.id,
      );

      expect(r.created, 2);
      expect(r.matchedExisting, 1);
      expect(r.skipped, 2);
      expect(r.enrolled, 3);
      expect((await svc.getStudents()).length, 3);
      expect((await svc.getStudentsInClass(cls.id)).length, 3);
    });

    test('إعادة نفس الدفعة لا تنشئ مكرراً', () async {
      final rows = [
        (fullName: 'أ', studentCode: '10', parentPhone: null),
        (fullName: 'ب', studentCode: '11', parentPhone: null),
      ];
      final first = await svc.createStudentsBulk(rows: rows);
      final second = await svc.createStudentsBulk(rows: rows);
      expect(first.created, 2);
      expect(second.created, 0);
      expect(second.matchedExisting, 2);
      expect((await svc.getStudents()).length, 2);
    });
  });

  group('السلة', () {
    test('حذف طالب ثم استعادته', () async {
      final s = await svc.createStudent(fullName: 'أحمد', studentCode: '1');
      await svc.softDeleteStudent(s.id);
      expect(await svc.getStudents(), isEmpty);
      expect((await svc.getDeletedStudents()).single.id, s.id);

      await svc.restoreStudent(s.id);
      expect((await svc.getStudents()).single.id, s.id);
      expect(await svc.getDeletedStudents(), isEmpty);
    });

    test('لا تُستعاد الطالب إن صار رقمه لطالب آخر', () async {
      final a = await svc.createStudent(fullName: 'أ', studentCode: '1');
      await svc.softDeleteStudent(a.id);
      await svc.createStudent(fullName: 'ب', studentCode: '1');
      await expectLater(svc.restoreStudent(a.id), throwsA(isA<StateError>()));
    });

    test('حذف فصل واستعادته', () async {
      final c = await svc.createClass(name: 'فصل');
      await svc.softDeleteClass(c.id);
      expect(await svc.getClasses(), isEmpty);
      expect((await svc.getDeletedClasses()).single.id, c.id);
      await svc.restoreClass(c.id);
      expect((await svc.getClasses()).single.id, c.id);
    });

    test('تقييم محذوف يظهر في السلة فقط إن كان فصله غير محذوف', () async {
      final c = await svc.createClass(name: 'فصل');
      final a = await svc.createAssessment(
          classId: c.id, name: 'اختبار', weight: 20, maxScore: 20);
      await svc.softDeleteAssessment(a.id);
      expect((await svc.getDeletedAssessments()).single.className, 'فصل');
      await svc.restoreAssessment(a.id);
      expect(await svc.getDeletedAssessments(), isEmpty);
      expect((await svc.getAssessments(c.id)).length, 1);
    });
  });

  group('أثر الحذف', () {
    test('عدّاد ما سيختفي عند حذف فصل وطالب', () async {
      final c = await svc.createClass(name: 'فصل');
      final s1 = await svc.createStudent(fullName: 'أ');
      final s2 = await svc.createStudent(fullName: 'ب');
      await svc.enrollStudent(classId: c.id, studentId: s1.id);
      await svc.enrollStudent(classId: c.id, studentId: s2.id);

      final session = await svc.getOrCreateSession(
          classId: c.id, date: DateTime(2026, 10, 1));
      await svc.saveAttendanceRecords(sessionId: session.id, records: [
        (studentId: s1.id, status: 'present'),
        (studentId: s2.id, status: 'absent'),
      ]);
      final a = await svc.createAssessment(
          classId: c.id, name: 'اختبار', weight: 20, maxScore: 20);
      await svc.saveGrades(assessmentId: a.id, grades: [
        (studentId: s1.id, rawScore: 15.0),
        (studentId: s2.id, rawScore: null),
      ]);

      final ci = await svc.classDeletionImpact(c.id);
      expect(ci.students, 2);
      expect(ci.sessions, 1);
      expect(ci.assessments, 1);

      final si = await svc.studentDeletionImpact(s1.id);
      expect(si.classes, 1);
      expect(si.records, 1);
      expect(si.grades, 1); // الدرجة الفارغة لا تُحسب

      final si2 = await svc.studentDeletionImpact(s2.id);
      expect(si2.grades, 0);
    });
  });

  group('سجل الحضور', () {
    test('ملخص الجلسات والحذف', () async {
      final c = await svc.createClass(name: 'فصل');
      final s1 = await svc.createStudent(fullName: 'أ');
      final s2 = await svc.createStudent(fullName: 'ب');
      final s3 = await svc.createStudent(fullName: 'ج');
      for (final s in [s1, s2, s3]) {
        await svc.enrollStudent(classId: c.id, studentId: s.id);
      }

      final d1 = await svc.getOrCreateSession(
          classId: c.id, date: DateTime(2026, 10, 1));
      final d2 = await svc.getOrCreateSession(
          classId: c.id, date: DateTime(2026, 10, 2));
      await svc.saveAttendanceRecords(sessionId: d1.id, records: [
        (studentId: s1.id, status: 'present'),
        (studentId: s2.id, status: 'late'),
        (studentId: s3.id, status: 'excused'),
      ]);
      await svc.saveAttendanceRecords(sessionId: d2.id, records: [
        (studentId: s1.id, status: 'absent'),
      ]);

      var list = await svc.getSessionSummaries(c.id);
      expect(list.length, 2);
      // الأحدث أولاً
      expect(list.first.session.id, d2.id);
      expect(list.first.absent, 1);
      expect(list.last.present, 1);
      expect(list.last.tardy, 1);
      expect(list.last.excused, 1);
      expect(list.last.total, 3);

      await svc.softDeleteSession(d2.id);
      list = await svc.getSessionSummaries(c.id);
      expect(list.single.session.id, d1.id);

      // يمكن تسجيل جلسة جديدة لنفس اليوم بعد الحذف
      final again = await svc.getOrCreateSession(
          classId: c.id, date: DateTime(2026, 10, 2));
      expect(again.id, isNot(d2.id));
    });

    test('حفظ الحضور مرتين لا يكرر السجلات', () async {
      final c = await svc.createClass(name: 'فصل');
      final s = await svc.createStudent(fullName: 'أ');
      final session = await svc.getOrCreateSession(
          classId: c.id, date: DateTime(2026, 10, 1));
      await svc.saveAttendanceRecords(sessionId: session.id, records: [
        (studentId: s.id, status: 'present'),
      ]);
      await svc.saveAttendanceRecords(sessionId: session.id, records: [
        (studentId: s.id, status: 'absent'),
      ]);
      final records = await svc.getRecordsForSession(session.id);
      expect(records.length, 1);
      expect(records.single.status, 'absent');
    });
  });

  group('تعديل التقييم', () {
    test('يحدّث الحقول ويوقف الاحتساب', () async {
      final c = await svc.createClass(name: 'فصل');
      final a = await svc.createAssessment(
          classId: c.id, name: 'قديم', weight: 20, maxScore: 20);
      await svc.updateAssessment(
        id: a.id,
        name: 'جديد',
        type: 'quiz',
        weight: 30,
        maxScore: 50,
        date: DateTime(2026, 10, 5),
        isActive: false,
      );
      final got = (await svc.getAssessments(c.id)).single;
      expect(got.name, 'جديد');
      expect(got.type, 'quiz');
      expect(got.weight, 30);
      expect(got.maxScore, 50);
      expect(got.isActive, isFalse);
      expect(got.date, DateTime(2026, 10, 5));
    });

    test('لا يُسمح بتصغير العظمى تحت أعلى درجة مُدخلة', () async {
      final c = await svc.createClass(name: 'فصل');
      final s = await svc.createStudent(fullName: 'أ');
      final a = await svc.createAssessment(
          classId: c.id, name: 'اختبار', weight: 20, maxScore: 20);
      await svc.saveGrades(assessmentId: a.id, grades: [
        (studentId: s.id, rawScore: 18.0),
      ]);

      await expectLater(
        svc.updateAssessment(
            id: a.id,
            name: 'اختبار',
            weight: 20,
            maxScore: 10,
            isActive: true),
        throwsA(isA<StateError>()),
      );
      // تكبير العظمى مسموح
      await svc.updateAssessment(
          id: a.id, name: 'اختبار', weight: 20, maxScore: 25, isActive: true);
      expect((await svc.getAssessments(c.id)).single.maxScore, 25);
    });
  });
}
