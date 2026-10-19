import 'package:flutter/material.dart';

import '../../shared/models/student_model.dart';

/// بيانات نموذج الطالب بعد الحفظ.
typedef StudentFormData = ({String fullName, String? code, String? phone});

/// نافذة واحدة لإضافة طالب أو تعديله. [existing] == null يعني إضافة.
/// ترجع null عند الإلغاء.
Future<StudentFormData?> showStudentFormDialog(
  BuildContext context, {
  StudentModel? existing,
}) async {
  final nameController = TextEditingController(text: existing?.fullName);
  final codeController = TextEditingController(text: existing?.studentCode);
  final phoneController = TextEditingController(text: existing?.parentPhone);
  String? nameError;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? 'إضافة طالب جديد' : 'تعديل بيانات الطالب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'اسم الطالب',
                  errorText: nameError,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'رقم الطالب / الهوية'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'جوال ولي الأمر (اختياري)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                setLocal(() => nameError = 'اسم الطالب مطلوب');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );

  final name = nameController.text.trim();
  final code = codeController.text.trim();
  final phone = phoneController.text.trim();

  if (ok != true) return null;
  return (
    fullName: name,
    code: code.isEmpty ? null : code,
    phone: phone.isEmpty ? null : phone,
  );
}
