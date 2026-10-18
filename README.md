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
   - (إن كنت قد نفّذتها سابقاً) نفّذ `05_patch_existing_db.sql` لتطبيق إصلاحات الأمان
3. شغّل التطبيق مع تمرير المفاتيح (لا تضعها داخل الكود):
```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```
4. للبناء عبر GitHub Actions أضف السرّين `SUPABASE_URL` و `SUPABASE_ANON_KEY`
   في Settings → Secrets and variables → Actions.

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

## العمل بدون إنترنت والمزامنة
- كل القراءة والكتابة تتم على قاعدة SQLite محلية (`sqflite`) لكل مستخدم، فيعمل التطبيق كاملاً بدون اتصال.
- كل تعديل يُعلَّم للرفع ثم يُرفع تلقائياً عند توفر الإنترنت، ويُسحب ما تغيّر على السيرفر (كل 45 ثانية، وعند عودة الاتصال، وبعد كل حفظ، وبزر المزامنة في الشريط العلوي).
- التعارض: **آخر رفع يفوز**. التعديل المحلي الذي لم يُرفع لا يُكتب فوقه عند السحب.
- أول تسجيل دخول يحتاج إنترنت. بعده تبقى الجلسة محفوظة.
- شغّل `supabase/06_sync_indexes.sql` لتسريع المزامنة.
- بيانات الجهاز غير مشفّرة (ملف SQLite عادي).
