import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_client.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../students/presentation/screens/home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  /// أرسل رمزاً جديداً فور فتح الشاشة (مثل الدخول بحساب لم يُؤكَّد بريده)
  final bool sendCodeOnOpen;

  const OtpScreen({super.key, required this.email, this.sendCodeOnOpen = false});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _cooldownSeconds = 60;

  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  String? _info;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.sendCodeOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resend();
      });
    } else {
      // الرمز أُرسل للتو عند التسجيل، فنبدأ العدّ التنازلي مباشرة
      _startCooldown(notify: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown({bool notify = true}) {
    _timer?.cancel();
    if (notify) {
      setState(() => _cooldown = _cooldownSeconds);
    } else {
      _cooldown = _cooldownSeconds;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _error = null;
      _info = null;
    });
    try {
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);
      if (!mounted) return;
      setState(() => _info = 'تم إرسال رمز جديد إلى بريدك');
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verify() async {
    final code = normalizeDigits(_otpController.text.trim());
    if (code.length < 6) {
      setState(() => _error = 'الرجاء إدخال الرمز المكوّن من 6 أرقام');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    try {
      await supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup, // مهم جداً: النوع هو signup
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
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
      appBar: AppBar(title: const Text('تأكيد الحساب')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى:\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
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
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('تأكيد الرمز'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: (_isResending || _cooldown > 0) ? null : _resend,
              child: _isResending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_cooldown > 0
                      ? 'إعادة إرسال الرمز بعد $_cooldown ثانية'
                      : 'لم يصلك الرمز؟ أعد الإرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
