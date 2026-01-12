# Reload Frontend Apps
# Usage: .\scripts\tools\reload_frontend.ps1 [app_name]
# Example: .\scripts\tools\reload_frontend.ps1 ev_user_mobile

param(
    [string]$AppName = "all"
)

$apps = @("ev_user_mobile", "admin_web", "collab_web", "collab_mobile")

Write-Host "🔄 Reloading Frontend Apps" -ForegroundColor Cyan
Write-Host ""

if ($AppName -eq "all") {
    Write-Host "Reloading all frontend apps..." -ForegroundColor Yellow
    $appsToReload = $apps
} else {
    if ($apps -contains $AppName) {
        Write-Host "Reloading $AppName..." -ForegroundColor Yellow
        $appsToReload = @($AppName)
    } else {
        Write-Host "❌ Invalid app name: $AppName" -ForegroundColor Red
        Write-Host "Available apps: $($apps -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$infraPath = Join-Path $PSScriptRoot "..\..\infra"

if (-not (Test-Path $infraPath)) {
    Write-Host "❌ infra folder not found!" -ForegroundColor Red
    exit 1
}

Set-Location $infraPath

foreach ($app in $appsToReload) {
    $serviceName = switch ($app) {
        "ev_user_mobile" { "frontend-ev-user" }
        "admin_web" { "frontend-admin" }
        "collab_web" { "frontend-collab-web" }
        "collab_mobile" { "frontend-collab-mobile" }
        default { $null }
    }

    if ($serviceName) {
        Write-Host "`n📦 Rebuilding $app ($serviceName)..." -ForegroundColor Cyan
        
        # Stop service
        docker-compose stop $serviceName
        
        # Rebuild
        docker-compose build $serviceName
        
        # Start service
        docker-compose up -d $serviceName
        
        Write-Host "✅ $app reloaded!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "✅ All done!" -ForegroundColor Green
Write-Host ""
Write-Host "Check status:" -ForegroundColor Yellow
Write-Host "  docker-compose ps" -ForegroundColor White

