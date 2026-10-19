import 'package:flutter/material.dart';

/// بديل لـ `withOpacity` (المهمل في Flutter 3.27+).
///
/// يستخدم `withValues(alpha: ...)` (API الجديد) الذي لا يُصدر تحذيراً.
/// يعمل على Flutter 3.27+ فقط (وهو الإصدار المستخدم في المشروع).
extension SoftColor on Color {
  /// يرجع نفس اللون بشفافية [opacity] (من 0.0 إلى 1.0).
  Color soft(double opacity) =>
      withValues(alpha: opacity.clamp(0.0, 1.0));
}
