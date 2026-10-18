class AppConstants {
  static const String appName = 'تطبيق المعلمين';
  static const String appVersion = '1.0.0';

  // حالات الحضور
  static const String present = 'present';
  static const String absent = 'absent';
  static const String late = 'late';
  static const String excused = 'excused';

  static const Map<String, String> attendanceStatusLabels = {
    present: 'حاضر',
    absent: 'غائب',
    late: 'متأخر',
    excused: 'بعذر',
  };

  // سياسة الدرجات المفقودة
  static const String missingExclude = 'exclude';
  static const String missingZero = 'zero';
}
