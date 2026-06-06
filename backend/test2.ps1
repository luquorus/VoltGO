$baseUrl = "http://localhost:8080"

Write-Host "=== LOGIN ==="
$loginResp = Invoke-WebRequest -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"test@1","password":"Admin@123"}'
$login = $loginResp.Content | ConvertFrom-Json
$tok = $login.token
$headers = @{ "Authorization" = "Bearer $tok" }
Write-Host "Token length: $($tok.Length)"
Write-Host "Logged in as: $($login.email)"

Write-Host "`n=== GET STATION ==="
$stationResp = Invoke-WebRequest -Uri "$baseUrl/api/ev/stations?lat=20.990150&lng=105.855610&radiusKm=10&page=0&size=1" -Method GET -Headers $headers
$stationData = $stationResp.Content | ConvertFrom-Json
$station = $stationData.content[0]
$stationId = $station.id
Write-Host "Station: $($station.name) ($stationId)"

Write-Host "`n=== GET CHARGER UNITS ==="
$availResp = Invoke-WebRequest -Uri "$baseUrl/api/ev/stations/$stationId/availability" -Method GET -Headers $headers
$avail = $availResp.Content | ConvertFrom-Json
Write-Host "Charger units: $($avail.Count)"
$unit = $avail[0]
$unitId = $unit.chargerUnitId
Write-Host "Using unit: $unitId"

Write-Host "`n=== CREATE BOOKING ==="
$startTime = (Get-Date).AddMinutes(60).ToUniversalTime().ToString("o")
$endTime = (Get-Date).AddMinutes(120).ToUniversalTime().ToString("o")
$bookingBody = @{
    stationId = $stationId
    chargerUnitId = $unitId
    startTime = $startTime
    endTime = $endTime
} | ConvertTo-Json
$bookingResp = Invoke-WebRequest -Uri "$baseUrl/api/ev/bookings" -Method POST -ContentType "application/json" -Headers $headers -Body $bookingBody
$booking = $bookingResp.Content | ConvertFrom-Json
$bookingId = $booking.id
Write-Host "Booking: $bookingId (status: $($booking.status))"

Write-Host "`n=== CREATE PAYMENT INTENT ==="
$intentResp = Invoke-WebRequest -Uri "$baseUrl/api/ev/payments/bookings/$bookingId/payment-intent" -Method POST -ContentType "application/json" -Headers $headers
$intent = $intentResp.Content | ConvertFrom-Json
$intentId = $intent.id
Write-Host "Payment intent: $intentId"

Write-Host "`n=== SIMULATE SUCCESS ==="
try {
    $simResp = Invoke-WebRequest -Uri "$baseUrl/api/ev/payments/$intentId/simulate-success" -Method POST -ContentType "application/json" -Headers $headers
    $result = $simResp.Content | ConvertFrom-Json
    Write-Host "SUCCESS! Status: $($result.status)"

    Write-Host "`n=== CHECK LOYALTY ==="
    $profileResp = Invoke-WebRequest -Uri "$baseUrl/api/ev/loyalty/me" -Method GET -Headers $headers
    $profile = $profileResp.Content | ConvertFrom-Json
    Write-Host "Points: $($profile.currentPoints) | Lifetime: $($profile.lifetimePoints)"
    Write-Host "Bookings: $($profile.totalBookings) | Ratings: $($profile.totalRatings)"
    Write-Host "Level: $($profile.level) - $($profile.levelName)"

    Write-Host "`n=== POINT HISTORY ==="
    $historyResp = Invoke-WebRequest -Uri "$baseUrl/api/ev/loyalty/points/history?page=0&size=10" -Method GET -Headers $headers
    $history = $historyResp.Content | ConvertFrom-Json
    Write-Host "Total: $($history.totalElements)"
    $history.content | ForEach-Object { Write-Host "  $($_.type) | $($_.source) | +$($_.points) pts" }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $reader.BaseStream.Position = 0
    Write-Host "Body: $($reader.ReadToEnd())"
}
Write-Host "`n=== DONE ==="
