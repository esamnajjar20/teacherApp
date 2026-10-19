import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';

import 'number_utils.dart';
import 'student_import.dart';

const _excelMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// نص الخلية كما يراه المعلم (الأرقام الصحيحة بدون .0).
String _cellText(Data? cell) {
  final v = cell?.value;
  if (v == null) return '';
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) return formatNumber(v.value);
  if (v is TextCellValue) {
    // في بعض إصدارات حزمة excel تكون القيمة String وفي أخرى TextSpan
    final dynamic raw = v.value;
    if (raw is String) return raw;
    try {
      final dynamic t = raw.text;
      if (t is String) return t;
    } catch (_) {}
    return raw.toString();
  }
  return v.toString();
}

/// يقرأ طلاباً من ملف .xlsx (أول ورقة فيها بيانات).
List<ImportedStudent> parseStudentsFromExcel(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  for (final name in excel.tables.keys) {
    final sheet = excel.tables[name];
    if (sheet == null) continue;
    final rows = <List<String>>[];
    for (final r in sheet.rows) {
      final cells = r.map(_cellText).toList();
      if (cells.every((c) => c.trim().isEmpty)) continue;
      rows.add(cells);
    }
    final parsed = parseStudentRows(rows);
    if (parsed.isNotEmpty) return parsed;
  }
  return const [];
}

/// يقرأ طلاباً من ملف CSV (UTF-8).
List<ImportedStudent> parseStudentsFromCsv(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('\uFEFF')) text = text.substring(1); // BOM
  return parseStudentsText(text);
}

/// يفتح منتقي الملفات ويرجع الطلاب المقروءين، أو null إن ألغى المعلم.
/// يرمي [FormatException] برسالة عربية إن كان الملف غير مدعوم أو غير مقروء.
Future<List<ImportedStudent>?> pickStudentsFile() async {
  const group = XTypeGroup(
    label: 'Excel / CSV',
    extensions: ['xlsx', 'csv'],
    mimeTypes: [_excelMime, 'text/csv', 'text/comma-separated-values'],
  );
  final file = await openFile(acceptedTypeGroups: [group]);
  if (file == null) return null;

  final name = file.name.toLowerCase();
  final bytes = await file.readAsBytes();
  try {
    if (name.endsWith('.xlsx')) return parseStudentsFromExcel(bytes);
    if (name.endsWith('.csv')) return parseStudentsFromCsv(bytes);
  } catch (_) {
    throw const FormatException('تعذّرت قراءة الملف، تأكد أنه Excel (.xlsx) سليم');
  }
  throw const FormatException('صيغة الملف غير مدعومة، اختر ملف .xlsx أو .csv');
}
