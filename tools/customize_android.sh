#!/usr/bin/env bash
# يخصّص مشروع android/ المُولَّد بـ `flutter create`: اسم التطبيق، صلاحية الإنترنت،
# compileSdk، وأيقونة التطبيق. آمن للتشغيل أكثر من مرة.
# الاستخدام (من جذر المشروع):  bash tools/customize_android.sh
set -euo pipefail

APP_LABEL="تطبيق المعلمين"
MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "android/ غير موجود. ولّده أولاً:"
  echo "  flutter create --platforms=android --project-name=teacher_app --org=com.esamnajjar20 ."
  exit 1
fi

# 1) اسم التطبيق الظاهر تحت الأيقونة
sed -i -E "s#android:label=\"[^\"]*\"#android:label=\"${APP_LABEL}\"#" "$MANIFEST"

# 2) صلاحية الإنترنت
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i '/<manifest/a \    <uses-permission android:name="android.permission.INTERNET" />' "$MANIFEST"
fi

# 3) compileSdk 36 (تتطلبه بعض الإضافات)
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] || continue
  sed -i -E 's/compileSdk = flutter\.compileSdkVersion/compileSdk = 36/; s/compileSdkVersion flutter\.compileSdkVersion/compileSdkVersion 36/; s/compileSdk = [0-9]+/compileSdk = 36/; s/compileSdkVersion [0-9]+/compileSdkVersion 36/' "$f"
done

# 4) أيقونة التطبيق (assets/icon/*.png)
flutter pub get
dart run flutter_launcher_icons

echo "تم تخصيص android/."
