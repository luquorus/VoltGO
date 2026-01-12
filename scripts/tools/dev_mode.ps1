# Start development mode với hot reload
# Usage: .\scripts\tools\dev_mode.ps1

Write-Host "🔧 Starting Development Mode (Hot Reload)" -ForegroundColor Cyan
Write-Host ""

$infraPath = Join-Path $PSScriptRoot "..\..\infra"

if (-not (Test-Path $infraPath)) {
    Write-Host "❌ infra folder not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Starting Docker Compose with dev override..." -ForegroundColor Yellow
Write-Host ""

Set-Location $infraPath

# Start with dev override
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

Write-Host ""
Write-Host "✅ Development mode started!" -ForegroundColor Green
Write-Host ""
Write-Host "Hot reload enabled - edit code and see changes automatically!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Access apps at:" -ForegroundColor Yellow
Write-Host "  - EV User: http://localhost:3001" -ForegroundColor White
Write-Host "  - Admin: http://localhost:3002" -ForegroundColor White
Write-Host "  - Collab Web: http://localhost:3003" -ForegroundColor White
Write-Host "  - Collab Mobile: http://localhost:3004" -ForegroundColor White

