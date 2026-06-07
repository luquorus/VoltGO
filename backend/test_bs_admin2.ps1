$baseUrl = "http://localhost:8080"

Write-Host "=== Test Login as admin2@local ===" -ForegroundColor Cyan
try {
    $login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{email="admin2@local";password="Admin@456"} | ConvertTo-Json)
    if ($login.token) {
        Write-Host "[OK] Login SUCCESS" -ForegroundColor Green
        Write-Host "    UserId: $($login.userId)" -ForegroundColor White
        Write-Host "    Token: $($login.token.Substring(0, 40))..." -ForegroundColor White
        $headers = @{"Authorization"="Bearer $($login.token)"}
    } else {
        Write-Host "[FAIL] No token in response: $($login | ConvertTo-Json)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[FAIL] Login failed: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $stream.ReadToEnd()
        $stream.Dispose()
        Write-Host "Response: $body" -ForegroundColor Red
    } catch {}
    exit 1
}

Write-Host ""
Write-Host "=== Test 1: Create Battery Swap Station (admin2) ===" -ForegroundColor Cyan
$bsBody = @{
    stationData = @{
        name = "Test BS Station admin2 $(Get-Date -Format 'HHmmss')"
        address = "123 Test Street, Hanoi"
        location = @{ lat = 21.0285; lng = 105.8542 }
        operatingHours = "24/7"
        parkingFee = 0
        totalBatteries = 20
        avgChargePowerKw = 40.0
        note = "Test by admin2"
    }
    publishImmediately = $true
} | ConvertTo-Json -Depth 10

try {
    $station = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/stations" -Method POST -Headers $headers -ContentType "application/json" -Body $bsBody
    Write-Host "[OK] Station Created" -ForegroundColor Green
    Write-Host "    ID: $($station.id)" -ForegroundColor White
    Write-Host "    Name: $($station.name)" -ForegroundColor White
    Write-Host "    totalBatteries: $($station.totalBatteries)" -ForegroundColor White
    Write-Host "    availableBatteries: $($station.availableBatteries)" -ForegroundColor White
    Write-Host "    trustScore: $($station.trustScore)" -ForegroundColor White
    Write-Host "    workflowStatus: $($station.workflowStatus)" -ForegroundColor White
    $stationId = $station.id
} catch {
    Write-Host "[FAIL] Create station: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $stream.ReadToEnd()
        $stream.Dispose()
        Write-Host "Response: $body" -ForegroundColor Red
    } catch {}
    $stationId = $null
}

if ($stationId) {
    Write-Host ""
    Write-Host "=== Test 2: Get Station Detail ===" -ForegroundColor Cyan
    try {
        $detail = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/stations/$stationId" -Method GET -Headers $headers
        Write-Host "[OK] Station Detail" -ForegroundColor Green
        Write-Host "    totalPiles: $($detail.totalPiles)" -ForegroundColor White
        Write-Host "    totalSlots: $($detail.totalSlots)" -ForegroundColor White
        Write-Host "    trustScore: $($detail.trustScore)" -ForegroundColor White
    } catch {
        Write-Host "[FAIL] Get detail: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "=== Test 3: List All Stations ===" -ForegroundColor Cyan
    try {
        $list = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/stations?page=0&size=5" -Method GET -Headers $headers
        Write-Host "[OK] Station List" -ForegroundColor Green
        Write-Host "    Total: $($list.totalElements)" -ForegroundColor White
        foreach ($s in $list.content) {
            Write-Host "    - $($s.name) | batteries: $($s.availableBatteries)/$($s.totalBatteries) | trust: $($s.trustScore) | piles: $($s.totalPiles)" -ForegroundColor White
        }
    } catch {
        Write-Host "[FAIL] List stations: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
