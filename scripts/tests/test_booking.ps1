# Test Booking MVP - Comprehensive Test Script
# Tests all booking functionality: create, list, get, cancel, expire

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fix TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::Expect100Continue = $false

$BACKEND_URL = "http://localhost:8080"

Write-Host "=== BOOKING MVP TEST ===" -ForegroundColor Magenta
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
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $body = $reader.ReadToEnd()
            Write-Host "  Response: $body" -ForegroundColor Red
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
            -Body @{email="evuser@test.local"; password="EvUser@123"; role="EV_USER"}
        Write-OK "User registered: evuser@test.local"
    } catch {
        Write-Host "  [INFO] User may already exist, trying login..." -ForegroundColor Yellow
    }
    
    # Login
    $loginResp = Invoke-Api `
        -Uri "$BACKEND_URL/auth/login" `
        -Method POST `
        -Body @{email="evuser@test.local"; password="EvUser@123"}
    
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

# Step 3: Create Booking (HOLD)
Write-Step "Step 3: Create Booking (HOLD)"
try {
    $startTime = (Get-Date).AddHours(2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddHours(3).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
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
    
    $bookingId = $booking.id
    Write-OK "Booking created: id=$bookingId, status=HOLD"
    Write-Host "    holdExpiresAt: $($booking.holdExpiresAt)"
} catch {
    Write-Err "Failed to create booking: $($_.Exception.Message)"
    exit 1
}

# Step 4: Get My Bookings
Write-Step "Step 4: Get My Bookings"
try {
    $bookings = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/mine?page=0&size=10" `
        -Method GET `
        -Headers $headers
    
    if ($bookings.content.Count -eq 0) {
        Write-Err "No bookings found"
        exit 1
    }
    
    $found = $bookings.content | Where-Object { $_.id -eq $bookingId }
    if (-not $found) {
        Write-Err "Created booking not found in list"
        exit 1
    }
    
    Write-OK "Found $($bookings.content.Count) booking(s)"
} catch {
    Write-Err "Failed to get bookings: $($_.Exception.Message)"
    exit 1
}

# Step 5: Get Booking by ID
Write-Step "Step 5: Get Booking by ID"
try {
    $booking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$bookingId" `
        -Method GET `
        -Headers $headers
    
    if ($booking.id -ne $bookingId) {
        Write-Err "Wrong booking returned"
        exit 1
    }
    
    Write-OK "Booking retrieved: id=$($booking.id), status=$($booking.status)"
} catch {
    Write-Err "Failed to get booking: $($_.Exception.Message)"
    exit 1
}

# Step 6: Cancel Booking
Write-Step "Step 6: Cancel Booking"
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

# Step 7: Try to cancel already cancelled booking (should fail)
Write-Step "Step 7: Try Cancel Already Cancelled (should fail)"
try {
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$bookingId/cancel" `
        -Method POST `
        -Headers $headers
    
    Write-Err "Should have failed to cancel already cancelled booking"
    exit 1
} catch {
    Write-OK "Correctly rejected cancel of CANCELLED booking"
}

# Step 8: Create another booking for expire test
Write-Step "Step 8: Create Another Booking for Expire Test"
try {
    $startTime = (Get-Date).AddHours(4).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddHours(5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        startTime = $startTime
        endTime = $endTime
    }
    
    $booking2 = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    $booking2Id = $booking2.id
    Write-OK "Second booking created: id=$booking2Id, status=HOLD"
    Write-Host "    This booking will expire in 10 minutes if not paid"
} catch {
    Write-Err "Failed to create second booking: $($_.Exception.Message)"
    exit 1
}

# Step 9: Test validation - startTime in past (should fail)
Write-Step "Step 9: Test Validation - startTime in Past (should fail)"
try {
    $pastTime = (Get-Date).AddHours(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $futureTime = (Get-Date).AddHours(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $invalidBody = @{
        stationId = $stationId
        startTime = $pastTime
        endTime = $futureTime
    }
    
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $invalidBody
    
    Write-Err "Should have rejected startTime in past"
    exit 1
} catch {
    Write-OK "Correctly rejected startTime in past"
}

# Step 10: Test validation - endTime before startTime (should fail)
Write-Step "Step 10: Test Validation - endTime before startTime (should fail)"
try {
    $startTime = (Get-Date).AddHours(6).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddHours(5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $invalidBody = @{
        stationId = $stationId
        startTime = $startTime
        endTime = $endTime
    }
    
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $invalidBody
    
    Write-Err "Should have rejected endTime before startTime"
    exit 1
} catch {
    Write-OK "Correctly rejected endTime before startTime"
}

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Magenta
Write-OK "All booking tests passed!"
Write-Host "`nNote: Scheduler will expire HOLD bookings every 1 minute."
Write-Host "      Check booking $booking2Id after 10 minutes to verify expiration."

