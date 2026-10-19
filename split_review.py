import os

BASE = '/data/data/com.termux/files/home/storage/downloads'

groups = {
    '01_services.txt': {
        'title': '1️⃣ الخدمات الأساسية (Services) - القلب',
        'files': [
            'lib/shared/services/database_service.dart',
            'lib/shared/services/sync_service.dart',
            'lib/shared/services/sync_helpers.dart',
        ],
    },
    '02_local_storage.txt': {
        'title': '2️⃣ قاعدة البيانات المحلية + النماذج',
        'files': [
            'lib/shared/local/local_database.dart',
            'lib/shared/models/class_model.dart',
            'lib/shared/models/student_model.dart',
            'lib/shared/models/attendance_model.dart',
            'lib/shared/models/grade_model.dart',
        ],
    },
    '03_auth.txt': {
        'title': '3️⃣ المصادقة (Auth Screens)',
        'files': [
            'lib/features/auth/presentation/screens/login_screen.dart',
            'lib/features/auth/presentation/screens/register_screen.dart',
            'lib/features/auth/presentation/screens/otp_screen.dart',
            'lib/features/auth/presentation/screens/forgot_password_screen.dart',
            'lib/features/auth/presentation/screens/profile_screen.dart',
            'lib/features/auth/presentation/screens/splash_screen.dart',
        ],
    },
    '04_core_utils.txt': {
        'title': '4️⃣ الأدوات (Utilities) - الحسابات',
        'files': [
            'lib/core/utils/grade_calculator.dart',
            'lib/core/utils/attendance_calculator.dart',
            'lib/core/utils/number_utils.dart',
            'lib/core/utils/student_import.dart',
            'lib/core/utils/student_file_import.dart',
            'lib/core/utils/auth_actions.dart',
            'lib/core/utils/color_utils.dart',
            'lib/core/utils/excel_share.dart',
        ],
    },
    '05_main_config.txt': {
        'title': '5️⃣ نقطة البداية والإعدادات',
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
        'title': '6️⃣ الـ Widgets المشتركة',
        'files': [
            'lib/core/widgets/confirm_dialog.dart',
            'lib/core/widgets/empty_state.dart',
            'lib/core/widgets/student_form_dialog.dart',
            'lib/core/widgets/student_picker_dialog.dart',
            'lib/core/widgets/sync_refresh_mixin.dart',
        ],
    },
    '07_students.txt': {
        'title': '7️⃣ شاشات الطلاب والفصول',
        'files': [
            'lib/features/students/presentation/screens/classes_screen.dart',
            'lib/features/students/presentation/screens/class_detail_screen.dart',
            'lib/features/students/presentation/screens/students_screen.dart',
            'lib/features/students/presentation/screens/student_detail_screen.dart',
            'lib/features/students/presentation/screens/bulk_students_screen.dart',
            'lib/features/students/presentation/screens/home_screen.dart',
        ],
    },
    '08_attendance.txt': {
        'title': '8️⃣ شاشات الحضور',
        'files': [
            'lib/features/attendance/presentation/screens/attendance_list_screen.dart',
            'lib/features/attendance/presentation/screens/take_attendance_screen.dart',
            'lib/features/attendance/presentation/screens/attendance_history_screen.dart',
            'lib/features/attendance/presentation/screens/attendance_report_screen.dart',
        ],
    },
    '09_grades_reports_trash.txt': {
        'title': '9️⃣ الدرجات + التقارير + السلة',
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
        'title': '🔟 الـ Workflow + SQL Migrations',
        'files': [
            '.github/workflows/flutter.yml',
            'supabase/migrations/20261018000001_create_tables.sql',
            'supabase/migrations/20261018000002_create_indexes.sql',
            'supabase/migrations/20261018000003_triggers.sql',
            'supabase/migrations/20261018000004_rls_policies.sql',
            'supabase/migrations/20261020000001_student_code_unique.sql',
        ],
    },
}

print("📂 جاري تقسيم الملفات...\n")

for filename, config in groups.items():
    filepath = os.path.join(BASE, filename)
    with open(filepath, 'w', encoding='utf-8') as out:
        out.write("=" * 80 + "\n")
        out.write(config['title'] + "\n")
        out.write("=" * 80 + "\n\n")

        found = 0
        missing = 0

        for f in config['files']:
            if os.path.exists(f):
                out.write(f"\n\n{'─' * 80}\n")
                out.write(f"📄 {f}\n")
                out.write(f"{'─' * 80}\n\n")
                with open(f, 'r', encoding='utf-8') as fh:
                    out.write(fh.read())
                found += 1
            else:
                out.write(f"\n\n⚠️  الملف مفقود: {f}\n")
                missing += 1

    size = os.path.getsize(filepath) // 1024
    status = f"✅ {found} ملف" + (f" | ⚠️ {missing} مفقود" if missing else "")
    print(f"  {filename}: {size} KB  ({status})")

print(f"\n🎉 تم إنشاء {len(groups)} ملف في: {BASE}")
print(f"\n📤 ارفع كل ملف إلى المحادثة واحداً تلو الآخر (بترتيب 01 → 10)")
