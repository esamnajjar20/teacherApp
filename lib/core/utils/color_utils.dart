import 'package:flutter/material.dart';

/// بديل لـ `withOpacity` (المهمل في Flutter 3.27+) يعمل على كل الإصدارات
/// ولا يسبّب تحذيرات `deprecated_member_use`.
extension SoftColor on Color {
  /// يرجع نفس اللون بشفافية [opacity] (من 0.0 إلى 1.0).
  Color soft(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}
