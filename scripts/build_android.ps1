param(
  [string]$ProjectPath = "production_report_app",
  [ValidateSet("apk","aab")] [string]$Target = "apk"
)
Push-Location $ProjectPath
if ($Target -eq "apk") {
  flutter build apk --release
  Write-Host "$ProjectPath\build\app\outputs\flutter-apk\app-release.apk"
} else {
  flutter build appbundle --release
  Write-Host "$ProjectPath\build\app\outputs\bundle\release\app-release.aab"
}
Pop-Location
