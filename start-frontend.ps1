$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$frontendRoot = Join-Path $projectRoot 'frontend'

Set-Location $frontendRoot

if (Get-Command npm.cmd -ErrorAction SilentlyContinue) {
    & npm.cmd start
    exit $LASTEXITCODE
}

Write-Host "No se encontro npm.cmd en el PATH." -ForegroundColor Yellow
Write-Host "Instala Node.js o ejecuta manualmente desde frontend:" -ForegroundColor Yellow
Write-Host "npm.cmd start"
