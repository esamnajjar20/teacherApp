# خط Cairo المضمَّن

التطبيق يعمل بدون إنترنت، لكن حزمة `google_fonts` تحمّل الخط من الإنترنت
إن لم تجده ضمن الملفات. لتضمينه:

1. نزّل خط Cairo من https://fonts.google.com/specimen/Cairo (Get font → Download all).
2. من مجلد `static/` في الملف المضغوط انسخ هذه الملفات إلى هذا المجلد:
   - `Cairo-Regular.ttf`
   - `Cairo-Medium.ttf`
   - `Cairo-SemiBold.ttf`
   - `Cairo-Bold.ttf`
3. أضفها إلى git. لا حاجة لتعديل أي كود: `google_fonts` يستخدم الملفات المضمَّنة
   تلقائياً ولا يتصل بالإنترنت للخطوط الموجودة هنا.

أي وزن غير موجود يُحمَّل من الإنترنت كما كان قبل التضمين.
