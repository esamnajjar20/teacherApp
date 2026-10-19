import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_client.dart';
import '../../core/errors/error_message.dart';
import '../local/local_database.dart';
import 'sync_helpers.dart';

export 'sync_helpers.dart' show SyncFailure;

class SyncStatus {
  final bool syncing;
  final int pending; // عدد التعديلات التي لم تُرفع بعد
  final DateTime? lastSync;
  final String? error;

  /// السجلات التي يفشل رفعها (مع السبب)، لعرضها في شاشة «حسابي»
  final List<SyncFailure> failures;

  const SyncStatus({
    this.syncing = false,
    this.pending = 0,
    this.lastSync,
    this.error,
    this.failures = const [],
  });

  SyncStatus copyWith({
    bool? syncing,
    int? pending,
    DateTime? lastSync,
    String? error,
    List<SyncFailure>? failures,
    bool clearError = false,
  }) {
    return SyncStatus(
      syncing: syncing ?? this.syncing,
      pending: pending ?? this.pending,
      lastSync: lastSync ?? this.lastSync,
      error: clearError ? null : (error ?? this.error),
      failures: failures ?? this.failures,
    );
  }
}

/// مزامنة ثنائية الاتجاه بين SQLite المحلية و Supabase.
///
/// - الرفع: كل صف dirty=1 يُرفع بـ upsert (بدون created_at/updated_at حتى
///   يضع السيرفر وقته هو، فتصل التعديلات لكل الأجهزة بترتيب صحيح).
/// - السحب: تغييرات السيرفر بعد آخر مؤشر (cursor) لكل جدول، مع تداخل 5 ثوانٍ،
///   ويستمر حتى تصل صفحة فارغة (فلا يتأثر بإعداد Max Rows في Supabase).
/// - التعارض: آخر رفع يفوز؛ الصف المعدّل محلياً ولم يُرفع لا يُستبدل عند السحب.
/// - الحذف: soft delete فينتقل مثل أي تعديل.
/// - السجل الذي يفشل رفعه يُعزل ويُعاد بتأخير تصاعدي (دقيقة → 30 دقيقة) بدل
///   إعادته كل 45 ثانية، ويُعرض للمعلم باسمه وسبب الفشل. زر «مزامنة الآن»
///   يتجاوز التأخير، وتعديل السجل يعيد المحاولة فوراً.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _pageSize = 1000;
  static const _pushBatch = 50;
  static const _overlap = Duration(seconds: 5);
  static const _offlineMessage = 'لا يوجد اتصال بالإنترنت';

  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus());

  /// يزداد كلما وصلت بيانات جديدة من السيرفر، لتحديث الشاشات
  final ValueNotifier<int> dataVersion = ValueNotifier(0);

  final Map<String, SyncFailure> _failures = {};

  Timer? _periodic;
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _started = false;
  bool _running = false;
  bool _again = false;

  void start() {
    if (_started) return;
    _started = true;
    _periodic = Timer.periodic(const Duration(seconds: 45), (_) => sync());
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) sync();
    });
    _refreshPending();
    sync();
  }

  Future<void> stop() async {
    _started = false;
    _periodic?.cancel();
    _debounce?.cancel();
    await _connSub?.cancel();
    _periodic = null;
    _debounce = null;
    _connSub = null;
    _failures.clear();
    status.value = const SyncStatus();
  }

  /// يُستدعى بعد أي كتابة محلية
  void notifyLocalChange() {
    _refreshPending();
    if (!_started) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), sync);
  }

  Future<int> _countPending() async {
    final db = await LocalDatabase.instance.open();
    var total = 0;
    for (final t in kTables) {
      total += Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM ${t.name} WHERE dirty=1')) ??
          0;
    }
    return total;
  }

  Future<void> _refreshPending() async {
    try {
      final n = await _countPending();
      status.value = status.value.copyWith(pending: n);
    } catch (_) {}
  }

  /// [force] = true (زر المزامنة اليدوي) يتجاوز فترة الانتظار للسجلات الفاشلة.
  Future<void> sync({bool force = false}) async {
    if (supabase.auth.currentSession == null) return;
    if (force) _failures.clear();
    if (_running) {
      _again = true;
      return;
    }

    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) {
      await _refreshPending();
      status.value = status.value.copyWith(error: _offlineMessage);
      return;
    }

    _running = true;
    status.value = status.value.copyWith(syncing: true);
    String? error;
    var pulledAny = false;

    try {
      do {
        _again = false;
        final failed = await _push();
        if (await _pull()) pulledAny = true;
        if (failed > 0) error = _failureSummary(failed);
      } while (_again);
    } catch (e) {
      error = friendlyError(e);
    } finally {
      _running = false;
      int pending = status.value.pending;
      try {
        pending = await _countPending();
      } catch (_) {}
      status.value = SyncStatus(
        syncing: false,
        pending: pending,
        lastSync: error == null ? DateTime.now() : status.value.lastSync,
        error: error,
        failures: List.unmodifiable(_failures.values),
      );
      if (pulledAny) dataVersion.value++;
    }
  }

  String _failureSummary(int failed) {
    if (_failures.length == 1) {
      final f = _failures.values.first;
      return 'تعذّرت مزامنة ${f.label}: ${f.message}';
    }
    return 'تعذّرت مزامنة $failed سجل، التفاصيل في شاشة «حسابي»';
  }

  // ======================= PUSH =======================

  bool _isFatal(Object e) {
    if (friendlyError(e) == _offlineMessage) return true;
    if (e is AuthException) return true;
    if (e is PostgrestException &&
        (e.code == 'PGRST301' || e.code == '401' || e.code == 'PGRST303')) {
      return true;
    }
    return false;
  }

  /// يرجع عدد السجلات التي فشل رفعها
  Future<int> _push() async {
    var failed = 0;
    for (final t in kTables) {
      failed += await _pushTable(t);
    }
    return failed;
  }

  String _key(TableDef t, Map<String, Object?> row) => '${t.name}|${row['id']}';

  Future<int> _pushTable(TableDef t) async {
    final db = await LocalDatabase.instance.open();
    final all = await db.query(t.name, where: 'dirty=1', orderBy: 'updated_at');
    final now = DateTime.now();
    var failed = 0;

    // نحذف من قائمة الفشل ما لم يعد ينتظر الرفع (تمت تسويته أو حُذف)
    final dirtyKeys = all.map((r) => _key(t, r)).toSet();
    _failures.removeWhere((k, v) => v.table == t.name && !dirtyKeys.contains(k));

    // نستبعد السجلات التي ما زالت في فترة الانتظار بعد فشل سابق
    final dirty = <Map<String, Object?>>[];
    for (final row in all) {
      final key = _key(t, row);
      final st = _failures[key];
      if (st != null) {
        if (st.updatedAt != row['updated_at']) {
          _failures.remove(key); // عُدّل بعد الفشل: نعيد المحاولة فوراً
        } else if (now.isBefore(st.nextAttempt)) {
          failed++;
          continue;
        }
      }
      dirty.add(row);
    }

    for (var i = 0; i < dirty.length; i += _pushBatch) {
      final end = i + _pushBatch > dirty.length ? dirty.length : i + _pushBatch;
      final chunk = dirty.sublist(i, end);
      try {
        await _pushRows(t, chunk);
      } catch (e) {
        if (_isFatal(e)) rethrow;
        // نعزل السجل المسبب للخطأ بالرفع واحداً واحداً
        for (final row in chunk) {
          try {
            await _pushRows(t, [row]);
          } catch (e2) {
            if (_isFatal(e2)) rethrow;
            if (t.name == 'attendance_sessions' &&
                e2 is PostgrestException &&
                e2.code == '23505') {
              try {
                await _resolveSessionConflict(row);
                continue;
              } catch (e3) {
                if (_isFatal(e3)) rethrow;
              }
            }
            failed++;
            await _recordFailure(t, row, e2);
            debugPrint('sync push failed (${t.name}): $e2');
          }
        }
      }
    }
    return failed;
  }

  Future<void> _recordFailure(
      TableDef t, Map<String, Object?> row, Object e) async {
    final key = _key(t, row);
    final attempts = (_failures[key]?.attempts ?? 0) + 1;
    _failures[key] = SyncFailure(
      table: t.name,
      rowId: '${row['id']}',
      label: await _describe(t, row),
      message: pushErrorMessage(e),
      attempts: attempts,
      updatedAt: row['updated_at'] as String?,
      nextAttempt: DateTime.now().add(retryDelay(attempts)),
    );
  }

  Future<String> _studentName(Object? studentId) async {
    final db = await LocalDatabase.instance.open();
    final r = await db.query('students',
        columns: ['full_name'],
        where: 'id=?',
        whereArgs: [studentId],
        limit: 1);
    return r.isEmpty ? 'طالب' : '${r.first['full_name']}';
  }

  /// وصف السجل بلغة المعلم، لعرضه في رسالة الخطأ
  Future<String> _describe(TableDef t, Map<String, Object?> row) async {
    try {
      switch (t.name) {
        case 'classes':
          return 'فصل: ${row['name']}';
        case 'students':
          return 'طالب: ${row['full_name']}';
        case 'enrollments':
          return 'تسجيل ${await _studentName(row['student_id'])} في فصل';
        case 'attendance_sessions':
          return 'جلسة حضور ${row['date']}';
        case 'attendance_records':
          return 'حضور ${await _studentName(row['student_id'])}';
        case 'assessments':
          return 'تقييم: ${row['name']}';
        case 'grades':
          return 'درجة ${await _studentName(row['student_id'])}';
        case 'grade_settings':
          return 'إعدادات الدرجات';
      }
    } catch (_) {}
    return t.name;
  }

  Future<void> _pushRows(TableDef t, List<Map<String, Object?>> rows) async {
    final payload = rows.map((r) => SyncCodec.toServer(t, r)).toList();
    final res = await supabase
        .from(t.name)
        .upsert(payload, onConflict: t.onConflict)
        .select();

    final byId = <String, Map<String, dynamic>>{
      for (final s in res) s['id'] as String: s,
    };

    final db = await LocalDatabase.instance.open();
    await db.transaction((txn) async {
      for (final r in rows) {
        final s = byId[r['id']];
        if (s == null) continue;
        // إن تغيّر الصف محلياً أثناء الرفع يبقى dirty ويُرفع في الدورة التالية
        await txn.update(
          t.name,
          SyncCodec.fromServer(t, s),
          where: 'id=? AND updated_at=?',
          whereArgs: [r['id'], r['updated_at']],
        );
      }
    });
    for (final r in rows) {
      _failures.remove(_key(t, r));
    }
  }

  /// جهازان أنشآ جلسة حضور لنفس الفصل واليوم: ندمج محلياً مع جلسة السيرفر
  Future<void> _resolveSessionConflict(Map<String, Object?> row) async {
    var q = supabase
        .from('attendance_sessions')
        .select()
        .eq('class_id', row['class_id'] as String)
        .eq('date', row['date'] as String)
        .isFilter('deleted_at', null);
    q = row['period'] == null
        ? q.isFilter('period', null)
        : q.eq('period', row['period'] as String);
    final server = await q.maybeSingle();
    if (server == null) throw StateError('session conflict not found');

    final db = await LocalDatabase.instance.open();
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE OR REPLACE attendance_records SET session_id=?, dirty=1 WHERE session_id=?',
        [server['id'], row['id']],
      );
      await txn.delete('attendance_sessions',
          where: 'id=?', whereArgs: [row['id']]);
    });
    await _applyServerRows(tableDef('attendance_sessions'), [server]);
  }

  // ======================= PULL =======================

  /// يرجع true إن تغيّر شيء محلياً
  Future<bool> _pull() async {
    var changed = false;
    for (final t in kTables) {
      if (await _pullTable(t)) changed = true;
    }
    return changed;
  }

  Future<bool> _pullTable(TableDef t) async {
    final metaKey = 'cursor_${t.name}';
    final cursor = await LocalDatabase.instance.getMeta(metaKey);
    final String? since = cursor == null
        ? null
        : DateTime.parse(cursor).subtract(_overlap).toUtc().toIso8601String();

    var maxTs = cursor;
    var changed = false;

    // نكمل حتى صفحة فارغة. الاعتماد على rows.length < _pageSize كان يوقف السحب
    // بصمت إن كان Max Rows في السيرفر أقل من حجم الصفحة، فيتقدم المؤشر وتضيع صفوف.
    await fetchAllPages<Map<String, dynamic>>(
      fetch: (offset) async {
        var q = supabase.from(t.name).select();
        final sinceTs = since;
        if (sinceTs != null) q = q.gt('updated_at', sinceTs);
        return await q
            .order('updated_at', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + _pageSize - 1);
      },
      onPage: (rows) async {
        for (final r in rows) {
          final ts = r['updated_at'] as String?;
          if (ts != null &&
              (maxTs == null ||
                  DateTime.parse(ts).isAfter(DateTime.parse(maxTs!)))) {
            maxTs = ts;
          }
        }
        if (await _applyServerRows(t, rows) > 0) changed = true;
      },
    );

    // المؤشر يتقدم فقط بعد نجاح سحب كل الصفحات
    if (maxTs != null) {
      await LocalDatabase.instance.setMeta(metaKey, maxTs!);
    }
    return changed;
  }

  /// يطبّق صفوف السيرفر محلياً ويرجع عدد الصفوف التي تغيّرت فعلاً
  Future<int> _applyServerRows(
      TableDef t, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    final db = await LocalDatabase.instance.open();
    var changed = 0;

    await db.transaction((txn) async {
      for (final r in rows) {
        final id = r['id'] as String;

        final existing =
            await txn.query(t.name, where: 'id=?', whereArgs: [id], limit: 1);
        if (existing.isNotEmpty) {
          final e = existing.first;
          if (e['dirty'] == 1) continue; // تعديل محلي لم يُرفع: لا نكتب فوقه
          if (e['updated_at'] == r['updated_at']) continue; // لا جديد
        }

        if (t.naturalKey.isNotEmpty) {
          final where = t.naturalKey.map((k) => '$k=?').join(' AND ');
          final args = t.naturalKey.map((k) => r[k]).toList();
          final other = await txn.query(
            t.name,
            where: '$where AND id<>?',
            whereArgs: [...args, id],
            limit: 1,
          );
          if (other.isNotEmpty && other.first['dirty'] == 1) continue;
        }

        await txn.insert(
          t.name,
          SyncCodec.fromServer(t, r),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        changed++;
      }
    });
    return changed;
  }
}
