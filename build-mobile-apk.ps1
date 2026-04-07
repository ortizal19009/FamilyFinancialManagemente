param(
    [switch]$Release = $true
)

$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot\mobile"

flutter clean
flutter pub get

if ($Release) {
    flutter build apk --release
    Write-Host ""
    Write-Host "APK generado en: mobile\build\app\outputs\flutter-apk\app-release.apk"
} else {
    flutter build apk --debug
    Write-Host ""
    Write-Host "APK generado en: mobile\build\app\outputs\flutter-apk\app-debug.apk"
}

