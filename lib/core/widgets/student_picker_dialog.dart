import 'package:flutter/material.dart';

import '../../shared/models/student_model.dart';

/// بحث داخل قائمة الطلاب (اسم / رقم / جوال).
bool studentMatchesQuery(StudentModel s, String query) {
  if (query.trim().isEmpty) return true;
  final q = query.trim().toLowerCase();
  return s.fullName.toLowerCase().contains(q) ||
      (s.studentCode?.toLowerCase().contains(q) ?? false) ||
      (s.parentPhone?.toLowerCase().contains(q) ?? false);
}

/// نافذة اختيار متعدد للطلاب. ترجع قائمة فارغة عند الإلغاء.
Future<List<StudentModel>?> showStudentPickerDialog(
  BuildContext context, {
  required List<StudentModel> students,
}) async {
  final queryController = TextEditingController();

  try {
    return await showDialog<List<StudentModel>>(
      context: context,
      builder: (ctx) {
        final selected = <StudentModel>{};

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final query = queryController.text;
            final visible =
                students.where((s) => studentMatchesQuery(s, query)).toList();
            return AlertDialog(
              title: const Text('اختر الطلاب'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: queryController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'ابحث بالاسم أو الرقم',
                        isDense: true,
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('لا توجد نتائج'))
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (ctx, i) {
                                final s = visible[i];
                                return CheckboxListTile(
                                  title: Text(s.fullName),
                                  subtitle: s.studentCode != null
                                      ? Text('الرقم: ${s.studentCode}')
                                      : null,
                                  value: selected.contains(s),
                                  onChanged: (v) {
                                    setLocal(() {
                                      if (v == true) {
                                        selected.add(s);
                                      } else {
                                        selected.remove(s);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, <StudentModel>[]),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selected.toList()),
                  child: Text('إضافة ${selected.length}'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    queryController.dispose();
  }
}
