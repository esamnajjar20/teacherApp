import os
import re

def file_op(path, transformations):
    """يطبق قائمة تحويلات على ملف ويعيد تقريراً."""
    if not os.path.exists(path):
        print(f"   ❌ الملف غير موجود: {path}")
        return False

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    applied = 0
    skipped = 0

    for old, new, label in transformations:
        if old in content:
            content = content.replace(old, new, 1)
            applied += 1
            print(f"   ✅ {label}")
        else:
            skipped += 1
            print(f"   ⚠️  {label} — لم يُعثر على النمط")

    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"   💾 تم حفظ الملف ({applied} تعديل)")
    return applied > 0

# ============================================================
print("\n" + "=" * 65)
print("🔧 سكربت إصلاح المشاكل الحرجة")
print("=" * 65)

# ============================================================
print("\n📁 [1/4] local_database.dart — جدول sync_failures + version bump")

old_open = '''      return openDatabase(
        p.join(dir, 'teacher_$uid.db'),
        version: 1,
        onCreate: createSchema,
      );'''

new_open = '''      return openDatabase(
        p.join(dir, 'teacher_$uid.db'),
        version: 2,
        onCreate: createSchema,
        onUpgrade: _upgrade,
      );'''

old_create_end = """    await db.execute(
        'CREATE TABLE sync_meta (key TEXT PRIMARY KEY, value TEXT)');
  }"""

new_create_end = """    await db.execute(
        'CREATE TABLE sync_meta (key TEXT PRIMARY KEY, value TEXT)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS sync_failures ('
        'key TEXT PRIMARY KEY, '
        'table_name TEXT NOT NULL, '
        'row_id TEXT NOT NULL, '
        'label TEXT NOT NULL, '
        'message TEXT NOT NULL, '
        'attempts INTEGER NOT NULL, '
        'updated_at TEXT, '
        'next_attempt TEXT NOT NULL)');
    try {
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS uq_students_teacher_code '
          'ON students(teacher_id, student_code) '
          'WHERE student_code IS NOT NULL AND deleted_at IS NULL');
    } catch (e) {
      debugPrint('Could not create unique index on student_code: $e');
    }
  }

  static Future<void> _upgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS sync_failures ('
          'key TEXT PRIMARY KEY, '
          'table_name TEXT NOT NULL, '
          'row_id TEXT NOT NULL, '
          'label TEXT NOT NULL, '
          'message TEXT NOT NULL, '
          'attempts INTEGER NOT NULL, '
          'updated_at TEXT, '
          'next_attempt TEXT NOT NULL)');
      try {
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS uq_students_teacher_code '
            'ON students(teacher_id, student_code) '
            'WHERE student_code IS NOT NULL AND deleted_at IS NULL');
      } catch (e) {
        debugPrint('Could not create unique index on student_code: $e');
      }
    }
  }"""

file_op('lib/shared/local/local_database.dart', [
    (old_open, new_open, 'رفع version إلى 2 + إضافة onUpgrade'),
    (old_create_end, new_create_end, 'إضافة جدول sync_failures + UNIQUE INDEX + method _upgrade'),
])

# ============================================================
print("\n📁 [2/4] sync_helpers.dart — withTimeout + maxPages")

helper_path = 'lib/shared/services/sync_helpers.dart'

with open(helper_path, 'r', encoding='utf-8') as f:
    helper_content = f.read()

# إضافة dart:async
if "import 'dart:async';" not in helper_content:
    helper_content = helper_content.replace(
        "import 'dart:convert';",
        "import 'dart:async';\nimport 'dart:convert';",
        1,
    )
    print("   ✅ إضافة import 'dart:async'")

# استبدال fetchAllPages
old_fetch = '''Future<int> fetchAllPages<T>({
  required Future<List<T>> Function(int offset) fetch,
  required Future<void> Function(List<T> page) onPage,
}) async {
  var offset = 0;
  while (true) {
    final page = await fetch(offset);
    if (page.isEmpty) break;
    await onPage(page);
    offset += page.length;
  }
  return offset;
}'''

new_fetch = '''/// يغلّف أي عملية بـ timeout افتراضي 20 ثانية.
Future<T> withTimeout<T>(
  Future<T> Function() body, [
  Duration duration = const Duration(seconds: 20),
]) {
  return body().timeout(
    duration,
    onTimeout: () => throw TimeoutException('انتهت مهلة الاتصال بالخادم'),
  );
}

Future<int> fetchAllPages<T>({
  required Future<List<T>> Function(int offset) fetch,
  required Future<void> Function(List<T> page) onPage,
  int maxPages = 100,
}) async {
  var offset = 0;
  var pages = 0;
  while (true) {
    if (pages++ >= maxPages) {
      debugPrint('fetchAllPages: stopped at maxPages=$maxPages, offset=$offset');
      break;
    }
    final page = await fetch(offset);
    if (page.isEmpty) break;
    await onPage(page);
    offset += page.length;
  }
  return offset;
}'''

if old_fetch in helper_content:
    helper_content = helper_content.replace(old_fetch, new_fetch, 1)
    print("   ✅ إضافة withTimeout + maxPages إلى fetchAllPages")
else:
    print("   ⚠️  لم يُعثر على fetchAllPages الأصلي")

with open(helper_path, 'w', encoding='utf-8') as f:
    f.write(helper_content)
print("   💾 تم حفظ sync_helpers.dart")

# ============================================================
print("\n📁 [3/4] sync_service.dart — حفظ failures + timeouts")

sync_path = 'lib/shared/services/sync_service.dart'

# 3.1: start() + _initialize + failure persistence methods
old_start = '''  void start() {
    if (_started) return;
    _started = true;
    _periodic = Timer.periodic(const Duration(seconds: 45), (_) => sync());
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) sync();
    });
    _refreshPending();
    sync();
  }'''

new_start = '''  void start() {
    if (_started) return;
    _started = true;
    _initialize();
  }

  Future<void> _initialize() async {
    _failures.clear();
    await _loadFailures();
    _periodic = Timer.periodic(const Duration(seconds: 45), (_) => sync());
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) sync();
    });
    await _refreshPending();
    await sync();
  }

  Future<void> _loadFailures() async {
    try {
      final db = await LocalDatabase.instance.open();
      final rows = await db.query('sync_failures');
      for (final r in rows) {
        final key = r['key'] as String;
        _failures[key] = SyncFailure(
          table: r['table_name'] as String,
          rowId: r['row_id'] as String,
          label: r['label'] as String,
          message: r['message'] as String,
          attempts: r['attempts'] as int,
          updatedAt: r['updated_at'] as String?,
          nextAttempt: DateTime.parse(r['next_attempt'] as String),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveFailure(String key, SyncFailure f) async {
    try {
      final db = await LocalDatabase.instance.open();
      await db.insert(
        'sync_failures',
        {
          'key': key,
          'table_name': f.table,
          'row_id': f.rowId,
          'label': f.label,
          'message': f.message,
          'attempts': f.attempts,
          'updated_at': f.updatedAt,
          'next_attempt': f.nextAttempt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> _removeFailure(String key) async {
    _failures.remove(key);
    try {
      final db = await LocalDatabase.instance.open();
      await db.delete('sync_failures', where: 'key=?', whereArgs: [key]);
    } catch (_) {}
  }

  Future<void> _clearAllFailures() async {
    _failures.clear();
    try {
      final db = await LocalDatabase.instance.open();
      await db.delete('sync_failures');
    } catch (_) {}
  }'''

# 3.2: stop() — لا تمسح _failures
old_stop = '''    _connSub = null;
    _failures.clear();
    status.value = const SyncStatus();
  }'''

new_stop = '''    _connSub = null;
    // لا نمسح _failures — محفوظة في SQLite، وتُعاد عند تسجيل الدخول التالي
    status.value = const SyncStatus();
  }'''

# 3.3: sync() — _clearAllFailures عند force
old_force = 'if (force) _failures.clear();'
new_force = 'if (force) await _clearAllFailures();'

# 3.4: _recordFailure — حفظ في SQLite
old_record = '''    _failures[key] = SyncFailure(
      table: t.name,
      rowId: '${row['id']}',
      label: await _describe(t, row),
      message: pushErrorMessage(e),
      attempts: attempts,
      updatedAt: row['updated_at'] as String?,
      nextAttempt: DateTime.now().add(retryDelay(attempts)),
    );
  }'''

new_record = '''    final failure = SyncFailure(
      table: t.name,
      rowId: '${row['id']}',
      label: await _describe(t, row),
      message: pushErrorMessage(e),
      attempts: attempts,
      updatedAt: row['updated_at'] as String?,
      nextAttempt: DateTime.now().add(retryDelay(attempts)),
    );
    _failures[key] = failure;
    await _saveFailure(key, failure);
  }'''

# 3.5: _pushRows — timeout + معالجة الرد الفارغ
old_push = '''    final res = await supabase
        .from(t.name)
        .upsert(payload, onConflict: t.onConflict)
        .select();

    final byId = <String, Map<String, dynamic>>{
      for (final s in res) s['id'] as String: s,
    };'''

new_push = '''    final res = await withTimeout(() async => await supabase
        .from(t.name)
        .upsert(payload, onConflict: t.onConflict)
        .select());

    if (res.isEmpty && rows.isNotEmpty) {
      for (final r in rows) {
        await _recordFailure(t, r,
            StateError('السيرفر رفض السجل بدون سبب واضح (قد تكون مشكلة صلاحيات)'));
      }
      return;
    }

    final byId = <String, Map<String, dynamic>>{
      for (final s in res) s['id'] as String: s,
    };'''

# 3.6: _pushRows — إزالة failures بشكل دائمي
old_remove = '''    for (final r in rows) {
      _failures.remove(_key(t, r));
    }
  }'''

new_remove = '''    for (final r in rows) {
      await _removeFailure(_key(t, r));
    }
  }'''

# 3.7: _pushTable — إزالة failures من القرص
old_cleanup = '''    final dirtyKeys = all.map((r) => _key(t, r)).toSet();
    _failures.removeWhere((k, v) => v.table == t.name && !dirtyKeys.contains(k));'''

new_cleanup = '''    final dirtyKeys = all.map((r) => _key(t, r)).toSet();
    final toRemove = _failures.entries
        .where((e) => e.value.table == t.name && !dirtyKeys.contains(e.key))
        .map((e) => e.key)
        .toList();
    for (final key in toRemove) {
      await _removeFailure(key);
    }'''

# 3.8: _pushTable — عند تعديل السجل، احذف فشله من القرص
old_edit = '''        if (st.updatedAt != row['updated_at']) {
          _failures.remove(key); // عُدّل بعد الفشل: نعيد المحاولة فوراً
        } else if (now.isBefore(st.nextAttempt)) {'''

new_edit = '''        if (st.updatedAt != row['updated_at']) {
          await _removeFailure(key); // عُدّل بعد الفشل: نعيد المحاولة فوراً
        } else if (now.isBefore(st.nextAttempt)) {'''

# 3.9: _pullTable — timeout
old_pull = '''        return await q
            .order('updated_at', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + _pageSize - 1);'''

new_pull = '''        return await withTimeout(() async => await q
            .order('updated_at', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + _pageSize - 1));'''

# 3.10: _resolveSessionConflict — timeout
old_conflict = 'final server = await q.maybeSingle();'
new_conflict = "final server = await withTimeout(() async => await q.maybeSingle());"

file_op(sync_path, [
    (old_start, new_start, 'تحويل start() إلى _initialize() + دوال حفظ failures'),
    (old_stop, new_stop, 'إيقاف مسح _failures في stop()'),
    (old_force, new_force, 'استخدام _clearAllFailures في sync(force)'),
    (old_record, new_record, 'حفظ failure في SQLite عند التسجيل'),
    (old_push, new_push, 'timeout + معالجة الرد الفارغ في _pushRows'),
    (old_remove, new_remove, 'إزالة failures بشكل دائمي بعد النجاح'),
    (old_cleanup, new_cleanup, 'تنظيف failures من القرص في _pushTable'),
    (old_edit, new_edit, 'حذف failure من القرص عند تعديل السجل'),
    (old_pull, new_pull, 'timeout على السحب في _pullTable'),
    (old_conflict, new_conflict, 'timeout على _resolveSessionConflict'),
])

# ============================================================
print("\n📁 [4/4] database_service.dart — فلترة الفصول + race condition")

db_path = 'lib/shared/services/database_service.dart'

# 4.1: getStudentsInClass — فلترة الفصول المحذوفة
old_query = '''    final rows = await db.rawQuery(\'\'\'
      SELECT s.* FROM students s
      JOIN enrollments e ON e.student_id = s.id
      WHERE e.class_id = ?
        AND e.is_active = 1
        AND e.deleted_at IS NULL
        AND s.deleted_at IS NULL
      ORDER BY s.full_name
    \'\'\', [classId]);'''

new_query = '''    final rows = await db.rawQuery(\'\'\'
      SELECT s.* FROM students s
      JOIN enrollments e ON e.student_id = s.id
      JOIN classes c ON c.id = e.class_id
      WHERE e.class_id = ?
        AND e.is_active = 1
        AND e.deleted_at IS NULL
        AND s.deleted_at IS NULL
        AND c.deleted_at IS NULL
      ORDER BY s.full_name
    \'\'\', [classId]);'''

# 4.2: createStudent — race condition
old_create = '''    final db = await _db;
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
    return StudentModel.fromJson(_dec('students', row));'''

new_create = '''    final db = await _db;
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
    return StudentModel.fromJson(_dec('students', row));'''

# 4.3: updateStudent — race condition
old_update = '''    final db = await _db;
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
    _changed();
  }'''

new_update = '''    final db = await _db;
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
  }'''

# 4.4: getStudentById — إضافة helper
old_get_students = '''    return rows.map((r) => StudentModel.fromJson(_dec('students', r))).toList();
  }

  /// هل رقم الطالب مستخدم لطالب آخر (غير محذوف) عند نفس المعلم؟'''

new_get_students = '''    return rows.map((r) => StudentModel.fromJson(_dec('students', r))).toList();
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

  /// هل رقم الطالب مستخدم لطالب آخر (غير محذوف) عند نفس المعلم؟'''

file_op(db_path, [
    (old_query, new_query, 'فلترة الفصول المحذوفة في getStudentsInClass'),
    (old_create, new_create, 'race condition في createStudent'),
    (old_update, new_update, 'race condition في updateStudent'),
    (old_get_students, new_get_students, 'إضافة getStudentById helper'),
])

# ============================================================
print("\n" + "=" * 65)
print("🎉 اكتمل الإصلاح — لمزيد من الأمان، سأتحقق الآن")
print("=" * 65)

# فحص سريع
print("\n🔍 فحص سريع للتحقق من الإصلاحات:")

checks = [
    ('lib/shared/local/local_database.dart', ['sync_failures', '_upgrade', 'version: 2']),
    ('lib/shared/services/sync_helpers.dart', ['withTimeout', 'maxPages', "import 'dart:async'"]),
    ('lib/shared/services/sync_service.dart', ['_initialize', '_loadFailures', '_saveFailure', '_clearAllFailures', 'withTimeout']),
    ('lib/shared/services/database_service.dart', ['getStudentById', 'isUniqueConstraintError', 'JOIN classes c']),
]

for path, symbols in checks:
    if not os.path.exists(path):
        print(f"   ❌ {path} — غير موجود")
        continue
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    missing = [s for s in symbols if s not in content]
    if missing:
        print(f"   ⚠️  {path}")
        for s in missing:
            print(f"        يفتقد: {s}")
    else:
        print(f"   ✅ {path}")

print("\n" + "=" * 65)
print("🚀 ارفع وابنِ:")
print("=" * 65)
print("""
  git add .
  git commit -m "Fix: Persist sync failures + timeouts + race conditions + class filter"
  git push origin main

  sleep 5
  gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
""")
