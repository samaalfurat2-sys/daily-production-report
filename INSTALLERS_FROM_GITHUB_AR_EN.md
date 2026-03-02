# إخراج ملفات التثبيت الجاهزة / Generate ready installers

## العربية

هذا المشروع لا يحتوي ملفات EXE أو APK مبنية مسبقًا داخل الحزمة نفسها. للحصول على ملفات التثبيت الجاهزة بدون إعداد محلي طويل:

1. أنشئ مستودع جديد في GitHub.
2. ارفع **كل محتويات هذا المشروع** إلى المستودع.
3. افتح تبويب **Actions**.
4. شغّل workflow باسم **Build Ready Installers**.
5. بعد اكتمال التشغيل نزّل المخرجات التالية:
   - **windows-setup-exe** → يحتوي ملف **ProductionReportSetup.exe** للتثبيت على ويندوز.
   - **windows-portable** → يحتوي نسخة ويندوز الجاهزة للتشغيل مباشرة.
   - **android-apk-debug** → يحتوي ملف **app-debug.apk** قابل للتثبيت على أندرويد.

### إذا أردت APK/AAB إصدار Release
شغّل workflow باسم **Build Android Release Optional** بعد إضافة أسرار GitHub التالية:
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

وسيتم إخراج:
- `app-release.apk`
- `app-release.aab`

## English

This package does not contain prebuilt EXE or APK files. To generate installers without lengthy local setup:

1. Create a new GitHub repository.
2. Upload **all project contents** to the repository.
3. Open the **Actions** tab.
4. Run the workflow named **Build Ready Installers**.
5. Download these artifacts:
   - **windows-setup-exe** → contains **ProductionReportSetup.exe** Windows installer.
   - **windows-portable** → ready-to-run Windows app bundle.
   - **android-apk-debug** → contains **app-debug.apk** for Android installation.

### If you need signed release APK/AAB
Run **Build Android Release Optional** after adding these GitHub Secrets:
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

Outputs:
- `app-release.apk`
- `app-release.aab`
