[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$baseUrl = "http://localhost:8080"

$loginBody = '{"email":"test@1","password":"Admin@123"}'
$login = Invoke-WebRequest -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body $loginBody -TimeoutSec 15
$j = [System.Text.Encoding]::UTF8.GetString($login.Content) | ConvertFrom-Json
$tok = $j.token
$headers = @{ "Authorization" = "Bearer $tok" }
Write-Host "Logged in: $($j.email)"

$stationUrl = "$baseUrl/api/ev/stations?lat=20.990150&lng=105.855610&radiusKm=10&page=0&size=1"
$s = Invoke-WebRequest -Uri $stationUrl -Method GET -Headers $headers -TimeoutSec 15
$sd = [System.Text.Encoding]::UTF8.GetString($s.Content) | ConvertFrom-Json
$station = $sd.content[0]
$stationId = $station.id
Write-Host "Station: $($station.name) ($stationId)"

$availUrl = "$baseUrl/api/ev/stations/$stationId/availability"
$a = Invoke-WebRequest -Uri $availUrl -Method GET -Headers $headers -TimeoutSec 15
$ad = [System.Text.Encoding]::UTF8.GetString($a.Content) | ConvertFrom-Json
$unit = $ad[0]
$unitId = $unit.chargerUnitId
Write-Host "Charger unit: $unitId"

$startTime = (Get-Date).AddMinutes(60).ToUniversalTime().ToString("o")
$endTime = (Get-Date).AddMinutes(120).ToUniversalTime().ToString("o")
$bookingBody = @{
    stationId = $stationId
    chargerUnitId = $unitId
    startTime = $startTime
    endTime = $endTime
} | ConvertTo-Json -Compress
$b = Invoke-WebRequest -Uri "$baseUrl/api/ev/bookings" -Method POST -ContentType "application/json" -Headers $headers -Body $bookingBody -TimeoutSec 15
$bd = [System.Text.Encoding]::UTF8.GetString($b.Content) | ConvertFrom-Json
$bookingId = $bd.id
Write-Host "Booking: $bookingId ($($bd.status))"

$i = Invoke-WebRequest -Uri "$baseUrl/api/ev/payments/bookings/$bookingId/payment-intent" -Method POST -ContentType "application/json" -Headers $headers -TimeoutSec 15
$id = [System.Text.Encoding]::UTF8.GetString($i.Content) | ConvertFrom-Json
$intentId = $id.id
Write-Host "Payment intent: $intentId"

Write-Host "Simulating success..."
try {
    $sim = Invoke-WebRequest -Uri "$baseUrl/api/ev/payments/$intentId/simulate-success" -Method POST -ContentType "application/json" -Headers $headers -TimeoutSec 15
    $res = [System.Text.Encoding]::UTF8.GetString($sim.Content) | ConvertFrom-Json
    Write-Host "SUCCESS! Status: $($res.status)"

    $p = Invoke-WebRequest -Uri "$baseUrl/api/ev/loyalty/me" -Method GET -Headers $headers -TimeoutSec 15
    $profile = [System.Text.Encoding]::UTF8.GetString($p.Content) | ConvertFrom-Json
    Write-Host "Points: $($profile.currentPoints) | Bookings: $($profile.totalBookings) | Level: $($profile.level)"

    $h = Invoke-WebRequest -Uri "$baseUrl/api/ev/loyalty/points/history?page=0&size=5" -Method GET -Headers $headers -TimeoutSec 15
    $history = [System.Text.Encoding]::UTF8.GetString($h.Content) | ConvertFrom-Json
    Write-Host "History: $($history.totalElements) transactions"
    $history.content | ForEach-Object { Write-Host "  $($_.type) | $($_.source) | +$($_.points)" }
} catch {
    $err = $_.Exception.Response
    $stream = $err.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    Write-Host "ERROR: $($reader.ReadToEnd())"
}
Write-Host "Done."
