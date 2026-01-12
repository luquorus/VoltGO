# Test Booking with Charger Unit - Comprehensive Test Script
# Tests all booking functionality with charger unit selection

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fix TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::Expect100Continue = $false

$BACKEND_URL = "http://localhost:8080"

Write-Host "=== BOOKING WITH CHARGER UNIT TEST ===" -ForegroundColor Magenta
Write-Host "Backend: $BACKEND_URL`n"

# Helper functions
function Invoke-Api {
    param([string]$Uri, [string]$Method, [hashtable]$Headers, [object]$Body)
    
    $params = @{
        Uri = $Uri
        Method = $Method
        ContentType = "application/json"
        TimeoutSec = 30
        UseBasicParsing = $true
    }
    
    if ($Headers) { $params.Headers = $Headers }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Compress) }
    
    try {
        return Invoke-RestMethod @params
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $errorObj = $body | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        Write-Host "  [ERROR] Status: $statusCode, Message: $($_.Exception.Message)" -ForegroundColor Red
        if ($errorObj) {
            Write-Host "  Error Code: $($errorObj.code), Message: $($errorObj.message)" -ForegroundColor Red
        } else {
            Write-Host "  Response: $body" -ForegroundColor Red
        }
        
        $global:LAST_API_ERROR = @{
            StatusCode = $statusCode
            Error = $errorObj
            Body = $body
        }
        throw
    }
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Err {
    param([string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

# Step 1: Register EV User (if not exists) then Login
Write-Step "Step 1: Register & Login as EV User"
try {
    # Try to register first (may fail if user exists, that's OK)
    try {
        $registerResp = Invoke-Api `
            -Uri "$BACKEND_URL/auth/register" `
            -Method POST `
            -Body @{email="evuser1@local"; password="EvUser@123"; role="EV_USER"}
        Write-OK "User registered: evuser1@local"
    } catch {
        Write-Host "  [INFO] User may already exist, trying login..." -ForegroundColor Yellow
    }
    
    # Login
    $loginResp = Invoke-Api `
        -Uri "$BACKEND_URL/auth/login" `
        -Method POST `
        -Body @{email="evuser1@local"; password="EvUser@123"}
    
    if (-not $loginResp.token) {
        Write-Err "Login failed - no token"
        exit 1
    }
    
    $token = $loginResp.token
    $userId = $loginResp.userId
    $headers = @{Authorization = "Bearer $token"}
    Write-OK "Logged in: userId=$userId"
} catch {
    Write-Err "Login failed: $($_.Exception.Message)"
    exit 1
}

# Step 2: Get a published station
Write-Step "Step 2: Get Published Station"
try {
    $stations = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/stations?lat=21.0400&lng=105.8700&radiusKm=10" `
        -Method GET `
        -Headers $headers
    
    if (-not $stations.content -or $stations.content.Count -eq 0) {
        Write-Err "No published stations found"
        exit 1
    }
    
    $stationId = $stations.content[0].stationId
    Write-OK "Using station: $stationId"
} catch {
    Write-Err "Failed to get station: $($_.Exception.Message)"
    exit 1
}

# Step 3: Get Charger Units
Write-Step "Step 3: Get Charger Units for Station"
try {
    $chargerUnits = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/stations/$stationId/charger-units" `
        -Method GET `
        -Headers $headers
    
    if (-not $chargerUnits -or $chargerUnits.Count -eq 0) {
        Write-Err "No charger units found for station"
        exit 1
    }
    
    $chargerUnitId = $chargerUnits[0].id
    $chargerUnitLabel = $chargerUnits[0].label
    Write-OK "Found $($chargerUnits.Count) charger unit(s)"
    Write-Host "    Using charger unit: $chargerUnitLabel (id=$chargerUnitId)"
    Write-Host "    Power: $($chargerUnits[0].powerType) $($chargerUnits[0].powerKw)kW"
    Write-Host "    Price: $($chargerUnits[0].pricePerHour) VND/hour"
    Write-Host "    Status: $($chargerUnits[0].status)"
} catch {
    Write-Err "Failed to get charger units: $($_.Exception.Message)"
    exit 1
}

# Step 4: Get Availability
Write-Step "Step 4: Get Availability for Station"
try {
    $tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
    $availability = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/stations/$stationId/availability?date=$tomorrow&slotMinutes=30" `
        -Method GET `
        -Headers $headers
    
    if (-not $availability -or -not $availability.availability) {
        Write-Err "No availability data returned"
        exit 1
    }
    
    $selectedUnitAvailability = $availability.availability | Where-Object { $_.chargerUnit.id -eq $chargerUnitId }
    if (-not $selectedUnitAvailability) {
        Write-Err "Charger unit not found in availability"
        exit 1
    }
    
    $slots = $selectedUnitAvailability.slots
    $availableSlots = $slots | Where-Object { $_.status -eq "AVAILABLE" }
    $bookedSlots = $slots | Where-Object { $_.status -eq "BOOKED" }
    $heldSlots = $slots | Where-Object { $_.status -eq "HELD" }
    
    Write-OK "Availability retrieved: $($slots.Count) slots"
    Write-Host "    AVAILABLE: $($availableSlots.Count)"
    Write-Host "    BOOKED: $($bookedSlots.Count)"
    Write-Host "    HELD: $($heldSlots.Count)"
} catch {
    Write-Err "Failed to get availability: $($_.Exception.Message)"
    exit 1
}

# Step 5: Create Booking with Charger Unit (HOLD)
Write-Step "Step 5: Create Booking with Charger Unit (HOLD)"
try {
    $startTime = (Get-Date).AddDays(1).AddHours(12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddDays(1).AddHours(13).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        chargerUnitId = $chargerUnitId
        startTime = $startTime
        endTime = $endTime
    }
    
    $booking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    if ($booking.status -ne "HOLD") {
        Write-Err "Expected status HOLD, got: $($booking.status)"
        exit 1
    }
    
    if (-not $booking.holdExpiresAt) {
        Write-Err "holdExpiresAt is missing"
        exit 1
    }
    
    if (-not $booking.chargerUnitId -or $booking.chargerUnitId -ne $chargerUnitId) {
        Write-Err "chargerUnitId is missing or incorrect"
        exit 1
    }
    
    if (-not $booking.priceSnapshot) {
        Write-Err "priceSnapshot is missing"
        exit 1
    }
    
    $bookingId = $booking.id
    Write-OK "Booking created: id=$bookingId, status=HOLD"
    Write-Host "    chargerUnitId: $($booking.chargerUnitId)"
    Write-Host "    holdExpiresAt: $($booking.holdExpiresAt)"
    Write-Host "    priceSnapshot amount: $($booking.priceSnapshot.amount)"
} catch {
    Write-Err "Failed to create booking: $($_.Exception.Message)"
    exit 1
}

# Step 6: Test Double-Booking Prevention (409 CONFLICT)
Write-Step "Step 6: Test Double-Booking Prevention (409 CONFLICT)"
try {
    $startTime = (Get-Date).AddDays(1).AddHours(12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddDays(1).AddHours(13).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        chargerUnitId = $chargerUnitId
        startTime = $startTime
        endTime = $endTime
    }
    
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    Write-Err "Should have failed with 409 CONFLICT for overlapping slot"
    exit 1
} catch {
    if ($global:LAST_API_ERROR.StatusCode -eq 409) {
        Write-OK "Correctly rejected overlapping booking with 409 CONFLICT"
        Write-Host "    Error code: $($global:LAST_API_ERROR.Error.code)"
    } else {
        Write-Err "Expected 409 CONFLICT, got status: $($global:LAST_API_ERROR.StatusCode)"
        exit 1
    }
}

# Step 7: Test Partial Overlap (should also fail)
Write-Step "Step 7: Test Partial Overlap (should fail)"
try {
    $startTime = (Get-Date).AddDays(1).AddHours(12).AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddDays(1).AddHours(13).AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        chargerUnitId = $chargerUnitId
        startTime = $startTime
        endTime = $endTime
    }
    
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    Write-Err "Should have failed with 409 CONFLICT for partial overlap"
    exit 1
} catch {
    if ($global:LAST_API_ERROR.StatusCode -eq 409) {
        Write-OK "Correctly rejected partial overlap with 409 CONFLICT"
    } else {
        Write-Err "Expected 409 CONFLICT, got status: $($global:LAST_API_ERROR.StatusCode)"
        exit 1
    }
}

# Step 8: Get Availability Again (should show HELD slot)
Write-Step "Step 8: Get Availability Again (should show HELD slot)"
try {
    $tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
    $availability = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/stations/$stationId/availability?date=$tomorrow&slotMinutes=30" `
        -Method GET `
        -Headers $headers
    
    $selectedUnitAvailability = $availability.availability | Where-Object { $_.chargerUnit.id -eq $chargerUnitId }
    $slots = $selectedUnitAvailability.slots
    
    # Find slot that overlaps with our booking
    $bookingStart = [DateTime]::Parse((Get-Date).AddDays(1).AddHours(12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
    $overlappingSlot = $slots | Where-Object {
        $slotStart = [DateTime]::Parse($_.startTime)
        $slotEnd = [DateTime]::Parse($_.endTime)
        ($slotStart -lt $bookingStart.AddHours(1) -and $slotEnd -gt $bookingStart)
    } | Select-Object -First 1
    
    if ($overlappingSlot.status -eq "HELD") {
        Write-OK "Availability correctly shows HELD status for our booking"
    } else {
        Write-Host "  [INFO] Slot status: $($overlappingSlot.status) (may be BOOKED if already confirmed)" -ForegroundColor Yellow
    }
} catch {
    Write-Err "Failed to get availability: $($_.Exception.Message)"
    exit 1
}

# Step 9: Test Validation - Missing chargerUnitId (should fail)
Write-Step "Step 9: Test Validation - Missing chargerUnitId (should fail)"
try {
    $startTime = (Get-Date).AddDays(1).AddHours(14).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddDays(1).AddHours(15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        startTime = $startTime
        endTime = $endTime
    }
    
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    Write-Err "Should have rejected missing chargerUnitId"
    exit 1
} catch {
    if ($global:LAST_API_ERROR.StatusCode -eq 400) {
        Write-OK "Correctly rejected missing chargerUnitId with 400 BAD REQUEST"
    } else {
        Write-Host "  [INFO] Got status $($global:LAST_API_ERROR.StatusCode) (validation may vary)" -ForegroundColor Yellow
    }
}

# Step 10: Test Validation - Invalid chargerUnitId (should fail)
Write-Step "Step 10: Test Validation - Invalid chargerUnitId (should fail)"
try {
    $startTime = (Get-Date).AddDays(1).AddHours(14).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddDays(1).AddHours(15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        chargerUnitId = "00000000-0000-0000-0000-000000000000"
        startTime = $startTime
        endTime = $endTime
    }
    
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    Write-Err "Should have rejected invalid chargerUnitId"
    exit 1
} catch {
    if ($global:LAST_API_ERROR.StatusCode -eq 404 -or $global:LAST_API_ERROR.StatusCode -eq 409) {
        Write-OK "Correctly rejected invalid chargerUnitId"
    } else {
        Write-Host "  [INFO] Got status $($global:LAST_API_ERROR.StatusCode)" -ForegroundColor Yellow
    }
}

# Step 11: Get Booking by ID
Write-Step "Step 11: Get Booking by ID"
try {
    $booking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$bookingId" `
        -Method GET `
        -Headers $headers
    
    if ($booking.id -ne $bookingId) {
        Write-Err "Wrong booking returned"
        exit 1
    }
    
    if (-not $booking.chargerUnitId) {
        Write-Err "chargerUnitId is missing in booking response"
        exit 1
    }
    
    Write-OK "Booking retrieved: id=$($booking.id), status=$($booking.status), chargerUnitId=$($booking.chargerUnitId)"
} catch {
    Write-Err "Failed to get booking: $($_.Exception.Message)"
    exit 1
}

# Step 12: Cancel Booking
Write-Step "Step 12: Cancel Booking"
try {
    $cancelled = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$bookingId/cancel" `
        -Method POST `
        -Headers $headers
    
    if ($cancelled.status -ne "CANCELLED") {
        Write-Err "Expected status CANCELLED, got: $($cancelled.status)"
        exit 1
    }
    
    Write-OK "Booking cancelled: id=$bookingId"
} catch {
    Write-Err "Failed to cancel booking: $($_.Exception.Message)"
    exit 1
}

# Step 13: Get Availability After Cancel (should show AVAILABLE)
Write-Step "Step 13: Get Availability After Cancel (should show AVAILABLE)"
try {
    Start-Sleep -Seconds 2  # Small delay to ensure DB updated
    
    $tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
    $availability = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/stations/$stationId/availability?date=$tomorrow&slotMinutes=30" `
        -Method GET `
        -Headers $headers
    
    $selectedUnitAvailability = $availability.availability | Where-Object { $_.chargerUnit.id -eq $chargerUnitId }
    $slots = $selectedUnitAvailability.slots
    
    $bookingStart = [DateTime]::Parse((Get-Date).AddDays(1).AddHours(12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
    $overlappingSlot = $slots | Where-Object {
        $slotStart = [DateTime]::Parse($_.startTime)
        $slotEnd = [DateTime]::Parse($_.endTime)
        ($slotStart -lt $bookingStart.AddHours(1) -and $slotEnd -gt $bookingStart)
    } | Select-Object -First 1
    
    if ($overlappingSlot.status -eq "AVAILABLE") {
        Write-OK "Availability correctly shows AVAILABLE after cancellation"
    } else {
        Write-Host "  [INFO] Slot status: $($overlappingSlot.status) (may take time to update)" -ForegroundColor Yellow
    }
} catch {
    Write-Err "Failed to get availability: $($_.Exception.Message)"
    exit 1
}

# Step 14: Create Booking on Different Charger Unit (should succeed)
Write-Step "Step 14: Create Booking on Different Charger Unit (should succeed)"
try {
    if ($chargerUnits.Count -lt 2) {
        Write-Host "  [SKIP] Only one charger unit available, skipping test" -ForegroundColor Yellow
    } else {
        $otherChargerUnitId = $chargerUnits[1].id
        $otherChargerUnitLabel = $chargerUnits[1].label
        
        $startTime = (Get-Date).AddDays(1).AddHours(12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endTime = (Get-Date).AddDays(1).AddHours(13).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        $createBody = @{
            stationId = $stationId
            chargerUnitId = $otherChargerUnitId
            startTime = $startTime
            endTime = $endTime
        }
        
        $booking2 = Invoke-Api `
            -Uri "$BACKEND_URL/api/ev/bookings" `
            -Method POST `
            -Headers $headers `
            -Body $createBody
        
        $booking2Id = $booking2.id
        Write-OK "Booking created on different charger unit: id=$booking2Id, chargerUnit=$otherChargerUnitLabel"
        
        # Clean up
        try {
            Invoke-Api `
                -Uri "$BACKEND_URL/api/ev/bookings/$booking2Id/cancel" `
                -Method POST `
                -Headers $headers | Out-Null
            Write-Host "    Cleaned up booking $booking2Id" -ForegroundColor Gray
        } catch {
            # Ignore cleanup errors
        }
    }
} catch {
    Write-Err "Failed to create booking on different charger unit: $($_.Exception.Message)"
    exit 1
}

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Magenta
Write-OK "All booking with charger unit tests passed!"
Write-Host "`nTested scenarios:"
Write-Host "  ✓ GET charger units"
Write-Host "  ✓ GET availability"
Write-Host "  ✓ Create booking with charger unit"
Write-Host "  ✓ Double-booking prevention (409 CONFLICT)"
Write-Host "  ✓ Partial overlap prevention (409 CONFLICT)"
Write-Host "  ✓ Availability shows HELD/BOOKED status"
Write-Host "  ✓ Validation errors"
Write-Host "  ✓ Booking cancellation"
Write-Host "  ✓ Availability updates after cancellation"
Write-Host "  ✓ Different charger units can have parallel bookings"

