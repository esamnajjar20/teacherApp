import 'number_utils.dart';

/// طالب مُستخرج من نص ملصوق أو ملف Excel، جاهز للإضافة.
typedef ImportedStudent = ({
  String fullName,
  String? studentCode,
  String? parentPhone,
});

const _nameHeaders = {
  'الاسم',
  'اسم الطالب',
  'الطالب',
  'اسم',
  'name',
  'full name',
  'fullname',
  'student',
  'student name',
};
const _codeHeaders = {
  'الرقم',
  'رقم الطالب',
  'رقم الهوية',
  'الهوية',
  'رقم',
  'رقم التسجيل',
  'code',
  'id',
  'student code',
  'student id',
};
const _phoneHeaders = {
  'الجوال',
  'جوال',
  'جوال ولي الأمر',
  'رقم الجوال',
  'الهاتف',
  'هاتف',
  'هاتف ولي الأمر',
  'phone',
  'mobile',
  'parent phone',
};

String _norm(String s) => s.trim().toLowerCase();

int _indexIn(List<String> row, Set<String> names) =>
    row.indexWhere((c) => names.contains(_norm(c)));

/// هل الخلية تشبه رقماً/رمزاً (أرقام فقط، مع - و / و مسافات)؟
bool _looksLikeCode(String s) {
  final t = normalizeDigits(s.trim());
  return t.isNotEmpty && RegExp(r'^[0-9][0-9\-/\s]*$').hasMatch(t);
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// يقسم نصاً ملصوقاً إلى صفوف وأعمدة.
/// الفاصل: Tab (النسخ من Excel)، وإلا الفاصلة أو الفاصلة المنقوطة أو «،».
List<List<String>> splitStudentsText(String text) {
  final rows = <List<String>>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    if (raw.trim().isEmpty) continue;
    // لا نقصّ الـ Tab الطرفي حتى لا تنزاح الأعمدة عند فراغ الخلية الأولى
    final line = raw;
    final cells = line.contains('\t')
        ? line.split('\t')
        : line.split(RegExp(r'[,;،]'));
    rows.add(cells.map((c) => c.trim()).toList());
  }
  return rows;
}

/// يحوّل صفوفاً خاماً إلى طلاب.
///
/// - إن كان الصف الأول عناوين معروفة (الاسم / الرقم / الجوال) تُحدَّد الأعمدة
///   بها ويُتجاوز ذلك الصف.
/// - وإلا الترتيب المتوقع: الاسم، الرقم، الجوال. وإن كانت الخلية الأولى رقماً
///   والثانية نصاً يُعدّ الترتيب معكوساً (الرقم أولاً) تلقائياً.
/// - الصفوف بلا اسم تُهمل. الأرقام العربية تُحوَّل إلى لاتينية.
List<ImportedStudent> parseStudentRows(List<List<String>> rows) {
  if (rows.isEmpty) return const [];

  var nameIdx = -1;
  var codeIdx = -1;
  var phoneIdx = -1;
  var start = 0;

  final first = rows.first;
  final headerName = _indexIn(first, _nameHeaders);
  if (headerName >= 0) {
    nameIdx = headerName;
    codeIdx = _indexIn(first, _codeHeaders);
    phoneIdx = _indexIn(first, _phoneHeaders);
    start = 1;
  }

  final out = <ImportedStudent>[];
  for (var i = start; i < rows.length; i++) {
    final row = rows[i];
    String cell(int idx) => (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

    String name;
    String code;
    String phone;
    if (nameIdx >= 0) {
      name = cell(nameIdx);
      code = cell(codeIdx);
      phone = cell(phoneIdx);
    } else {
      final c0 = cell(0);
      final c1 = cell(1);
      final swapped = c1.isNotEmpty && _looksLikeCode(c0) && !_looksLikeCode(c1);
      name = swapped ? c1 : c0;
      code = swapped ? c0 : c1;
      phone = cell(2);
    }

    if (name.isEmpty) continue;
    final normCode = _blankToNull(normalizeDigits(code));
    final normPhone = _blankToNull(normalizeDigits(phone));
    out.add((fullName: name, studentCode: normCode, parentPhone: normPhone));
  }
  return out;
}

/// اختصار: نص ملصوق → طلاب.
List<ImportedStudent> parseStudentsText(String text) =>
    parseStudentRows(splitStudentsText(text));
