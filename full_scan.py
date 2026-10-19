import os
import re

lib_dir = 'lib'

print("=" * 70)
print("🔍 الفحص الشامل للمشروع")
print("=" * 70)

# ================================================================
# 1. قراءة pubspec.yaml للحزم والأصول
# ================================================================
declared_packages = set()
declared_assets = set()

if os.path.exists('pubspec.yaml'):
    with open('pubspec.yaml', 'r', encoding='utf-8') as f:
        pubspec = f.read()

    # استخراج أسماء الحزم (تحت dependencies و dev_dependencies)
    in_deps = False
    for line in pubspec.split('\n'):
        stripped = line.strip()
        if stripped.startswith('dependencies:') or stripped.startswith('dev_dependencies:'):
            in_deps = True
            continue
        if stripped.startswith('#') or not stripped:
            continue
        if in_deps:
            if line.startswith(' ') or line.startswith('\t'):
                match = re.match(r'^\s+([a-z_][a-z0-9_]*):', line)
                if match:
                    declared_packages.add(match.group(1))
            else:
                in_deps = False

    # استخراج assets
    for line in pubspec.split('\n'):
        s = line.strip()
        if s.startswith('- assets/'):
            declared_assets.add(s.replace('- ', '').rstrip('/'))

print(f"\n📦 حزم dependencies/dev_dependencies: {len(declared_packages)}")
print(f"📁 أصول assets مذكورة: {len(declared_assets)}")

# ================================================================
# 2. فحص الاستيرادات في كل ملفات Dart
# ================================================================
missing_files = {}       # ملفات محلية مفقودة
missing_packages = {}    # حزم مذكورة بالكود لكن غير موجودة بـ pubspec
missing_teacher_app = {} # مسارات package:teacher_app مفقودة
all_imported_packages = set()

dart_files_count = 0

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if not file.endswith('.dart'):
            continue
        dart_files_count += 1
        filepath = os.path.join(root, file)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # جمع كل الاستيرادات
        imports = re.findall(r"^\s*import\s+'([^']+)'", content, re.MULTILINE)
        imports += re.findall(r'^\s*import\s+"([^"]+)"', content, re.MULTILINE)

        for imp in imports:
            if imp.startswith('package:teacher_app/'):
                target = imp.replace('package:teacher_app/', 'lib/')
                if not os.path.exists(target):
                    missing_teacher_app.setdefault(target, []).append(filepath)

            elif imp.startswith('package:'):
                pkg = imp.split('/')[0].replace('package:', '')
                all_imported_packages.add(pkg)
                # تجاهل حزم flutter/dart الأساسية
                if pkg not in ('flutter', 'flutter_test', 'flutter_localizations', 'flutter_web_plugins', 'integration_test'):
                    if pkg not in declared_packages:
                        missing_packages.setdefault(pkg, []).append(filepath)

            elif not imp.startswith('dart:'):
                # استيراد نسبي
                base = os.path.dirname(filepath)
                target = os.path.normpath(os.path.join(base, imp))
                if not os.path.exists(target):
                    missing_files.setdefault(target, []).append(filepath)

print(f"\n📄 عدد ملفات Dart: {dart_files_count}")
print(f"📦 عدد الحزم المستخدمة بالكود: {len(all_imported_packages)}")

# ================================================================
# 3. فحص الأصول (assets)
# ================================================================
missing_assets = []
for asset in declared_assets:
    if not os.path.exists(asset):
        missing_assets.append(asset)

# ================================================================
# 4. عرض النتائج
# ================================================================
def print_section(title, items, prefix="❌"):
    if items:
        print(f"\n{'=' * 70}")
        print(f"{prefix} {title}: {len(items)}")
        print('=' * 70)
        for key, sources in items.items():
            print(f"\n{prefix} {key}")
            for src in sources[:3]:
                print(f"     ← {src}")
            if len(sources) > 3:
                print(f"     ... ومطلوب من {len(sources) - 3} ملف آخر")
    else:
        print(f"\n✅ {title}: لا شيء (سليم)")

print_section("ملفات محلية مفقودة", missing_files)
print_section("حزم غير موجودة في pubspec.yaml", missing_packages)
print_section("ملفات package:teacher_app مفقودة", missing_teacher_app)

if missing_assets:
    print(f"\n{'=' * 70}")
    print(f"❌ أصول assets مفقودة: {len(missing_assets)}")
    print('=' * 70)
    for a in missing_assets:
        print(f"   • {a}")
else:
    print(f"\n✅ أصول assets: سليمة")

# ================================================================
# 5. فحص أعضاء/دوال ناقصة في الملفات الحساسة
# ================================================================
print(f"\n{'=' * 70}")
print("🔍 فحص الدوال/الأعضاء في الملفات الحساسة")
print('=' * 70)

critical_checks = [
    ('lib/core/utils/grade_calculator.dart', [
        'defaultScale', 'classResults', 'StudentResult',
    ]),
    ('lib/core/utils/attendance_calculator.dart', [
        'AttendanceStats', 'AttendanceCalculator', 'warningThreshold',
    ]),
    ('lib/core/utils/excel_share.dart', ['shareExcel']),
    ('lib/core/widgets/student_picker_dialog.dart', [
        'showStudentPickerDialog', 'studentMatchesQuery',
    ]),
    ('lib/shared/services/database_service.dart', [
        'updateClass', 'updateStudent', 'updateAssessment',
        'getSessionSummaries', 'classDeletionImpact', 'studentDeletionImpact',
        'createStudentsBulk', 'getDeletedClasses', 'restoreClass',
    ]),
    ('lib/shared/services/sync_service.dart', [
        'SyncFailure', 'sync({bool force', 'failureSummary', 'retryDelay',
    ]),
    ('lib/shared/local/local_database.dart', [
        'deleteForUser', 'useDatabaseForTesting', 'createSchema',
    ]),
]

all_ok = True
for path, symbols in critical_checks:
    if not os.path.exists(path):
        print(f"⚠️  {path} غير موجود!")
        all_ok = False
        continue
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    missing_syms = [s for s in symbols if s not in content]
    if missing_syms:
        print(f"❌ {path}")
        for s in missing_syms:
            print(f"     يفتقد: {s}")
        all_ok = False
    else:
        print(f"✅ {path}")

# ================================================================
# 6. الملخص النهائي
# ================================================================
print("\n" + "=" * 70)
total_issues = len(missing_files) + len(missing_packages) + len(missing_teacher_app) + len(missing_assets) + (0 if all_ok else 1)
if total_issues == 0:
    print("🎉 كل شيء سليم! المشروع جاهز للبناء.")
else:
    print(f"⚠️  إجمالي المشاكل: {total_issues}")
    print("   أرسل هذا الناتج لتحديد ما يجب إصلاحه.")
print("=" * 70)
