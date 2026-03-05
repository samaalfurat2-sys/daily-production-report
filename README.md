# Daily Production Report App (Windows + Android) — Source Project v3.0.0

## 📦 Getting the Installers (EXE / APK) — ملفات التثبيت

> **This repository does not contain prebuilt EXE or APK files.**  
> They are generated on-demand via GitHub Actions — no local Flutter/Dart setup required.
>
> **هذا المستودع لا يحتوي ملفات EXE أو APK مبنية مسبقًا.**  
> يتم توليدها عبر GitHub Actions — دون الحاجة لإعداد Flutter محلي.

### Steps / الخطوات

| # | English | العربية |
|---|---------|---------|
| 1 | Open the **Actions** tab of this repository | افتح تبويب **Actions** في هذا المستودع |
| 2 | Select **Build Ready Installers** and click **Run workflow** | اختر **Build Ready Installers** ثم اضغط **Run workflow** |
| 3 | After the run completes, click the finished run and scroll to **Artifacts** | بعد اكتمال التشغيل افتح السجل وانزل إلى قسم **Artifacts** |
| 4 | Download the artifact you need: | نزّل المخرج المطلوب: |

| Artifact | Contents |
|----------|----------|
| **windows-setup-exe** | `ProductionReportSetup.exe` — Windows installer |
| **windows-portable** | Ready-to-run Windows app (no install needed) |
| **android-apk-release** | `app-*-release.apk` — Android APK (install directly on device) |

> **Signed release APK/AAB:** run the **Build Android Release Optional** workflow after
> adding the four `ANDROID_KEYSTORE_*` / `ANDROID_KEY_*` GitHub Secrets described in
> [`INSTALLERS_FROM_GITHUB_AR_EN.md`](INSTALLERS_FROM_GITHUB_AR_EN.md).

---

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
