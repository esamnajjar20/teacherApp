import os

BASE = '/data/data/com.termux/files/home/storage/downloads'
PREFIX = 'FINAL_'

groups = {
    '01_services.txt': {
        'title': '1️⃣ الخدمات الأساسية (Services) - النهائي',
        'files': [
            'lib/shared/services/database_service.dart',
            'lib/shared/services/sync_service.dart',
            'lib/shared/services/sync_helpers.dart',
        ],
    },
    '02_local_storage.txt': {
        'title': '2️⃣ التخزين المحلي + النماذج - النهائي',
        'files': [
            'lib/shared/local/local_database.dart',
            'lib/shared/models/class_model.dart',
            'lib/shared/models/student_model.dart',
            'lib/shared/models/attendance_model.dart',
            'lib/shared/models/grade_model.dart',
        ],
    },
    '03_auth.txt': {
        'title': '3️⃣ المصادقة (Auth) - النهائي (بدون OTP)',
        'files': [
            'lib/features/auth/presentation/screens/login_screen.dart',
            'lib/features/auth/presentation/screens/register_screen.dart',
            'lib/features/auth/presentation/screens/change_password_screen.dart',
            'lib/features/auth/presentation/screens/profile_screen.dart',
            'lib/features/auth/presentation/screens/splash_screen.dart',
        ],
    },
    '04_core_utils.txt': {
        'title': '4️⃣ الأدوات المساعدة (Utilities) - النهائي',
        'files': [
            'lib/core/utils/grade_calculator.dart',
            'lib/core/utils/attendance_calculator.dart',
            'lib/core/utils/number_utils.dart',
            'lib/core/utils/safe_parse.dart',
            'lib/core/utils/student_import.dart',
            'lib/core/utils/student_file_import.dart',
            'lib/core/utils/auth_actions.dart',
            'lib/core/utils/color_utils.dart',
            'lib/core/utils/excel_share.dart',
        ],
    },
    '05_main_config.txt': {
        'title': '5️⃣ نقطة البداية والإعدادات - النهائي',
        'files': [
            'lib/main.dart',
            'pubspec.yaml',
            'lib/core/constants/supabase_config.dart',
            'lib/core/constants/supabase_client.dart',
            'lib/core/constants/app_constants.dart',
            'lib/core/errors/error_message.dart',
            'lib/core/theme/app_theme.dart',
        ],
    },
    '06_widgets.txt': {
        'title': '6️⃣ الـ Widgets المشتركة - النهائي',
        'files': [
            'lib/core/widgets/confirm_dialog.dart',
            'lib/core/widgets/empty_state.dart',
            'lib/core/widgets/student_form_dialog.dart',
            'lib/core/widgets/student_picker_dialog.dart',
            'lib/core/widgets/sync_refresh_mixin.dart',
        ],
    },
    '07_students.txt': {
        'title': '7️⃣ شاشات الطلاب والفصول - النهائي',
        'files': [
            'lib/features/students/presentation/screens/home_screen.dart',
            'lib/features/students/presentation/screens/classes_screen.dart',
            'lib/features/students/presentation/screens/class_detail_screen.dart',
            'lib/features/students/presentation/screens/students_screen.dart',
            'lib/features/students/presentation/screens/student_detail_screen.dart',
            'lib/features/students/presentation/screens/bulk_students_screen.dart',
        ],
    },
    '08_attendance.txt': {
        'title': '8️⃣ شاشات الحضور - النهائي',
        'files': [
            'lib/features/attendance/presentation/screens/attendance_list_screen.dart',
            'lib/features/attendance/presentation/screens/take_attendance_screen.dart',
            'lib/features/attendance/presentation/screens/attendance_history_screen.dart',
            'lib/features/attendance/presentation/screens/attendance_report_screen.dart',
        ],
    },
    '09_grades_reports_trash.txt': {
        'title': '9️⃣ الدرجات والتقارير والسلة - النهائي',
        'files': [
            'lib/features/grades/presentation/screens/grades_list_screen.dart',
            'lib/features/grades/presentation/screens/assessments_screen.dart',
            'lib/features/grades/presentation/screens/enter_grades_screen.dart',
            'lib/features/grades/presentation/screens/grade_settings_screen.dart',
            'lib/features/grades/presentation/screens/class_results_screen.dart',
            'lib/features/reports/presentation/screens/reports_screen.dart',
            'lib/features/trash/presentation/screens/trash_screen.dart',
        ],
    },
    '10_workflow_sql.txt': {
        'title': '🔟 الـ Workflow + كل Migrations - النهائي',
        'files': [
            '.github/workflows/flutter.yml',
            'supabase/migrations/20261018000001_create_tables.sql',
            'supabase/migrations/20261018000002_create_indexes.sql',
            'supabase/migrations/20261018000003_triggers.sql',
            'supabase/migrations/20261018000004_rls_policies.sql',
            'supabase/migrations/20261020000001_student_code_unique.sql',
            'supabase/migrations/20261021000001_delete_my_account.sql',
        ],
    },
}

print("=" * 68)
print("📚 إنشاء 10 ملفات نهائية")
print("=" * 68)

total_files_found = 0
total_files_missing = 0

for filename, config in groups.items():
    filepath = os.path.join(BASE, PREFIX + filename)
    found = 0
    missing = 0
    missing_list = []

    with open(filepath, 'w', encoding='utf-8') as out:
        out.write("=" * 80 + "\n")
        out.write(config['title'] + "\n")
        out.write("=" * 80 + "\n")
        out.write(f"📅 تاريخ الإنشاء: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        out.write("=" * 80 + "\n\n")

        for f in config['files']:
            if os.path.exists(f):
                out.write(f"\n\n{'─' * 80}\n")
                out.write(f"📄 {f}\n")
                out.write(f"{'─' * 80}\n\n")
                with open(f, 'r', encoding='utf-8') as fh:
                    out.write(fh.read())
                found += 1
                total_files_found += 1
            else:
                out.write(f"\n\n⚠️  الملف مفقود: {f}\n")
                missing += 1
                total_files_missing += 1
                missing_list.append(f)

    size = os.path.getsize(filepath) // 1024
    status = f"✅ {found} ملف"
    if missing:
        status += f" | ⚠️ {missing} مفقود"
    print(f"  {PREFIX}{filename}: {size} KB  ({status})")
    if missing_list:
        for m in missing_list:
            print(f"      ⚠️  مفقود: {m}")

print()
print("=" * 68)
print(f"🎉 المجموع: {total_files_found} ملف موجود، {total_files_missing} مفقود")
print("=" * 68)
print(f"\n📁 الملفات في: {BASE}")
print(f"📤 ارفعها واحداً تلو الآخر (FINAL_01 → FINAL_10)")
