import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_app/shared/local/local_database.dart';
import 'package:teacher_app/shared/services/sync_helpers.dart';

void main() {
  group('fetchAllPages', () {
    final data = List<int>.generate(25, (i) => i);

    test('يجمع كل الصفوف حتى لو السيرفر يقتطع الصفحة (Max Rows أقل)', () async {
      // السيرفر لا يعيد أكثر من 10 صفوف مهما كان المطلوب
      final seen = <int>[];
      final total = await fetchAllPages<int>(
        fetch: (offset) async => data.skip(offset).take(10).toList(),
        onPage: (page) async => seen.addAll(page),
      );
      expect(total, 25);
      expect(seen, data);
    });

    test('نتيجة فارغة من البداية', () async {
      var pages = 0;
      final total = await fetchAllPages<int>(
        fetch: (offset) async => <int>[],
        onPage: (page) async => pages++,
      );
      expect(total, 0);
      expect(pages, 0);
    });

    test('خطأ أثناء السحب يصل للمستدعي', () async {
      await expectLater(
        fetchAllPages<int>(
          fetch: (offset) async => throw StateError('boom'),
          onPage: (page) async {},
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('retryDelay', () {
    test('تأخير تصاعدي بحد أقصى 30 دقيقة', () {
      expect(retryDelay(0), const Duration(seconds: 60));
      expect(retryDelay(1), const Duration(seconds: 60));
      expect(retryDelay(2), const Duration(seconds: 120));
      expect(retryDelay(3), const Duration(seconds: 240));
      expect(retryDelay(6), const Duration(minutes: 30));
      expect(retryDelay(50), const Duration(minutes: 30));
    });
  });

  group('SyncCodec', () {
    test('toServer: بدون أوقات ولا dirty، والبولياني حقيقي', () {
      final m = SyncCodec.toServer(tableDef('classes'), {
        'id': '1',
        'teacher_id': 't',
        'name': 'فصل',
        'subject': null,
        'academic_year': '2026-2027',
        'is_archived': 1,
        'deleted_at': null,
        'created_at': 'x',
        'updated_at': 'y',
        'dirty': 1,
      });
      expect(m['is_archived'], true);
      expect(m['name'], 'فصل');
      expect(m.containsKey('created_at'), isFalse);
      expect(m.containsKey('updated_at'), isFalse);
      expect(m.containsKey('dirty'), isFalse);
    });

    test('JSON يذهب ويعود', () {
      final t = tableDef('grade_settings');
      final server = SyncCodec.toServer(t, {
        'id': '1',
        'class_id': 'c',
        'grading_scale': '[{"min":90,"grade":"A"}]',
        'missing_grade_policy': 'zero',
        'created_at': 'x',
        'updated_at': 'y',
      });
      expect(server['grading_scale'], isA<List>());

      final local = SyncCodec.fromServer(t, {
        ...server,
        'created_at': 'x',
        'updated_at': 'y',
      });
      expect(local['grading_scale'], isA<String>());
      expect(local['dirty'], 0);
    });

    test('fromServer: boolean → 0/1', () {
      final local = SyncCodec.fromServer(tableDef('assessments'), {
        'id': '1',
        'class_id': 'c',
        'name': 'n',
        'type': null,
        'weight': 10,
        'max_score': 20,
        'date': null,
        'is_active': false,
        'deleted_at': null,
        'created_at': 'x',
        'updated_at': 'y',
      });
      expect(local['is_active'], 0);
    });
  });

  group('pushErrorMessage', () {
    test('رقم طالب مكرر', () {
      final msg = pushErrorMessage(PostgrestException(
        message:
            'duplicate key value violates unique constraint "uq_students_teacher_code"',
        code: '23505',
      ));
      expect(msg, contains('رقم الطالب'));
    });

    test('قيد CHECK', () {
      final msg =
          pushErrorMessage(PostgrestException(message: 'x', code: '23514'));
      expect(msg, contains('رفضها الخادم'));
    });

    test('خطأ عام', () {
      expect(pushErrorMessage(StateError('مخصص')), 'مخصص');
    });
  });
}
