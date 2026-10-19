import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// يحوّل مصنّف Excel إلى ملف ويشاركه عبر تطبيقات الهاتف.
Future<void> shareExcel(
  Excel excel, {
  required String baseName,
  required String text,
}) async {
  final dir = await getTemporaryDirectory();
  final safeName = baseName
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final fileName =
      '${safeName.isEmpty ? 'file' : safeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
  final path = '${dir.path}${Platform.pathSeparator}$fileName';
  final bytes = excel.encode();
  if (bytes == null) throw StateError('تعذّر إنشاء ملف Excel');
  await File(path).writeAsBytes(bytes);
  await Share.shareXFiles([XFile(path)], text: text);
}
