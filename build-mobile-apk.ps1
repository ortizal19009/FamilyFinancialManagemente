param(
    [switch]$Release = $true
)

$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot\mobile"

function Remove-DirectoryWithRetries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$MaxAttempts = 5
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        } catch {
            if ($attempt -eq $MaxAttempts) {
                throw
            }
            Start-Sleep -Milliseconds (500 * $attempt)
        }
    }
}

if (Test-Path -LiteralPath ".\android\gradlew.bat") {
    Push-Location ".\android"
    try {
        .\gradlew.bat --stop | Out-Null
    } catch {
        Write-Host "No se pudo detener Gradle de forma limpia. Se intentara continuar."
    } finally {
        Pop-Location
    }
}

Remove-DirectoryWithRetries -Path ".\build"
Remove-DirectoryWithRetries -Path ".\.dart_tool"
if (Test-Path -LiteralPath ".\.flutter-plugins-dependencies") {
    Remove-Item -LiteralPath ".\.flutter-plugins-dependencies" -Force -ErrorAction SilentlyContinue
}

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
