# ملخص هذه الدفعة

(ملف توثيقي فقط؛ يمكن حذفه بعد القراءة)

## ملفات يجب حذفها يدوياً (لا يمكن حذفها بفك الضغط)
```bash
git rm supabase/01_tables.sql supabase/02_indexes.sql supabase/03_triggers.sql \
       supabase/04_rls.sql supabase/05_patch_existing_db.sql supabase/06_sync_indexes.sql \
       supabase/07_delete_account.sql full_database_setup.sql make_full_sql.sh fix_auth.py lib/core/errors/failures.dart
```
مصدر قاعدة البيانات الوحيد الآن: `supabase/migrations/` (+ ملف جديد لفهرس رقم الطالب).

## خطوات بعد فك الضغط
1. `flutter pub get` (أُضيفت: file_selector، sqflite_common_ffi، flutter_launcher_icons؛ أُزيلت: flutter_riverpod، intl).
2. نفّذ `supabase/migrations/20261020000001_student_code_unique.sql` على قاعدة Supabase.
3. `flutter analyze && flutter test` — **لم يُشغَّل شيء منها عند كتابة هذه التعديلات (لا يوجد Flutter في بيئة العمل)**.
4. ضع ملفات خط Cairo في `assets/google_fonts/` (انظر README هناك).
5. اختياري: ثبّت `android/` في المستودع (الأوامر في README).
