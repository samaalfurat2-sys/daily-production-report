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

The app connects to OneDrive using a **device-code flow** by default — the
user is shown a short code and a URL (`https://microsoft.com/devicelogin`),
signs in on any browser, and then taps "I've signed in" in the app.  This
works on all platforms without any redirect URI registration.

`frontend_template/lib/auth/onedrive_auth.dart` provides a `flutter_appauth`
**PKCE flow** alternative that opens a browser tab and redirects back
automatically (one-tap sign-in on Android).  The steps below are required
**only** if you switch to the PKCE flow.

---

### Step 1 — Get your SHA-1 signing fingerprint

**Debug keystore** (for development / emulator):
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
  -alias YOUR_KEY_ALIAS \
  -storepass YOUR_STORE_PASSWORD
```

Copy the `SHA1:` line from the output (e.g. `AA:BB:CC:…`).

> **Windows users:** The debug keystore is at `%USERPROFILE%\.android\debug.keystore`.
> See `commands.txt` for the full command list.

---

### Step 2 — Register an Azure App (one-time)

1. Open [Azure Portal → App Registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade).
2. Click **New registration**. Give it a name (e.g. `ProductionReportApp`).
3. Under **Supported account types**, select **"Personal Microsoft accounts only"**
   (for personal OneDrive) or **"Any Azure AD directory + personal accounts"**
   for both.
4. Click **Register**.
5. Copy the **Application (client) ID** — this is your `_clientId` in `graph_client.dart`.

---

### Step 3 — Register the redirect URI in Azure

1. In your app registration, click **Authentication → Add a platform → Android**.
2. Enter:
   - **Package name**: `com.example.production_report_app`
     *(replace with your actual `applicationId` from `android/app/build.gradle`)*
   - **Signature hash**: paste the SHA-1 from Step 1 (Azure base64-encodes it automatically).
3. Azure displays the generated redirect URI:
   ```
   msauth://com.example.production_report_app/<base64-sha1>
   ```
4. Copy the full URI — you will need it in Step 4.

---

### Step 4 — Update the placeholder in code

Open `frontend_template/lib/auth/onedrive_auth.dart` and replace the value of
`_sha1Placeholder` with the base64-sha1 segment from the redirect URI you
copied in Step 3.

```dart
// Before (placeholder — do NOT ship this):
static const _sha1Placeholder = 'placeholder_replace_with_your_base64_sha1';

// After (your actual value):
static const _sha1Placeholder = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789AB==';
```

> **Security note:** The SHA-1 itself is NOT a secret, but do not commit
> keystore passwords or private keys to this repository.

---

### Step 5 — Verify the intent-filter in AndroidManifest.xml

`frontend_template/android/app/src/main/AndroidManifest.xml` already contains:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data
        android:scheme="msauth"
        android:host="com.example.production_report_app"/>
</intent-filter>
```

If you rename the package, update `android:host` to match your `applicationId`.

---

### Capturing Android logs for debugging

Run these while reproducing the sign-in failure on a connected device or
emulator:

```bash
# Filter to your package only
adb logcat | grep -i "com.example.production_report_app"

# Broaden to auth / OAuth / MSAL related tags
adb logcat | grep -iE "msal|oauth|auth|flutter|OneDriveAuth"

# Save a log snapshot to a file
adb logcat -d > /tmp/logcat_$(date +%Y%m%d_%H%M%S).txt
```

See `commands.txt` at the repo root for the full keytool / adb reference.
