import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/core/utils/student_import.dart';

void main() {
  group('parseStudentsText', () {
    test('الاسم والرقم والجوال بفواصل مختلفة', () {
      final r = parseStudentsText('أحمد علي، 1001، 0599000000\nسارة خالد,1002');
      expect(r.length, 2);
      expect(r[0].fullName, 'أحمد علي');
      expect(r[0].studentCode, '1001');
      expect(r[0].parentPhone, '0599000000');
      expect(r[1].fullName, 'سارة خالد');
      expect(r[1].studentCode, '1002');
      expect(r[1].parentPhone, isNull);
    });

    test('اسم فقط', () {
      final r = parseStudentsText('محمد\n\n  \nليلى');
      expect(r.map((s) => s.fullName).toList(), ['محمد', 'ليلى']);
      expect(r.every((s) => s.studentCode == null), isTrue);
    });

    test('النسخ من Excel (Tab)', () {
      final r = parseStudentsText('أحمد\t1001\t0599\nسارة\t1002\t');
      expect(r.length, 2);
      expect(r[1].parentPhone, isNull);
    });

    test('الرقم أولاً يُكتشف تلقائياً', () {
      final r = parseStudentsText('1001, أحمد علي');
      expect(r.single.fullName, 'أحمد علي');
      expect(r.single.studentCode, '1001');
    });

    test('الأرقام العربية تتحول للاتينية', () {
      final r = parseStudentsText('أحمد، ١٠٠١، ٠٥٩٩');
      expect(r.single.studentCode, '1001');
      expect(r.single.parentPhone, '0599');
    });

    test('الصفوف بلا اسم تُهمل', () {
      final r = parseStudentsText(',1001\nأحمد,1002');
      expect(r.length, 1);
      expect(r.single.fullName, 'أحمد');
    });

    test('نص فارغ', () {
      expect(parseStudentsText('  \n \n'), isEmpty);
    });
  });

  group('parseStudentRows', () {
    test('صف العناوين يحدد الأعمدة ويُتجاوز', () {
      final r = parseStudentRows([
        ['الجوال', 'الاسم', 'الرقم'],
        ['0599', 'علي', '٥٠٥'],
        ['', 'منى', ''],
      ]);
      expect(r.length, 2);
      expect(r[0].fullName, 'علي');
      expect(r[0].studentCode, '505');
      expect(r[0].parentPhone, '0599');
      expect(r[1].fullName, 'منى');
      expect(r[1].studentCode, isNull);
    });

    test('بدون عناوين الترتيب: اسم، رقم، جوال', () {
      final r = parseStudentRows([
        ['علي', '7', '059'],
      ]);
      expect(r.single.studentCode, '7');
      expect(r.single.parentPhone, '059');
    });
  });
}
