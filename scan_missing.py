import os
import re

lib_dir = 'lib'
missing = set()
all_imports = {}

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if not file.endswith('.dart'):
            continue
        filepath = os.path.join(root, file)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        imports = re.findall(r"import\s+'([^']+)'", content)
        imports += re.findall(r'import\s+"([^"]+)"', content)

        for imp in imports:
            if imp.startswith('package:teacher_app/'):
                target = imp.replace('package:teacher_app/', 'lib/')
                if not os.path.exists(target):
                    missing.add(target)
                    all_imports.setdefault(target, []).append(filepath)
            elif not imp.startswith('package:') and not imp.startswith('dart:'):
                base = os.path.dirname(filepath)
                target = os.path.normpath(os.path.join(base, imp))
                if not os.path.exists(target):
                    missing.add(target)
                    all_imports.setdefault(target, []).append(filepath)

print("=" * 60)
print(f"📊 عدد الملفات المفقودة: {len(missing)}")
print("=" * 60)
if missing:
    for m in sorted(missing):
        print(f"\n❌ مفقود: {m}")
        print(f"   مطلوب من:")
        for src in all_imports[m]:
            print(f"     - {src}")
else:
    print("✅ كل الاستيرادات المحلية سليمة! لا توجد ملفات مفقودة.")

# فحص دوال وأعضاء ناقصة في الملفات الموجودة
print("\n" + "=" * 60)
print("🔍 فحص الدوال/الأعضاء الناقصة في الملفات الموجودة")
print("=" * 60)

checks = [
    ('lib/core/utils/grade_calculator.dart', ['defaultScale', 'classResults', 'StudentResult']),
    ('lib/shared/services/database_service.dart', ['updateClass', 'updateStudent', 'updateAssessment', 'getSessionSummaries']),
    ('lib/shared/services/sync_service.dart', ['SyncFailure', 'sync({bool force', 'failureSummary']),
]

for path, symbols in checks:
    if not os.path.exists(path):
        print(f"⚠️  {path} غير موجود أصلاً!")
        continue
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    for sym in symbols:
        if sym not in content:
            print(f"❌ {path} → يفتقد: {sym}")
        else:
            print(f"✅ {path} → يحتوي على: {sym}")
