$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonExe = Join-Path $projectRoot '.venv\Scripts\python.exe'

Set-Location $projectRoot

if (Test-Path $pythonExe) {
    & $pythonExe -m uvicorn backend.app:asgi_app --host 127.0.0.1 --port 5000 --reload
    exit $LASTEXITCODE
}

Write-Host "No se encontro .venv\\Scripts\\python.exe en la raiz del proyecto." -ForegroundColor Yellow
Write-Host "Crea o activa el entorno virtual, o ejecuta manualmente:" -ForegroundColor Yellow
Write-Host "py -m uvicorn backend.app:asgi_app --host 127.0.0.1 --port 5000 --reload"
