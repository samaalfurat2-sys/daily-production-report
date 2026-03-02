param([string]$ProjectPath = "production_report_app")
Push-Location $ProjectPath
flutter build windows --release
Pop-Location
Write-Host "$ProjectPath\build\windows\x64\runner\Release\production_report_app.exe"
