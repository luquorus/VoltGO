$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8080"

# Login
Write-Host "=== LOGIN ==="
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"test@1","password":"Admin@123"}'
$tok = $login.token
$userId = $login.userId
Write-Host "Logged in as: $($login.email)"

# Get a station and charger unit
Write-Host "`n=== GET STATIONS ==="
$stations = Invoke-RestMethod -Uri "$baseUrl/api/ev/stations?lat=20.990150&lng=105.855610&radiusKm=10&page=0&size=1" -Method GET -Headers @{ "Authorization" = "Bearer $tok" }
if ($stations.content.Count -gt 0) {
    $station = $stations.content[0]
    $stationId = $station.id
    Write-Host "Station: $($station.name) ($stationId)"

    # Get charger units
    $units = Invoke-RestMethod -Uri "$baseUrl/api/ev/stations/$stationId/availability" -Method GET -Headers @{ "Authorization" = "Bearer $tok" }
    if ($units.Count -gt 0) {
        $unit = $units[0]
        $unitId = $unit.chargerUnitId
        Write-Host "Charger unit: $unitId"

        # Create booking
        Write-Host "`n=== CREATE BOOKING ==="
        $startTime = (Get-Date).AddMinutes(60)
        $endTime = (Get-Date).AddMinutes(120)
        $bookingReq = @{
            stationId = $stationId
            chargerUnitId = $unitId
            startTime = $startTime.ToUniversalTime().ToString("o")
            endTime = $endTime.ToUniversalTime().ToString("o")
        }
        $booking = Invoke-RestMethod -Uri "$baseUrl/api/ev/bookings" -Method POST -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $tok" } -Body ($bookingReq | ConvertTo-Json)
        $bookingId = $booking.id
        Write-Host "Booking created: $bookingId (status: $($booking.status))"

        # Create payment intent
        Write-Host "`n=== CREATE PAYMENT INTENT ==="
        $intent = Invoke-RestMethod -Uri "$baseUrl/api/ev/payments/bookings/$bookingId/payment-intent" -Method POST -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $tok" }
        $intentId = $intent.id
        Write-Host "Payment intent: $intentId (status: $($intent.status))"

        # Simulate success
        Write-Host "`n=== SIMULATE SUCCESS ==="
        try {
            $result = Invoke-RestMethod -Uri "$baseUrl/api/ev/payments/$intentId/simulate-success" -Method POST -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $tok" }
            Write-Host "SUCCESS! Booking status: $($result.status)"

            # Check loyalty
            Write-Host "`n=== CHECK LOYALTY ==="
            $profile = Invoke-RestMethod -Uri "$baseUrl/api/ev/loyalty/me" -Method GET -Headers @{ "Authorization" = "Bearer $tok" }
            Write-Host "Current Points: $($profile.currentPoints)"
            Write-Host "Lifetime Points: $($profile.lifetimePoints)"
            Write-Host "Total Bookings: $($profile.totalBookings)"
            Write-Host "Total Ratings: $($profile.totalRatings)"
            Write-Host "Level: $($profile.level) ($($profile.levelName))"

            # Check point history
            Write-Host "`n=== POINT HISTORY ==="
            $history = Invoke-RestMethod -Uri "$baseUrl/api/ev/loyalty/points/history" -Method GET -Headers @{ "Authorization" = "Bearer $tok" }
            Write-Host "Total transactions: $($history.totalElements)"
            $history.content | ForEach-Object {
                Write-Host "  - $($_.type) | $($_.source) | $($_.points) pts | $($_.description)"
            }

            # Check eligible stations
            Write-Host "`n=== ELIGIBLE STATIONS ==="
            $eligible = Invoke-RestMethod -Uri "$baseUrl/api/ev/loyalty/ratings/eligible" -Method GET -Headers @{ "Authorization" = "Bearer $tok" }
            Write-Host "Eligible stations: $($eligible.Count)"
            $eligible | ForEach-Object { Write-Host "  - $($_.stationName) ($($_.sourceType))" }
        } catch {
            Write-Host "ERROR: $($_.Exception.Message)"
            $errBody = [System.Text.Encoding]::UTF8.GetString($_.Exception.Response.GetResponseStream().ReadAll())
            Write-Host "Response: $errBody"
        }
    } else {
        Write-Host "No available charger units"
    }
} else {
    Write-Host "No stations found"
}
Write-Host "`n=== DONE ==="
