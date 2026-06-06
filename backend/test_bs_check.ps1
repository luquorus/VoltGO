$baseUrl = "http://localhost:8080"
$adminLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$adminHeaders = @{"Authorization"="Bearer $($adminLogin.token)"}

# Check BS stations
$stations = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations?serviceType=BATTERY_SWAP" -Method GET -Headers $adminHeaders
Write-Host "BS Stations: $($stations.content.Count) total" -ForegroundColor Cyan
$stations.content | ForEach-Object {
    Write-Host "  [$($_.id)] $($_.name) | Status: $($_.workflowStatus)" -ForegroundColor White
}

# Check CR
Write-Host ""
Write-Host "Latest CR status:" -ForegroundColor Cyan
$crs = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests" -Method GET -Headers $adminHeaders
$crs | Select-Object -First 3 | ForEach-Object {
    Write-Host "  [$($_.id)] Status: $($_.status) | Type: $($_.type)" -ForegroundColor Gray
}
