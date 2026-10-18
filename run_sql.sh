#!/bin/bash

echo "🔗 الصق رابط الاتصال (Session Pooler) من Supabase هنا واضغط Enter:"
read DB_URL

if [ -z "$DB_URL" ]; then
    echo "❌ لم تقم بلصق الرابط. تم الإلغاء."
    exit 1
fi

# استخراج اسم المضيف (Hostname) من الرابط
HOST=$(echo "$DB_URL" | sed -E 's|.*@([^:/]+).*|\1|')

# البحث عن عنوان IPv4 للمضيف وإجبار psql على استخدامه
IPV4=$(getent ahostsv4 "$HOST" | awk '{print $1}' | head -n 1)

if [ -z "$IPV4" ]; then
    echo "⚠️ تحذير: لم يتم العثور على عنوان IPv4. تأكد من أنك تستخدم رابط Session Pooler."
else
    echo "✅ تم إجبار الاتصال عبر IPv4: $IPV4"
    # إخبار psql باستخدام هذا العنوان
    export PGHOSTADDR="$IPV4"
fi

echo "⏳ جاري تنفيذ ملفات SQL..."
for f in supabase/*.sql; do
    echo "▶️ تنفيذ: $f"
    psql "$DB_URL" -f "$f"
    if [ $? -ne 0 ]; then
        echo "❌ حدث خطأ في الملف: $f"
        echo "هل تريد الاستمرار؟ (y/n)"
        read choice
        if [ "$choice" != "y" ]; then
            break
        fi
    else
        echo "✅ نجح: $f"
    fi
done
echo "🎉 انتهت العملية!"
