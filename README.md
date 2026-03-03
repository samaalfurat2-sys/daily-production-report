# Daily Production Report App (Windows + Android) — Source Project v2.0

This project is a buildable source package for a bilingual Daily Production Report system with:
- Windows desktop app (Flutter Windows)
- Android app (Flutter Android)
- FastAPI backend
- Multi-user login and roles
- Shift reporting for Blow / Filling / Label / Shrink / Diesel
- Raw Materials Warehouse
- Finished Goods Warehouse
- Automatic inventory posting when a shift is approved

## Demo accounts
After backend setup:
- admin / Admin1234
- supervisor / Supervisor123
- operator / Operator123
- viewer / Viewer123

## Quick local backend (SQLite)
```bash
cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/macOS:
# source .venv/bin/activate
pip install -r requirements.txt
python -m app.scripts.seed_demo
uvicorn app.main:app --reload
```

Open:
- http://localhost:8000/docs

## Flutter bootstrap
```powershell
cd scripts
powershell -ExecutionPolicy Bypass -File .\bootstrap_flutter_project.ps1 -ProjectPath production_report_app -TemplatePath ..\frontend_template
```

## Build
Windows:
```powershell
cd production_report_app
flutter build windows --release
```

Android:
```powershell
flutter build apk --release
flutter build appbundle --release
```

---

## Android OneDrive Sign-In Setup

### Root cause of OneDrive sign-in failures on Android

The Android APK requires three things that are often missed:

1. **INTERNET permission** — declared in `AndroidManifest.xml` (already included).
2. **`singleTask` launch mode** — allows the OS to route the OAuth redirect back to the exact activity that started the flow (already set in `AndroidManifest.xml`).
3. **Registered redirect URI in Azure** — the `msauth://` redirect URI must be registered for your package name **and** your SHA-1 signing fingerprint.

---

### Step 1 — Get your SHA-1 fingerprint

**Debug keystore** (for development / CI):
```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android -keypass android
```

**Release keystore** (for Play Store / production):
```bash
keytool -list -v \
  -keystore /path/to/your/release.jks \
  -alias your_key_alias \
  -storepass YOUR_STORE_PASSWORD
```

Copy the `SHA1:` line from the output (e.g. `AA:BB:CC:...`).

---

### Step 2 — Register the redirect URI in Azure

1. Open [Azure Portal → App Registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade) → select your app.
2. Click **Authentication** → **Add a platform** → **Android**.
3. Enter:
   - **Package name**: `com.example.production_report_app`  
     *(replace with your actual applicationId from `android/app/build.gradle`)*
   - **Signature hash**: paste the SHA-1 from Step 1 (Azure will base64-encode it automatically).
4. Azure shows the generated redirect URI:
   ```
   msauth://com.example.production_report_app/<base64-sha1>
   ```
5. Copy it — you will need it in the `OneDriveAuth` wrapper (`lib/auth/onedrive_auth.dart`).

---

### Step 3 — Update the redirect URI in code

Open `frontend_template/lib/auth/onedrive_auth.dart` and replace
`placeholder_replace_with_your_base64_sha1` with the SHA-1 hash portion
from the redirect URI you copied in Step 2.

---

### Step 4 — Verify the intent-filter in AndroidManifest.xml

`frontend_template/android/app/src/main/AndroidManifest.xml` already contains:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="msauth"
          android:host="com.example.production_report_app"/>
</intent-filter>
```

If you rename the package, update `android:host` to match.

---

### Capturing logs (Android)

Run these while reproducing the sign-in failure:

```bash
# Filter for your package
adb logcat | grep -i "com.example.production_report_app"

# Broaden to auth-related tags
adb logcat | grep -iE "msal|oauth|auth|flutter|OneDriveAuth"

# Save to file for sharing
adb logcat -d > /tmp/logcat_$(date +%Y%m%d_%H%M%S).txt
```

---

### Current auth flow (device-code)

The app currently uses the **device-code flow**: no browser redirect is required.
The user is shown a short code and a URL (`https://microsoft.com/devicelogin`).  
This works on all platforms without any redirect URI registration.

`lib/auth/onedrive_auth.dart` provides a `flutter_appauth`-based **PKCE flow**
alternative that handles the browser redirect automatically and gives a
one-tap sign-in experience on Android.

