import urllib.parse
import glob
import os
import sys
import pg8000.native

def main():
    print("=" * 50)
    print("🚀 سكربت تهيئة قاعدة بيانات Supabase (Termux Edition)")
    print("=" * 50)
    
    # طلب رابط الاتصال
    db_url = input("\n🔗 الصق رابط الاتصال (Connection String) من Supabase:\n> ").strip()
    
    if not db_url.startswith("postgresql://") and not db_url.startswith("postgres://"):
        print("❌ خطأ: الرابط يجب أن يبدأ بـ postgresql://")
        sys.exit(1)
        
    print("\n⏳ جاري محاولة الاتصال بقاعدة البيانات...")
    try:
        # تفكيك الرابط لفصل اسم المستخدم وكلمة المرور والمضيف
        parsed = urllib.parse.urlparse(db_url)
        password = urllib.parse.unquote(parsed.password) if parsed.password else ""
        
        # الاتصال باستخدام pg8000
        conn = pg8000.native.Connection(
            user=parsed.username,
            password=password,
            host=parsed.hostname,
            port=parsed.port or 5432,
            database=parsed.path.lstrip('/') or 'postgres'
        )
        print("✅ تم الاتصال بنجاح!\n")
    except Exception as e:
        print(f"❌ فشل الاتصال: {e}")
        sys.exit(1)

    # البحث عن ملفات SQL
    sql_files = sorted(glob.glob('supabase/*.sql'))
    if not sql_files:
        print("⚠️ لم يتم العثور على ملفات SQL في مجلد supabase/")
        sys.exit(1)

    print(f"📂 تم العثور على {len(sql_files)} ملفات SQL. جاري التنفيذ...\n")

    for file_path in sql_files:
        filename = os.path.basename(file_path)
        print(f"⏳ تنفيذ: {filename}...")
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                sql_script = f.read()
            
            # تنفيذ محتوى الملف
            conn.run(sql_script)
            print(f"✅ نجح: {filename}")
        except Exception as e:
            print(f"❌ خطأ في {filename}:\n{e}")
            choice = input("\n⚠️ هل تريد الاستمرار للملف التالي؟ (y/n): ")
            if choice.lower() != 'y':
                print("🛑 تم إيقاف التنفيذ بناءً على طلبك.")
                break

    conn.close()
    print("\n🎉 انتهت العملية بالكامل!")

if __name__ == "__main__":
    main()
