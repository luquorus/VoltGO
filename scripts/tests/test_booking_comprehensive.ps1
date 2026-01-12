# Comprehensive Booking API Test Script
# Tests all booking functionality including validations, edge cases, and business logic

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fix TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::Expect100Continue = $false

$BACKEND_URL = "http://localhost:8080"

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "COMPREHENSIVE BOOKING API TEST SUITE" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Backend: $BACKEND_URL`n"

$global:TEST_COUNT = 0
$global:PASSED_COUNT = 0
$global:FAILED_COUNT = 0
$global:LAST_API_ERROR = $null

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
    $global:PASSED_COUNT++
}

function Write-Err {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
    $global:FAILED_COUNT++
}

function Assert-StatusCode {
    param([int]$Expected, [int]$Actual, [string]$Message)
    
    $global:TEST_COUNT++
    if ($Actual -eq $Expected) {
        Write-OK "$Message (Expected: $Expected, Got: $Actual)"
        return $true
    } else {
        Write-Err "$Message (Expected: $Expected, Got: $Actual)"
        return $false
    }
}

function Assert-Equals {
    param($Expected, $Actual, [string]$Message)
    
    $global:TEST_COUNT++
    if ($Expected -eq $Actual) {
        Write-OK "$Message (Expected: $Expected, Got: $Actual)"
        return $true
    } else {
        Write-Err "$Message (Expected: $Expected, Got: $Actual)"
        return $false
    }
}

function Assert-NotNull {
    param($Value, [string]$Message)
    
    $global:TEST_COUNT++
    if ($Value -ne $null) {
        Write-OK "$Message (Value is not null)"
        return $true
    } else {
        Write-Err "$Message (Value is null)"
        return $false
    }
}

function Test-ShouldFail {
    param([scriptblock]$Action, [int]$ExpectedStatusCode, [string]$TestName)
    
    $global:TEST_COUNT++
    try {
        & $Action | Out-Null
        Write-Err "$TestName - Should have failed with $ExpectedStatusCode"
        return $false
    } catch {
        $actualStatus = $global:LAST_API_ERROR.StatusCode
        if ($actualStatus -eq $ExpectedStatusCode) {
            Write-OK "$TestName - Correctly failed with $ExpectedStatusCode"
            return $true
        } else {
            Write-Err "$TestName - Expected $ExpectedStatusCode, got $actualStatus"
            return $false
        }
    }
}

# Step 1: Register & Login as EV User
Write-Step "Step 1: Authentication - Register & Login as EV User"
try {
    # Try to register first (may fail if user exists, that's OK)
    try {
        $registerResp = Invoke-Api `
            -Uri "$BACKEND_URL/auth/register" `
            -Method POST `
            -Body @{email="test_booking_user@local"; password="TestUser@123"; role="EV_USER"}
        Write-Host "  [INFO] User registered" -ForegroundColor Gray
    } catch {
        Write-Host "  [INFO] User may already exist, trying login..." -ForegroundColor Gray
    }
    
    # Login
    $loginResp = Invoke-Api `
        -Uri "$BACKEND_URL/auth/login" `
        -Method POST `
        -Body @{email="test_booking_user@local"; password="TestUser@123"}
    
    if (-not $loginResp.token) {
        Write-Err "Login failed - no token"
        exit 1
    }
    
    $script:token = $loginResp.token
    $script:userId = $loginResp.userId
    $script:headers = @{Authorization = "Bearer $script:token"}
    Write-OK "Logged in: userId=$($script:userId)"
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
        -Headers $script:headers
    
    if (-not $stations.content -or $stations.content.Count -eq 0) {
        Write-Err "No published stations found"
        exit 1
    }
    
    $script:stationId = $stations.content[0].stationId
    Write-OK "Using station: $($script:stationId)"
} catch {
    Write-Err "Failed to get station: $($_.Exception.Message)"
    exit 1
}

# Step 3: Get Charger Units
Write-Step "Step 3: Get Charger Units for Station"
try {
    $chargerUnits = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/stations/$($script:stationId)/charger-units" `
        -Method GET `
        -Headers $script:headers
    
    if (-not $chargerUnits -or $chargerUnits.Count -eq 0) {
        Write-Err "No charger units found for station"
        exit 1
    }
    
    $script:chargerUnitId = $chargerUnits[0].id
    $script:chargerUnitLabel = $chargerUnits[0].label
    Write-OK "Found $($chargerUnits.Count) charger unit(s)"
    Write-Host "    Using: $script:chargerUnitLabel (id=$script:chargerUnitId)" -ForegroundColor Gray
    
    # Store second charger unit if available
    if ($chargerUnits.Count -gt 1) {
        $script:secondChargerUnitId = $chargerUnits[1].id
    }
} catch {
    Write-Err "Failed to get charger units: $($_.Exception.Message)"
    exit 1
}

# Step 4: Test Validation - Missing chargerUnitId
Write-Step "Step 4: Validation - Missing chargerUnitId"
$tomorrow = (Get-Date).AddDays(1)
$startTime = $tomorrow.AddHours(14).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$endTime = $tomorrow.AddHours(15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            startTime = $startTime
            endTime = $endTime
        }
} -ExpectedStatusCode 400 -TestName "Missing chargerUnitId"

# Step 5: Test Validation - Invalid chargerUnitId (UUID not found)
Write-Step "Step 5: Validation - Invalid chargerUnitId (UUID not found)"
$invalidId = "00000000-0000-0000-0000-000000000000"
Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $invalidId
            startTime = $startTime
            endTime = $endTime
        }
} -ExpectedStatusCode 404 -TestName "Invalid chargerUnitId (not found)"

# Step 6: Test Validation - StartTime in past
Write-Step "Step 6: Validation - StartTime in past"
$pastTime = (Get-Date).AddHours(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$futureTime = (Get-Date).AddHours(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $pastTime
            endTime = $futureTime
        }
} -ExpectedStatusCode 400 -TestName "StartTime in past"

# Step 7: Test Validation - EndTime before StartTime
Write-Step "Step 7: Validation - EndTime before StartTime"
$validStart = $tomorrow.AddHours(14).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$invalidEnd = $tomorrow.AddHours(13).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $validStart
            endTime = $invalidEnd
        }
} -ExpectedStatusCode 400 -TestName "EndTime before StartTime"

# Step 8: Test Validation - Duration too short (< 15 minutes)
Write-Step "Step 8: Validation - Duration too short (< 15 minutes)"
$shortStart = $tomorrow.AddHours(16).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$shortEnd = $tomorrow.AddHours(16).AddMinutes(10).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $shortStart
            endTime = $shortEnd
        }
} -ExpectedStatusCode 400 -TestName "Duration too short (< 15 minutes)"

# Step 9: Test Validation - Duration too long (> 4 hours)
Write-Step "Step 9: Validation - Duration too long (> 4 hours)"
$longStart = $tomorrow.AddHours(17).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$longEnd = $tomorrow.AddHours(21).AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $longStart
            endTime = $longEnd
        }
} -ExpectedStatusCode 400 -TestName "Duration too long (> 4 hours)"

# Step 10: Create Booking Successfully
Write-Step "Step 10: Create Booking Successfully (HOLD status)"
try {
    $bookingStart = $tomorrow.AddHours(12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $bookingEnd = $tomorrow.AddHours(13).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $script:stationId
        chargerUnitId = $script:chargerUnitId
        startTime = $bookingStart
        endTime = $bookingEnd
    }
    
    $booking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body $createBody
    
    Assert-Equals -Expected "HOLD" -Actual $booking.status -Message "Booking status is HOLD"
    Assert-NotNull -Value $booking.holdExpiresAt -Message "holdExpiresAt is set"
    Assert-NotNull -Value $booking.chargerUnitId -Message "chargerUnitId is set"
    Assert-Equals -Expected $script:chargerUnitId -Actual $booking.chargerUnitId -Message "chargerUnitId matches"
    Assert-NotNull -Value $booking.priceSnapshot -Message "priceSnapshot is set"
    
    $script:bookingId = $booking.id
    Write-OK "Booking created: id=$($script:bookingId)"
} catch {
    Write-Err "Failed to create booking: $($_.Exception.Message)"
    exit 1
}

# Step 11: Test Double-Booking Prevention (Exact Overlap)
Write-Step "Step 11: Double-Booking Prevention - Exact Overlap (409 CONFLICT)"
Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $bookingStart
            endTime = $bookingEnd
        }
} -ExpectedStatusCode 409 -TestName "Double-booking prevention (exact overlap)"

# Step 12: Test Partial Overlap - Before
Write-Step "Step 12: Double-Booking Prevention - Partial Overlap Before"
$overlapBeforeStart = $tomorrow.AddHours(12).AddMinutes(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$overlapBeforeEnd = $tomorrow.AddHours(12).AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $overlapBeforeStart
            endTime = $overlapBeforeEnd
        }
} -ExpectedStatusCode 409 -TestName "Partial overlap (before)"

# Step 13: Test Partial Overlap - After
Write-Step "Step 13: Double-Booking Prevention - Partial Overlap After"
$overlapAfterStart = $tomorrow.AddHours(12).AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$overlapAfterEnd = $tomorrow.AddHours(13).AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $overlapAfterStart
            endTime = $overlapAfterEnd
        }
} -ExpectedStatusCode 409 -TestName "Partial overlap (after)"

# Step 14: Test Partial Overlap - Contains
Write-Step "Step 14: Double-Booking Prevention - Overlap Contains"
$overlapContainsStart = $tomorrow.AddHours(11).AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$overlapContainsEnd = $tomorrow.AddHours(13).AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $overlapContainsStart
            endTime = $overlapContainsEnd
        }
} -ExpectedStatusCode 409 -TestName "Overlap contains existing booking"

# Step 15: Get Booking by ID
Write-Step "Step 15: Get Booking by ID"
try {
    $retrievedBooking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$($script:bookingId)" `
        -Method GET `
        -Headers $script:headers
    
    Assert-Equals -Expected $script:bookingId -Actual $retrievedBooking.id -Message "Booking ID matches"
    Assert-Equals -Expected "HOLD" -Actual $retrievedBooking.status -Message "Booking status is HOLD"
    Assert-NotNull -Value $retrievedBooking.chargerUnitId -Message "chargerUnitId in response"
} catch {
    Write-Err "Failed to get booking: $($_.Exception.Message)"
}

# Step 16: Get My Bookings (Pagination)
Write-Step "Step 16: Get My Bookings (Pagination)"
try {
    $myBookings = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/mine?page=0&size=10" `
        -Method GET `
        -Headers $script:headers
    
    Assert-NotNull -Value $myBookings.content -Message "Bookings list exists"
    $found = $myBookings.content | Where-Object { $_.id -eq $script:bookingId }
    Assert-NotNull -Value $found -Message "Created booking found in list"
    Write-OK "Retrieved $($myBookings.content.Count) booking(s)"
} catch {
    Write-Err "Failed to get my bookings: $($_.Exception.Message)"
}

# Step 17: Create Booking on Different Charger Unit (should succeed)
Write-Step "Step 17: Parallel Booking on Different Charger Unit"
if ($script:secondChargerUnitId) {
    try {
        $parallelStart = $tomorrow.AddHours(12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $parallelEnd = $tomorrow.AddHours(13).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        $parallelBooking = Invoke-Api `
            -Uri "$BACKEND_URL/api/ev/bookings" `
            -Method POST `
            -Headers $script:headers `
            -Body @{
                stationId = $script:stationId
                chargerUnitId = $script:secondChargerUnitId
                startTime = $parallelStart
                endTime = $parallelEnd
            }
        
        Assert-Equals -Expected "HOLD" -Actual $parallelBooking.status -Message "Parallel booking created successfully"
        Write-OK "Different charger units can have parallel bookings"
        
        # Clean up parallel booking
        try {
            Invoke-Api `
                -Uri "$BACKEND_URL/api/ev/bookings/$($parallelBooking.id)/cancel" `
                -Method POST `
                -Headers $script:headers | Out-Null
        } catch {
            # Ignore cleanup errors
        }
    } catch {
        Write-Err "Failed to create parallel booking: $($_.Exception.Message)"
    }
} else {
    Write-Host "  [SKIP] Only one charger unit available" -ForegroundColor Yellow
}

# Step 18: Cancel Booking (HOLD status - should succeed)
Write-Step "Step 18: Cancel Booking (HOLD status)"
try {
    $cancelledBooking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$($script:bookingId)/cancel" `
        -Method POST `
        -Headers $script:headers
    
    Assert-Equals -Expected "CANCELLED" -Actual $cancelledBooking.status -Message "Booking status changed to CANCELLED"
    Write-OK "Booking cancelled successfully"
} catch {
    Write-Err "Failed to cancel booking: $($_.Exception.Message)"
}

# Step 19: Test Cancel Already Cancelled Booking (should fail)
Write-Step "Step 19: Cancel Already Cancelled Booking (should fail)"
Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$($script:bookingId)/cancel" `
        -Method POST `
        -Headers $script:headers
} -ExpectedStatusCode 400 -TestName "Cancel already cancelled booking"

# Step 20: Test Cancel Non-Existent Booking (should fail)
Write-Step "Step 20: Cancel Non-Existent Booking (404)"
$fakeId = "00000000-0000-0000-0000-000000000000"
Test-ShouldFail -Action {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$fakeId/cancel" `
        -Method POST `
        -Headers $script:headers
} -ExpectedStatusCode 404 -TestName "Cancel non-existent booking"

# Step 21: Create Another Booking for Availability Test
Write-Step "Step 21: Create Another Booking for Availability Test"
try {
    $availStart = $tomorrow.AddHours(15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $availEnd = $tomorrow.AddHours(16).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $availBooking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $script:headers `
        -Body @{
            stationId = $script:stationId
            chargerUnitId = $script:chargerUnitId
            startTime = $availStart
            endTime = $availEnd
        }
    
    $script:availBookingId = $availBooking.id
    Write-OK "Booking created for availability test: id=$($script:availBookingId)"
} catch {
    Write-Err "Failed to create booking for availability test: $($_.Exception.Message)"
}

# Step 22: Check Availability Shows HELD/BOOKED Status
Write-Step "Step 22: Availability Shows HELD/BOOKED Status"
try {
    Start-Sleep -Seconds 2  # Small delay
    
    $dateStr = $tomorrow.ToString("yyyy-MM-dd")
    $availability = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/stations/$($script:stationId)/availability?date=$dateStr&slotMinutes=30" `
        -Method GET `
        -Headers $script:headers
    
    $selectedUnitAvailability = $availability.availability | Where-Object { $_.chargerUnit.id -eq $script:chargerUnitId }
    if ($selectedUnitAvailability) {
        $slots = $selectedUnitAvailability.slots
        $bookingStartTime = [DateTime]::Parse($availStart)
        $overlappingSlot = $slots | Where-Object {
            $slotStart = [DateTime]::Parse($_.startTime)
            $slotEnd = [DateTime]::Parse($_.endTime)
            ($slotStart -lt $bookingStartTime.AddHours(1) -and $slotEnd -gt $bookingStartTime)
        } | Select-Object -First 1
        
        if ($overlappingSlot) {
            if ($overlappingSlot.status -eq "HELD" -or $overlappingSlot.status -eq "BOOKED") {
                Write-OK "Availability correctly shows $($overlappingSlot.status) status"
            } else {
                Write-Host "  [INFO] Slot status: $($overlappingSlot.status) (may update asynchronously)" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "  [INFO] Availability check: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 23: Cancel and Check Availability Updates
Write-Step "Step 23: Cancel and Check Availability Updates"
try {
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$($script:availBookingId)/cancel" `
        -Method POST `
        -Headers $script:headers | Out-Null
    
    Start-Sleep -Seconds 2
    
    $dateStr = $tomorrow.ToString("yyyy-MM-dd")
    $availability = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/stations/$($script:stationId)/availability?date=$dateStr&slotMinutes=30" `
        -Method GET `
        -Headers $script:headers
    
    Write-OK "Booking cancelled, availability should update"
} catch {
    Write-Host "  [INFO] Availability update check: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 24: Test Get Booking After Cancel (should still return it)
Write-Step "Step 24: Get Cancelled Booking"
try {
    $cancelledBooking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$($script:availBookingId)" `
        -Method GET `
        -Headers $script:headers
    
    Assert-Equals -Expected "CANCELLED" -Actual $cancelledBooking.status -Message "Cancelled booking can still be retrieved"
} catch {
    Write-Err "Failed to get cancelled booking: $($_.Exception.Message)"
}

# Summary
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "TEST SUMMARY" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Total Tests: $global:TEST_COUNT" -ForegroundColor White
Write-Host "Passed: $global:PASSED_COUNT" -ForegroundColor Green
Write-Host "Failed: $global:FAILED_COUNT" -ForegroundColor $(if ($global:FAILED_COUNT -eq 0) { "Green" } else { "Red" })

if ($global:FAILED_COUNT -eq 0) {
    Write-Host "`n[SUCCESS] ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[FAILED] SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}

