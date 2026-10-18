#!/bin/bash
echo "⏳ جاري دمج ملفات SQL في ملف واحد..."
> full_database_setup.sql
for f in supabase/01_tables.sql supabase/02_indexes.sql supabase/03_triggers.sql supabase/04_rls.sql supabase/05_patch_existing_db.sql supabase/06_sync_indexes.sql; do
    if [ -f "$f" ]; then
        echo "-- ==========================================" >> full_database_setup.sql
        echo "-- FILE: $f" >> full_database_setup.sql
        echo "-- ==========================================" >> full_database_setup.sql
        cat "$f" >> full_database_setup.sql
        echo "" >> full_database_setup.sql
    else
        echo "⚠️ تحذير: الملف $f غير موجود!"
    fi
done
echo "✅ تم إنشاء الملف بنجاح: full_database_setup.sql"
