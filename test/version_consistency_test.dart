import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/core/constants/app_constants.dart';

void main() {
  test('رقم الإصدار في pubspec.yaml يطابق AppConstants.appVersion', () {
    final text = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
        .firstMatch(text);
    expect(m, isNotNull);
    expect(m!.group(1), AppConstants.appVersion,
        reason: 'غيّر الرقم في الموضعين معاً');
  });
}
