# تطبيق المعلمين (Teacher App)

تطبيق Flutter كامل لإدارة الحضور والدرجات والتقارير للمعلمين.

## التقنيات
- Flutter + Riverpod
- Supabase (Auth + PostgreSQL + RLS)
- Excel export
- دعم عربي كامل (RTL)

## الميزات المكتملة
- تسجيل دخول / إنشاء حساب
- إدارة الفصول (إضافة / عرض / حذف ناعم)
- إدارة الطلاب
- ربط الطلاب بالفصول (Enrollment)
- تسجيل الحضور (حاضر / غائب / متأخر / بعذر) مع الافتراضي = حاضر
- إدارة التقييمات والأوزان
- إدخال الدرجات
- تصدير كشف الدرجات إلى Excel
- Soft Delete على كل الكيانات
- RLS جاهز

## خطوات التشغيل

1. أنشئ مشروع Supabase
2. نفّذ ملفات SQL بالترتيب من مجلد `supabase/`:
   - 01_tables.sql
   - 02_indexes.sql
   - 03_triggers.sql
   - 04_rls.sql
3. ضع رابط المشروع و anon key في:
   `lib/core/constants/supabase_config.dart`
4. شغّل:
```bash
flutter pub get
flutter run
```

## هيكل المجلدات
```
lib/
├── core/
├── features/
│   ├── auth/
│   ├── students/
│   ├── attendance/
│   ├── grades/
│   └── reports/
└── shared/
    ├── models/
    └── services/
```

## ملاحظات
- PowerSync + Drift (العمل الكامل دون إنترنت) لم يُدمج بعد — التطبيق يعمل حالياً مع Supabase مباشرة.
- يمكن إضافة PowerSync لاحقاً فوق نفس المخطط.
