param(
  [string]$ProjectPath = "production_report_app",
  [string]$TemplatePath = "..\frontend_template"
)

if (-not (Test-Path $ProjectPath)) { New-Item -ItemType Directory -Path $ProjectPath | Out-Null }
Push-Location $ProjectPath
flutter create . --platforms=android,windows
Pop-Location

Copy-Item -Recurse -Force "$TemplatePath\*" "$ProjectPath\"
Push-Location $ProjectPath
flutter pub get
# Generate localisation files (AppLocalizations) required by all screens.
# Without this step CI throws "undefined getter AppLocalizations" on both
# Android (assembleDebug) and Windows (flutter build windows --release).
flutter gen-l10n
Pop-Location

Write-Host "Ready:"
Write-Host "  cd $ProjectPath"
Write-Host "  flutter run -d windows"
Write-Host "  flutter run -d android"
