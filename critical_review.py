import os

# فقط الملفات التي تحتاج مراجعة دقيقة
files_to_review = [
    # Services (القلب)
    'lib/shared/services/database_service.dart',
    'lib/shared/services/sync_service.dart',
    'lib/shared/services/sync_helpers.dart',
    'lib/shared/local/local_database.dart',
    # Auth (نقطة الدخول)
    'lib/features/auth/presentation/screens/login_screen.dart',
    'lib/features/auth/presentation/screens/register_screen.dart',
    'lib/features/auth/presentation/screens/otp_screen.dart',
    'lib/features/auth/presentation/screens/forgot_password_screen.dart',
    # Core utils
    'lib/core/utils/grade_calculator.dart',
    'lib/core/utils/attendance_calculator.dart',
    'lib/core/utils/student_import.dart',
    'lib/core/utils/auth_actions.dart',
    # main
    'lib/main.dart',
]

with open('/data/data/com.termux/files/home/storage/downloads/critical_review.txt', 'w', encoding='utf-8') as out:
    out.write("=" * 80 + "\n# مراجعة الملفات الحرجة\n" + "=" * 80 + "\n\n")
    for f in files_to_review:
        if os.path.exists(f):
            out.write(f"\n\n{'=' * 80}\n# {f}\n{'=' * 80}\n\n")
            with open(f, 'r', encoding='utf-8') as fh:
                out.write(fh.read())
        else:
            out.write(f"\n⚠️ {f} مفقود\n")

size = os.path.getsize('/data/data/com.termux/files/home/storage/downloads/critical_review.txt')
print(f"✅ تم إنشاء critical_review.txt")
print(f"📄 الحجم: {size // 1024} KB (أصغر بكثير)")
