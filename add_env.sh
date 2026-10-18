#!/bin/bash

echo "======================================================"
echo "🚀 سكربت إضافة مفاتيح Supabase إلى GitHub"
echo "======================================================"

# 1. التحقق من تسجيل الدخول في GitHub
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ أنت غير مسجل الدخول في GitHub!"
    echo "يرجى كتابة الأمر التالي أولاً ثم إعادة تشغيل السكربت:"
    echo "gh auth login"
    exit 1
fi
echo "✅ تم التحقق من تسجيل الدخول في GitHub."
echo ""

# 2. طلب الرابط
read -p "🔗 الصق رابط Supabase (Project URL) هنا: " SUPABASE_URL
if [ -z "$SUPABASE_URL" ]; then
    echo "❌ الرابط فارغ! تم الإلغاء."
    exit 1
fi

# 3. طلب المفتاح العام
echo "🔑 (ملاحظة: عند لصق المفتاح لن يظهر النص على الشاشة للأمان، وهذا طبيعي)"
read -sp "الصق المفتاح العام (Anon Key) هنا: " SUPABASE_ANON_KEY
echo ""
if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ المفتاح فارغ! تم الإلغاء."
    exit 1
fi

echo ""
echo "⏳ جاري إضافة المفاتيح إلى GitHub Secrets..."

# 4. إضافة المفاتيح
gh secret set SUPABASE_URL -b "$SUPABASE_URL"
gh secret set SUPABASE_ANON_KEY -b "$SUPABASE_ANON_KEY"

if [ $? -eq 0 ]; then
    echo "✅ تمت إضافة المفاتيح بنجاح!"
else
    echo "❌ حدث خطأ أثناء إضافة المفاتيح."
    exit 1
fi

echo ""
echo "📋 قائمة المفاتيح المسجلة حالياً:"
gh secret list
echo ""

# 5. سؤال المستخدم: هل يريد بناء APK جديد الآن؟
read -p "🚀 هل تريد بدء بناء APK جديد الآن؟ (y/n): " build_choice
if [ "$build_choice" = "y" ] || [ "$build_choice" = "Y" ]; then
    echo "⏳ جاري تحفيز البناء على GitHub..."
    git commit --allow-empty -m "Trigger rebuild with Supabase secrets"
    git push origin main
    echo "✅ تم الرفع! جاري مراقبة البناء..."
    sleep 3
    gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
else
    echo "👍 يمكنك بناء التطبيق لاحقاً بـ git push."
fi
