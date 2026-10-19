import 'package:flutter/widgets.dart';

import '../../shared/services/sync_service.dart';

/// يجعل الشاشة تُحدّث بياناتها بصمت عند وصول تغييرات من السيرفر.
///
/// بدل إعادة بناء الشاشة كلها (فيضيع نص البحث وموضع التمرير)، تُعيد الشاشة
/// قراءة بياناتها فقط عبر [reloadSilently] دون مؤشر تحميل.
mixin SyncRefreshMixin<T extends StatefulWidget> on State<T> {
  /// أعد قراءة البيانات دون إظهار مؤشر تحميل أو مسح حالة الواجهة.
  Future<void> reloadSilently();

  @override
  void initState() {
    super.initState();
    SyncService.instance.dataVersion.addListener(_onSyncedData);
  }

  @override
  void dispose() {
    SyncService.instance.dataVersion.removeListener(_onSyncedData);
    super.dispose();
  }

  void _onSyncedData() {
    if (mounted) reloadSilently();
  }
}
