import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_client.dart';
import '../../../../core/errors/error_message.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _emailController = TextEditingController(text: widget.initialEmail);
  bool _isLoading = false;
  String? _error;
  String? _info;

  Future<void> _reset() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'أدخل بريدك الإلكتروني');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });
    try {
      await supabase.auth
          .resetPasswordForEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _info = 'تم إرسال رمز إعادة التعيين إلى بريدك');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'أدخل بريدك الإلكتروني وسنرسل لك رمزاً لإعادة تعيين كلمة المرور.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            if (_info != null) ...[
              Text(_info!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _reset,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('إرسال رمز إعادة التعيين'),
            ),
          ],
        ),
      ),
    );
  }
}
