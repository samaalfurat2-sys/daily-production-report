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
