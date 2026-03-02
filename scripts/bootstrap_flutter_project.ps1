param(
  [string]$ProjectPath = "production_report_app",
  [string]$TemplatePath = "..\frontend_template"
)

if (!(Test-Path $ProjectPath)) { New-Item -ItemType Directory -Path $ProjectPath | Out-Null }

Push-Location $ProjectPath
flutter create . --platforms=android,windows
Pop-Location

Copy-Item -Path "$TemplatePath\*" -Destination $ProjectPath -Recurse -Force

Push-Location $ProjectPath
flutter pub get
Pop-Location

Write-Host "Ready:"
Write-Host "  cd $ProjectPath"
Write-Host "  flutter run -d windows"
Write-Host "  flutter run -d android"
