import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/supabase_client.dart';
import '../../../../core/utils/auth_actions.dart';
import 'change_password_screen.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../shared/local/local_database.dart';
import '../../../../shared/services/sync_service.dart';

/// شاشة الحساب: بيانات المعلم، حالة المزامنة، تغيير كلمة المرور، حذف الحساب.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _editName() async {
    final current =
        supabase.auth.currentUser?.userMetadata?['full_name']?.toString() ?? '';
    final ctrl = TextEditingController(text: current);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الاسم'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم المعلم'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    if (ok != true || name.isEmpty) return;

    setState(() => _busy = true);
    try {
      await supabase.auth.updateUser(UserAttributes(data: {'full_name': name}));
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        try {
          await supabase.from('profiles').update({'full_name': name}).eq('id', uid);
        } catch (_) {
          // جدول profiles ثانوي؛ الاسم الأساسي محفوظ في بيانات الحساب
        }
      }
      _snack('تم حفظ الاسم');
    } catch (e) {
      _snack(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChangePasswordScreen(),
      ),
    );
    if (changed == true && mounted) {
      _snack('تم تغيير كلمة المرور');
    }
  }

  Future<void> _deleteAccount() async {
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('حذف الحساب نهائياً'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سيُحذف حسابك وكل فصولك وطلابك وحضورك ودرجاتك من الخادم ومن هذا الجهاز، ولا يمكن التراجع.',
              ),
              const SizedBox(height: 12),
              const Text('للتأكيد اكتب كلمة: حذف'),
              TextField(
                controller: confirmCtrl,
                onChanged: (_) => setLocal(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: confirmCtrl.text.trim() == 'حذف'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('حذف نهائياً'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final uid = supabase.auth.currentUser?.id;
    setState(() => _busy = true);
    try {
      await supabase.rpc('delete_my_account');

      await SyncService.instance.stop();
      if (uid != null) await LocalDatabase.instance.deleteForUser(uid);
      try {
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // المستخدم حُذف من الخادم؛ الجلسة المحلية تُمسح على أي حال
      }

      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      _snack(friendlyError(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final name = user?.userMetadata?['full_name']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    (name?.isNotEmpty == true ? name! : (user?.email ?? 'م'))[0]
                        .toUpperCase(),
                  ),
                ),
                title: Text(name?.isNotEmpty == true ? name! : 'معلم'),
                subtitle: Text(user?.email ?? ''),
                trailing: IconButton(
                  tooltip: 'تعديل الاسم',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _editName,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<SyncStatus>(
              valueListenable: SyncService.instance.status,
              builder: (context, st, _) {
                final String title;
                final IconData icon;
                if (st.syncing) {
                  title = 'جارٍ المزامنة...';
                  icon = Icons.sync;
                } else if (st.error != null) {
                  title = 'غير متزامن';
                  icon = Icons.cloud_off;
                } else if (st.pending > 0) {
                  title = '${st.pending} تعديل بانتظار الرفع';
                  icon = Icons.cloud_upload_outlined;
                } else {
                  title = 'كل البيانات متزامنة';
                  icon = Icons.cloud_done_outlined;
                }
                final syncCard = Card(
                  child: ListTile(
                    leading: Icon(icon),
                    title: Text(title),
                    subtitle: Text([
                      if (st.error != null) st.error!,
                      st.lastSync == null
                          ? 'لم تتم مزامنة بعد في هذه الجلسة'
                          : 'آخر مزامنة: ${_fmt(st.lastSync!)}',
                    ].join('\n')),
                    isThreeLine: st.error != null,
                    trailing: TextButton(
                      onPressed: st.syncing
                          ? null
                          : () => SyncService.instance.sync(force: true),
                      child: const Text('مزامنة الآن'),
                    ),
                  ),
                );
                if (st.failures.isEmpty) return syncCard;
                return Column(
                  children: [
                    syncCard,
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سجلات تعذّرت مزامنتها (${st.failures.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'عدّل السجل المذكور أو احذفه ثم اضغط «مزامنة الآن».',
                              style: TextStyle(fontSize: 12),
                            ),
                            const Divider(),
                            for (final f in st.failures.take(20))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('• ${f.label}: ${f.message}'),
                              ),
                            if (st.failures.length > 20)
                              Text('... و${st.failures.length - 20} آخرين'),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('تغيير كلمة المرور'),
                    onTap: _changePassword,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('تسجيل الخروج'),
                    onTap: () => confirmAndSignOut(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('حذف الحساب',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text('حذف نهائي لكل بياناتك'),
                onTap: _deleteAccount,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${AppConstants.appName} • الإصدار ${AppConstants.appVersion}',
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
