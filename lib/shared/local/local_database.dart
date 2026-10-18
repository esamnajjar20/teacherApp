import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/supabase_client.dart';

enum ColType { text, integer, real, boolean, json }

/// تعريف جدول: نفس أعمدة السيرفر + عمود dirty محلي (تعديل لم يُرفع بعد).
class TableDef {
  final String name;
  final Map<String, ColType> cols;

  /// مفتاح فريد طبيعي (مثل class_id + student_id) لمنع التكرار بين الأجهزة
  final List<String> naturalKey;

  /// أعمدة onConflict عند الرفع للسيرفر
  final String onConflict;

  TableDef(
    this.name,
    this.cols, {
    this.naturalKey = const [],
    this.onConflict = 'id',
  });
}

const _t = ColType.text;
const _ts = <String, ColType>{
  'created_at': ColType.text,
  'updated_at': ColType.text,
};
const _del = <String, ColType>{'deleted_at': ColType.text};

/// الترتيب مهم: الآباء قبل الأبناء (للرفع).
final List<TableDef> kTables = [
  TableDef('classes', {
    'id': _t,
    'teacher_id': _t,
    'name': _t,
    'subject': _t,
    'academic_year': _t,
    'is_archived': ColType.boolean,
    ..._del,
    ..._ts,
  }),
  TableDef('students', {
    'id': _t,
    'teacher_id': _t,
    'full_name': _t,
    'student_code': _t,
    'parent_phone': _t,
    'notes': _t,
    ..._del,
    ..._ts,
  }),
  TableDef(
    'enrollments',
    {
      'id': _t,
      'class_id': _t,
      'student_id': _t,
      'enrollment_date': _t,
      'is_active': ColType.boolean,
      'left_date': _t,
      ..._del,
      ..._ts,
    },
    naturalKey: ['class_id', 'student_id'],
    onConflict: 'class_id,student_id',
  ),
  TableDef('attendance_sessions', {
    'id': _t,
    'class_id': _t,
    'date': _t,
    'period': _t,
    'notes': _t,
    ..._del,
    ..._ts,
  }),
  TableDef(
    'attendance_records',
    {
      'id': _t,
      'session_id': _t,
      'student_id': _t,
      'status': _t,
      'notes': _t,
      ..._del,
      ..._ts,
    },
    naturalKey: ['session_id', 'student_id'],
    onConflict: 'session_id,student_id',
  ),
  TableDef('assessments', {
    'id': _t,
    'class_id': _t,
    'name': _t,
    'type': _t,
    'weight': ColType.real,
    'max_score': ColType.real,
    'date': _t,
    'is_active': ColType.boolean,
    ..._del,
    ..._ts,
  }),
  TableDef(
    'grades',
    {
      'id': _t,
      'assessment_id': _t,
      'student_id': _t,
      'raw_score': ColType.real,
      'notes': _t,
      ..._del,
      ..._ts,
    },
    naturalKey: ['assessment_id', 'student_id'],
    onConflict: 'assessment_id,student_id',
  ),
  TableDef(
    'grade_settings',
    {
      'id': _t,
      'class_id': _t,
      'grading_scale': ColType.json,
      'missing_grade_policy': _t,
      ..._ts,
    },
    naturalKey: ['class_id'],
    onConflict: 'class_id',
  ),
];

TableDef tableDef(String name) => kTables.firstWhere((t) => t.name == name);

/// قاعدة SQLite المحلية — ملف مستقل لكل مستخدم.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Future<Database>? _future;
  String? _userId;

  Future<Database> open() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      return Future.error(StateError('انتهت الجلسة، سجّل الدخول من جديد'));
    }
    if (_future != null && _userId == uid) return _future!;

    final previous = _future;
    _userId = uid;
    _future = () async {
      if (previous != null) {
        try {
          await (await previous).close();
        } catch (_) {}
      }
      final dir = await getDatabasesPath();
      return openDatabase(
        p.join(dir, 'teacher_$uid.db'),
        version: 1,
        onCreate: _create,
      );
    }();
    return _future!;
  }

  Future<void> close() async {
    final f = _future;
    _future = null;
    _userId = null;
    if (f != null) {
      try {
        await (await f).close();
      } catch (_) {}
    }
  }

  static String _sqlType(ColType t) {
    switch (t) {
      case ColType.integer:
      case ColType.boolean:
        return 'INTEGER';
      case ColType.real:
        return 'REAL';
      case ColType.text:
      case ColType.json:
        return 'TEXT';
    }
  }

  Future<void> _create(Database db, int version) async {
    for (final t in kTables) {
      final cols = t.cols.entries
          .map((e) =>
              '${e.key} ${_sqlType(e.value)}${e.key == 'id' ? ' PRIMARY KEY' : ''}')
          .join(', ');
      await db.execute(
        'CREATE TABLE ${t.name} ($cols, dirty INTEGER NOT NULL DEFAULT 0)',
      );
      await db.execute('CREATE INDEX idx_${t.name}_dirty ON ${t.name}(dirty)');
      if (t.naturalKey.isNotEmpty) {
        await db.execute(
          'CREATE UNIQUE INDEX uq_${t.name}_nk ON ${t.name}(${t.naturalKey.join(',')})',
        );
      }
    }
    await db.execute('CREATE INDEX idx_enroll_class ON enrollments(class_id)');
    await db.execute(
        'CREATE INDEX idx_sessions_class_date ON attendance_sessions(class_id, date)');
    await db.execute(
        'CREATE INDEX idx_assess_class ON assessments(class_id)');
    await db.execute(
        'CREATE INDEX idx_grades_assess ON grades(assessment_id)');
    await db.execute(
        'CREATE TABLE sync_meta (key TEXT PRIMARY KEY, value TEXT)');
  }

  Future<String?> getMeta(String key) async {
    final db = await open();
    final r = await db.query('sync_meta',
        where: 'key=?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await open();
    await db.insert('sync_meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// صف SQLite → Map يفهمه `Model.fromJson` (bool / json)
  static Map<String, dynamic> decode(String table, Map<String, Object?> row) {
    final t = tableDef(table);
    final m = <String, dynamic>{};
    for (final e in t.cols.entries) {
      Object? v = row[e.key];
      if (v != null) {
        if (e.value == ColType.boolean) {
          v = v == 1;
        } else if (e.value == ColType.json) {
          v = jsonDecode(v as String);
        }
      }
      m[e.key] = v;
    }
    return m;
  }
}
