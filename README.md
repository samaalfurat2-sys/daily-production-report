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

## OneDrive Integration (Device Code Flow)

The app uses Microsoft's **Device Code Flow** for OneDrive authentication. No redirect URI or browser deeplink is required.

### How it works
1. Tap **Connect Personal OneDrive** in the OneDrive Sync screen.
2. A code (e.g. `ABCD1234`) and URL (`https://microsoft.com/devicelogin`) are displayed.
3. Open that URL in any browser, enter the code, and sign in with your personal Microsoft (Outlook / Hotmail / Live) account.
4. Tap **I've signed in** in the app to confirm and receive the access token.

### Azure App Registration (for developers / IT)
The app uses a pre-configured Azure AD Application (`client_id: d2123462-2f0c-44f5-8f0e-ff2f489c7449`) registered for personal Microsoft accounts.

If you need to create your own registration:
1. Go to [Azure Portal → App registrations](https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationsListBlade).
2. Click **New registration** → choose **Accounts in any organizational directory and personal Microsoft accounts**.
3. No redirect URI is needed for Device Code Flow. Leave it blank or add `https://login.microsoftonline.com/common/oauth2/nativeclient` as a **Mobile and desktop applications** URI.
4. Under **Authentication → Advanced settings**, enable **Allow public client flows**.
5. Copy the **Application (client) ID** and update `_clientId` in `frontend_template/lib/services/graph_client.dart`.

### Android permissions
The `AndroidManifest.xml` template in `frontend_template/android/app/src/main/` explicitly declares `android.permission.INTERNET`, which is required for all HTTPS calls to Microsoft's OAuth endpoints.
