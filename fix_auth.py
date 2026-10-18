import os

# 1. إنشاء ملف شاشة التسجيل الجديد
screen_dir = 'lib/features/auth/presentation/screens'
os.makedirs(screen_dir, exist_ok=True)
register_path = os.path.join(screen_dir, 'register_screen.dart')

register_code = '''import 'package:flutter/material.dart';
import '../../../../core/constants/supabase_client.dart';
import '../../../../core/errors/error_message.dart';
import '../../../students/presentation/screens/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final response = await supabase.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {'full_name': email.split('@').first},
      );

      if (!mounted) return;

      if (response.session != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الحساب. تحقق من بريدك لتأكيد الحساب.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'الرجاء إدخال البريد';
                      if (!value.contains('@')) return 'بريد غير صالح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'الرجاء إدخال كلمة المرور';
                      if (value.length < 6) return 'كلمة المرور قصيرة جداً';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('إنشاء الحساب'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''
with open(register_path, 'w', encoding='utf-8') as f:
    f.write(register_code)

# 2. تعديل شاشة الدخول
login_path = os.path.join(screen_dir, 'login_screen.dart')
with open(login_path, 'r', encoding='utf-8') as f:
    content = f.read()

# إضافة الاستيراد
if "import 'register_screen.dart';" not in content:
    content = content.replace("import '../../../../core/constants/supabase_client.dart';", "import '../../../../core/constants/supabase_client.dart';\nimport 'register_screen.dart';")

# تغيير الزر ليفتح الشاشة الجديدة بدل استدعاء _signUp
old_button = "OutlinedButton(\n                    onPressed: _isLoading ? null : _signUp,\n                    child: const Text('إنشاء حساب جديد'),\n                  ),"
new_button = """OutlinedButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text('إنشاء حساب جديد'),
                  ),"""

if old_button in content:
    content = content.replace(old_button, new_button)
else:
    # محاولة بديلة إذا اختلفت المسافات
    import re
    content = re.sub(r"OutlinedButton\(\s*onPressed:\s*_isLoading\s*\?\s*null\s*:\s*_signUp,.*?\),", new_button, content, flags=re.DOTALL)

with open(login_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ تم إنشاء شاشة التسجيل وتعديل زر الانتقال بنجاح!")
