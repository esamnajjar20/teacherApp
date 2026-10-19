import 'package:flutter/material.dart';

import '../../shared/services/sync_service.dart';
import '../constants/supabase_client.dart';
import '../errors/error_message.dart';

enum _SignOutChoice { cancel, syncFirst, signOut }

/// تسجيل الخروج بعد تأكيد المعلم، مع تحذير إن كانت هناك تعديلات لم تُرفع.
///
/// التنقل لشاشة الدخول يتم تلقائياً من مستمع onAuthStateChange في main.dart.
/// هذه هي النقطة الوحيدة لتسجيل الخروج في التطبيق.
Future<void> confirmAndSignOut(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);

  while (true) {
    if (!context.mounted) return;
    final pending = SyncService.instance.status.value.pending;

    final choice = await showDialog<_SignOutChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(pending > 0 ? 'تعديلات لم تُرفع بعد' : 'تسجيل الخروج'),
        content: Text(
          pending > 0
              ? 'لديك $pending تعديل لم يُرفع إلى الخادم. ستبقى على هذا الجهاز '
                  'وتُرفع عند تسجيل الدخول بنفس الحساب، لكنها لن تظهر على '
                  'أجهزتك الأخرى قبل ذلك، وتضيع إن حُذف التطبيق قبل الرفع.\n\n'
                  'يُفضَّل المزامنة قبل الخروج.'
              : 'هل أنت متأكد من تسجيل الخروج؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SignOutChoice.cancel),
            child: const Text('إلغاء'),
          ),
          if (pending > 0)
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, _SignOutChoice.syncFirst),
              child: const Text('مزامنة الآن'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SignOutChoice.signOut),
            child: Text(
              pending > 0 ? 'خروج دون رفع' : 'خروج',
              style: TextStyle(color: pending > 0 ? Colors.red : null),
            ),
          ),
        ],
      ),
    );

    if (choice == null || choice == _SignOutChoice.cancel) return;
    if (choice == _SignOutChoice.signOut) break;

    // مزامنة ثم نعيد السؤال إن بقي شيء لم يُرفع
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await SyncService.instance.sync(force: true);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (SyncService.instance.status.value.pending == 0) {
      messenger.showSnackBar(const SnackBar(content: Text('تمت المزامنة')));
      break;
    }
    final err = SyncService.instance.status.value.error;
    if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
  }

  try {
    await supabase.auth.signOut();
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
    );
  }
}
