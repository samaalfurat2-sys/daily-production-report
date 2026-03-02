# Start Here / ابدأ من هنا

## English
1. Start the backend:
   - `cd backend`
   - create a virtual environment
   - `pip install -r requirements.txt`
   - `python -m app.scripts.seed_demo`
   - `uvicorn app.main:app --reload`
2. Open `http://localhost:8000/docs` and confirm the API is live.
3. Build the Flutter project:
   - `cd scripts`
   - run `bootstrap_flutter_project.ps1`
4. In the app login screen use:
   - `admin / Admin1234`
5. Build outputs:
   - Windows: `flutter build windows --release`
   - Android APK: `flutter build apk --release`
   - Android AAB: `flutter build appbundle --release`

## العربية
1. شغّل السيرفر:
   - `cd backend`
   - أنشئ بيئة افتراضية
   - `pip install -r requirements.txt`
   - `python -m app.scripts.seed_demo`
   - `uvicorn app.main:app --reload`
2. افتح `http://localhost:8000/docs` وتأكد أن الـ API يعمل.
3. ابنِ مشروع Flutter:
   - `cd scripts`
   - شغّل `bootstrap_flutter_project.ps1`
4. الدخول الافتراضي:
   - `admin / Admin1234`
5. ملفات البناء:
   - Windows: `flutter build windows --release`
   - Android APK: `flutter build apk --release`
   - Android AAB: `flutter build appbundle --release`
