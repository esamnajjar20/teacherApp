import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_client.dart';
import '../../core/errors/error_message.dart';
import '../local/local_database.dart';

class SyncStatus {
  final bool syncing;
  final int pending; // عدد التعديلات التي لم تُرفع بعد
  final DateTime? lastSync;
  final String? error;

  const SyncStatus({
    this.syncing = false,
    this.pending = 0,
    this.lastSync,
    this.error,
  });

  SyncStatus copyWith({
    bool? syncing,
    int? pending,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
  }) {
    return SyncStatus(
      syncing: syncing ?? this.syncing,
      pending: pending ?? this.pending,
      lastSync: lastSync ?? this.lastSync,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// مزامنة ثنائية الاتجاه بين SQLite المحلية و Supabase.
///
/// - الرفع: كل صف dirty=1 يُرفع بـ upsert (بدون created_at/updated_at حتى
///   يضع السيرفر وقته هو، فتصل التعديلات لكل الأجهزة بترتيب صحيح).
/// - السحب: تغييرات السيرفر بعد آخر مؤشر (cursor) لكل جدول، مع تداخل 5 ثوانٍ.
/// - التعارض: آخر رفع يفوز؛ الصف المعدّل محلياً ولم يُرفع لا يُستبدل عند السحب.
/// - الحذف: soft delete فينتقل مثل أي تعديل.
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

  Future<void> sync() async {
    if (supabase.auth.currentSession == null) return;
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
        if (failed > 0) error = 'تعذّرت مزامنة $failed سجل، ستُعاد المحاولة';
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
      );
      if (pulledAny) dataVersion.value++;
    }
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

  Future<int> _pushTable(TableDef t) async {
    final db = await LocalDatabase.instance.open();
    final dirty = await db.query(t.name, where: 'dirty=1', orderBy: 'updated_at');
    var failed = 0;

    for (var i = 0; i < dirty.length; i += _pushBatch) {
      final chunk = dirty.sublist(i, math.min(i + _pushBatch, dirty.length));
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
            debugPrint('sync push failed (${t.name}): $e2');
          }
        }
      }
    }
    return failed;
  }

  Future<void> _pushRows(TableDef t, List<Map<String, Object?>> rows) async {
    final payload = rows.map((r) => _toServer(t, r)).toList();
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
          _fromServer(t, s),
          where: 'id=? AND updated_at=?',
          whereArgs: [r['id'], r['updated_at']],
        );
      }
    });
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

  Map<String, dynamic> _toServer(TableDef t, Map<String, Object?> row) {
    final m = <String, dynamic>{};
    for (final e in t.cols.entries) {
      // الأوقات يضعها السيرفر
      if (e.key == 'created_at' || e.key == 'updated_at') continue;
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

  Map<String, Object?> _fromServer(TableDef t, Map<String, dynamic> r) {
    final m = <String, Object?>{};
    for (final e in t.cols.entries) {
      Object? v = r[e.key];
      if (v != null) {
        if (e.value == ColType.boolean) {
          v = (v == true) ? 1 : 0;
        } else if (e.value == ColType.json) {
          v = jsonEncode(v);
        }
      }
      m[e.key] = v;
    }
    m['dirty'] = 0;
    return m;
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
    String? since;
    if (cursor != null) {
      since = DateTime.parse(cursor).subtract(_overlap).toUtc().toIso8601String();
    }

    var offset = 0;
    var maxTs = cursor;
    var changed = false;

    while (true) {
      var q = supabase.from(t.name).select();
      if (since != null) q = q.gt('updated_at', since);
      final rows = await q
          .order('updated_at', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + _pageSize - 1);

      for (final r in rows) {
        final ts = r['updated_at'] as String?;
        if (ts != null &&
            (maxTs == null ||
                DateTime.parse(ts).isAfter(DateTime.parse(maxTs)))) {
          maxTs = ts;
        }
      }

      if (await _applyServerRows(t, rows) > 0) changed = true;

      if (rows.length < _pageSize) break;
      offset += _pageSize;
    }

    if (maxTs != null) {
      await LocalDatabase.instance.setMeta(metaKey, maxTs);
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
          _fromServer(t, r),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        changed++;
      }
    });
    return changed;
  }
}
