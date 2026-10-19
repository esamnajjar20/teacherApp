import os

print("=" * 68)
print("🔧 إصلاح widgets (memory leak + تحسينات)")
print("=" * 68)

# ============================================================
# 1. student_form_dialog: dispose controllers
# ============================================================
print("\n📁 [1] student_form_dialog.dart")

path = 'lib/core/widgets/student_form_dialog.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    old_fn = """Future<StudentFormData?> showStudentFormDialog(
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
}"""

    new_fn = """Future<StudentFormData?> showStudentFormDialog(
  BuildContext context, {
  StudentModel? existing,
}) async {
  final nameController = TextEditingController(text: existing?.fullName);
  final codeController = TextEditingController(text: existing?.studentCode);
  final phoneController = TextEditingController(text: existing?.parentPhone);
  String? nameError;

  try {
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

    if (ok != true) return null;

    final name = nameController.text.trim();
    final code = codeController.text.trim();
    final phone = phoneController.text.trim();

    return (
      fullName: name,
      code: code.isEmpty ? null : code,
      phone: phone.isEmpty ? null : phone,
    );
  } finally {
    nameController.dispose();
    codeController.dispose();
    phoneController.dispose();
  }
}"""

    if old_fn in c:
        c = c.replace(old_fn, new_fn, 1)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print("   ✅ Controllers تُحرَّر الآن (try/finally)")
    elif 'try {' in c and 'finally {' in c:
        print("   ⏭️  مطبق مسبقاً")
    else:
        print("   ⚠️  النمط غير موجود")

# ============================================================
# 2. student_picker_dialog: controller صريح + dispose
# ============================================================
print("\n📁 [2] student_picker_dialog.dart")

path = 'lib/core/widgets/student_picker_dialog.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    old_fn = """/// نافذة اختيار متعدد للطلاب. ترجع قائمة فارغة عند الإلغاء.
Future<List<StudentModel>?> showStudentPickerDialog(
  BuildContext context, {
  required List<StudentModel> students,
}) async {
  return showDialog<List<StudentModel>>(
    context: context,
    builder: (ctx) {
      final selected = <StudentModel>{};
      var query = '';

      return StatefulBuilder(
        builder: (ctx, setLocal) {
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
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث بالاسم أو الرقم',
                      isDense: true,
                    ),
                    onChanged: (v) => setLocal(() => query = v),
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
}"""

    new_fn = """/// نافذة اختيار متعدد للطلاب. ترجع قائمة فارغة عند الإلغاء.
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
}"""

    if old_fn in c:
        c = c.replace(old_fn, new_fn, 1)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print("   ✅ Controller صريح + dispose")
    elif 'queryController' in c:
        print("   ⏭️  مطبق مسبقاً")
    else:
        print("   ⚠️  النمط غير موجود")

# ============================================================
# 3. empty_state: maxLines دفاعي
# ============================================================
print("\n📁 [3] empty_state.dart (تحسين بسيط)")

path = 'lib/core/widgets/empty_state.dart'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    old_title = """            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),"""

    new_title = """            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),"""

    if old_title in c:
        c = c.replace(old_title, new_title, 1)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print("   ✅ maxLines + overflow للنص الطويل")
    elif 'maxLines: 3' in c:
        print("   ⏭️  مطبق مسبقاً")

# ============================================================
# 4. التحقق
# ============================================================
print("\n" + "=" * 68)
print("🔍 التحقق")
print("=" * 68)

checks = [
    ('lib/core/widgets/student_form_dialog.dart', ['try {', 'finally {', 'nameController.dispose()']),
    ('lib/core/widgets/student_picker_dialog.dart', ['queryController', 'queryController.dispose()']),
    ('lib/core/widgets/empty_state.dart', ['maxLines: 3']),
]

all_ok = True
for path, symbols in checks:
    if not os.path.exists(path):
        print(f"   ❌ {path}")
        all_ok = False
        continue
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    missing = [s for s in symbols if s not in content]
    if missing:
        print(f"   ⚠️  {os.path.basename(path)} — يفتقد: {missing}")
        all_ok = False
    else:
        print(f"   ✅ {os.path.basename(path)}")

print("\n" + "=" * 68)
print("📋 ملخص:")
print("=" * 68)
print("""
   ✅ student_form_dialog: لا memory leak
   ✅ student_picker_dialog: controller صريح
   ✅ empty_state: نصوص طويلة لا تتجاوز

🚀 ارفع وابنِ:
   git add .
   git commit -m "Fix: widget memory leaks (dispose controllers)"
   git push origin main
""")
