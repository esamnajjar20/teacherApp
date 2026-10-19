import os

with open('/data/data/com.termux/files/home/storage/downloads/project_review.txt', 'w', encoding='utf-8') as out:
    out.write("=" * 80 + "\n")
    out.write("تقرير مراجعة كامل للمشروع\n")
    out.write("=" * 80 + "\n\n")

    # 1. pubspec
    out.write("\n" + "=" * 80 + "\n# pubspec.yaml\n" + "=" * 80 + "\n")
    with open('pubspec.yaml', 'r', encoding='utf-8') as f:
        out.write(f.read())

    # 2. Core
    for section, path in [
        ('Core - Constants & Errors', 'lib/core'),
        ('Shared - Models', 'lib/shared/models'),
        ('Shared - Services', 'lib/shared/services'),
        ('Shared - Local DB', 'lib/shared/local'),
    ]:
        out.write("\n\n" + "=" * 80 + "\n# " + section + "\n" + "=" * 80 + "\n")
        for root, dirs, files in os.walk(path):
            for file in sorted(files):
                if file.endswith('.dart'):
                    filepath = os.path.join(root, file)
                    out.write(f"\n\n--- {filepath} ---\n")
                    with open(filepath, 'r', encoding='utf-8') as f:
                        out.write(f.read())

    # 3. Features
    for section, path in [
        ('Features - Auth', 'lib/features/auth'),
        ('Features - Students & Classes', 'lib/features/students'),
        ('Features - Attendance', 'lib/features/attendance'),
        ('Features - Grades', 'lib/features/grades'),
        ('Features - Reports', 'lib/features/reports'),
        ('Features - Trash', 'lib/features/trash'),
    ]:
        out.write("\n\n" + "=" * 80 + "\n# " + section + "\n" + "=" * 80 + "\n")
        for root, dirs, files in os.walk(path):
            for file in sorted(files):
                if file.endswith('.dart'):
                    filepath = os.path.join(root, file)
                    out.write(f"\n\n--- {filepath} ---\n")
                    with open(filepath, 'r', encoding='utf-8') as f:
                        out.write(f.read())

    # 4. main.dart
    out.write("\n\n" + "=" * 80 + "\n# main.dart\n" + "=" * 80 + "\n")
    with open('lib/main.dart', 'r', encoding='utf-8') as f:
        out.write(f.read())

print("✅ تم إنشاء التقرير")

import os
size = os.path.getsize('/data/data/com.termux/files/home/storage/downloads/project_review.txt')
print(f"📄 الحجم: {size // 1024} KB")
