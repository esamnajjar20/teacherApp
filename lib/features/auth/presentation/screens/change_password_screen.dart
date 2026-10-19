import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_client.dart';
import '../../../../core/errors/error_message.dart';

/// تغيير كلمة المرور للمستخدم المسجّل دخوله.
///
/// لا يطلب الإيميل — يُؤخذ من الجلسة تلقائياً.
/// يتحقق من كلمة المرور القديمة قبل التغيير.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  String? _error;

  /// الإيميل من الجلسة — يُستخدم داخلياً فقط
  String? get _email => supabase.auth.currentUser?.email;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email;
    if (email == null) {
      setState(() => _error = 'انتهت الجلسة، سجّل الدخول من جديد');
      return;
    }

    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmController.text;

    // التحقق
    if (oldPass.isEmpty) {
      setState(() => _error = 'أدخل كلمة المرور الحالية');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'كلمة المرور الجديدة 6 أحرف على الأقل');
      return;
    }
    if (newPass == oldPass) {
      setState(() => _error = 'كلمة المرور الجديدة يجب أن تختلف عن الحالية');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // خطوة 1: تحقق من الكلمة الحالية
      // (نستخدم الإيميل من الجلسة — لا يُدخله المستخدم)
      await supabase.auth.signInWithPassword(
        email: email,
        password: oldPass,
      );

      // خطوة 2: غيّر الكلمة
      await supabase.auth.updateUser(UserAttributes(password: newPass));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.contains('Invalid login credentials')) {
        setState(() => _error = 'كلمة المرور الحالية غير صحيحة');
      } else {
        setState(() => _error = friendlyError(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;

    return Scaffold(
      appBar: AppBar(title: const Text('تغيير كلمة المرور')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.password, size: 64, color: Colors.blue),
            const SizedBox(height: 16),

            // عرض الإيميل للتوضيح فقط (ليس حقلاً للإدخال)
            if (email != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // كلمة المرور الحالية
            TextField(
              controller: _oldPasswordController,
              obscureText: _obscureOld,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الحالية',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureOld
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureOld = !_obscureOld),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // كلمة المرور الجديدة
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                prefixIcon: const Icon(Icons.lock_outline),
                helperText: '6 أحرف على الأقل',
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // التأكيد
            TextField(
              controller: _confirmController,
              obscureText: _obscureNew,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور الجديدة',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ كلمة المرور'),
            ),
          ],
        ),
      ),
    );
  }
}
