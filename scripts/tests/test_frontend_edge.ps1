# Test Frontend Apps trên Edge Browser
# Đảm bảo docker-compose đã chạy: cd infra && docker-compose up -d

Write-Host "🌐 Testing Frontend Apps trên Edge Browser" -ForegroundColor Cyan
Write-Host ""

# Check if Edge is installed
$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edgePath)) {
    $edgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
}

if (-not (Test-Path $edgePath)) {
    Write-Host "❌ Microsoft Edge not found!" -ForegroundColor Red
    Write-Host "   Please install Edge browser first" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Found Edge at: $edgePath" -ForegroundColor Green
Write-Host ""

# Check if services are running
Write-Host "1. Checking Docker services..." -ForegroundColor Yellow
$services = @("voltgo-frontend-ev-user", "voltgo-frontend-admin", "voltgo-frontend-collab-web", "voltgo-frontend-collab-mobile")
$allRunning = $true

foreach ($service in $services) {
    $container = docker ps --filter "name=$service" --format "{{.Names}}"
    if ($container -eq $service) {
        Write-Host "   ✅ $service is running" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $service is not running" -ForegroundColor Red
        $allRunning = $false
    }
}

if (-not $allRunning) {
    Write-Host ""
    Write-Host "⚠️  Some services are not running. Starting them..." -ForegroundColor Yellow
    Write-Host "   Run: cd infra && docker-compose up -d" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "2. Opening apps in Edge browser..." -ForegroundColor Yellow
Write-Host ""

# Open apps in Edge
$apps = @(
    @{ Name = "EV User Mobile"; Url = "http://localhost:3001" }
    @{ Name = "Admin Web Portal"; Url = "http://localhost:3002" }
    @{ Name = "Collaborator Web"; Url = "http://localhost:3003" }
    @{ Name = "Collaborator Mobile"; Url = "http://localhost:3004" }
)

foreach ($app in $apps) {
    Write-Host "   Opening $($app.Name)..." -ForegroundColor Cyan
    Start-Process -FilePath $edgePath -ArgumentList $app.Url
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "✅ All apps opened in Edge browser!" -ForegroundColor Green
Write-Host ""
Write-Host "Test URLs:" -ForegroundColor Yellow
Write-Host "   - EV User: http://localhost:3001" -ForegroundColor White
Write-Host "   - Admin: http://localhost:3002" -ForegroundColor White
Write-Host "   - Collaborator Web: http://localhost:3003" -ForegroundColor White
Write-Host "   - Collaborator Mobile: http://localhost:3004" -ForegroundColor White
Write-Host ""
Write-Host "💡 Tip: Login với admin@local / Admin@123 để test" -ForegroundColor Cyan

