# Mở tất cả Frontend Apps trong Edge Browser
# Chạy sau khi: cd infra && docker-compose up -d

Write-Host "🌐 Opening Frontend Apps in Edge Browser" -ForegroundColor Cyan
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

Write-Host "✅ Found Edge browser" -ForegroundColor Green
Write-Host ""

# Check if services are running
Write-Host "Checking Docker services..." -ForegroundColor Yellow
$services = @(
    @{ Name = "voltgo-frontend-ev-user"; Url = "http://localhost:3001"; App = "EV User Mobile" }
    @{ Name = "voltgo-frontend-admin"; Url = "http://localhost:3002"; App = "Admin Web Portal" }
    @{ Name = "voltgo-frontend-collab-web"; Url = "http://localhost:3003"; App = "Collaborator Web" }
    @{ Name = "voltgo-frontend-collab-mobile"; Url = "http://localhost:3004"; App = "Collaborator Mobile" }
)

$allRunning = $true
foreach ($service in $services) {
    $container = docker ps --filter "name=$($service.Name)" --format "{{.Names}}"
    if ($container -eq $service.Name) {
        Write-Host "   ✅ $($service.App) is running" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $($service.App) is not running" -ForegroundColor Red
        $allRunning = $false
    }
}

if (-not $allRunning) {
    Write-Host ""
    Write-Host "⚠️  Some services are not running." -ForegroundColor Yellow
    Write-Host "   Start them with: cd infra && docker-compose up -d" -ForegroundColor Cyan
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        exit 1
    }
}

Write-Host ""
Write-Host "Opening apps in Edge browser..." -ForegroundColor Yellow
Write-Host ""

# Open all apps
foreach ($service in $services) {
    Write-Host "   Opening $($service.App)..." -ForegroundColor Cyan
    Start-Process -FilePath $edgePath -ArgumentList $service.Url
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "✅ All apps opened!" -ForegroundColor Green
Write-Host ""
Write-Host "Frontend Apps URLs:" -ForegroundColor Yellow
Write-Host "   📱 EV User Mobile:      http://localhost:3001" -ForegroundColor White
Write-Host "   🖥️  Admin Web Portal:     http://localhost:3002" -ForegroundColor White
Write-Host "   💼 Collaborator Web:     http://localhost:3003" -ForegroundColor White
Write-Host "   📱 Collaborator Mobile:  http://localhost:3004" -ForegroundColor White
Write-Host ""
Write-Host "Backend API:" -ForegroundColor Yellow
Write-Host "   🔧 API:                 http://localhost:8080" -ForegroundColor White
Write-Host "   📚 Swagger UI:          http://localhost:8080/swagger-ui.html" -ForegroundColor White
Write-Host ""
Write-Host "💡 Login với: admin@local / Admin@123" -ForegroundColor Cyan

