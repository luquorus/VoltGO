$baseUrl = "http://localhost:8080"
$adminLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$adminHeaders = @{"Authorization"="Bearer $($adminLogin.token)"}
Write-Host "=== Test BS Station Create (Admin Bypass) ===" -ForegroundColor Cyan

$bsBody = @{
    type = "CREATE_BATTERY_SWAP_STATION"
    totalBatteries = 24
    avgChargePowerKw = 40.0
    operatingHours = "24/7"
    parkingFee = 0
    note = "Test BS Station"
    pileTemplates = @(
        @{ pileIndex = 1; slotsPerPile = 6 },
        @{ pileIndex = 2; slotsPerPile = 6 },
        @{ pileIndex = 3; slotsPerPile = 6 },
        @{ pileIndex = 4; slotsPerPile = 6 }
    )
} | ConvertTo-Json -Depth 10

try {
    $bsCR = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $bsBody
    Write-Host "[OK] CR: $($bsCR.id) | Status: $($bsCR.status)" -ForegroundColor Green
    Write-Host "[OK] StationId: $($bsCR.stationId)" -ForegroundColor White
    Write-Host "[OK] VersionId: $($bsCR.proposedVersionId)" -ForegroundColor White
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $stream.ReadToEnd()
        $stream.Dispose()
        Write-Host "Response: $body" -ForegroundColor Red
    } catch {}
}
