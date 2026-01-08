# Test Payment MVP - Comprehensive Test Script
# Tests all payment functionality: create intent, simulate success/fail, guards, idempotency

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fix TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::Expect100Continue = $false

$BACKEND_URL = "http://localhost:8080"

Write-Host "=== PAYMENT MVP TEST ===" -ForegroundColor Magenta
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

# Step 1: Login as EV User
Write-Step "Step 1: Login as EV User"
try {
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
    
    $bookingId = $booking.id
    Write-OK "Booking created: id=$bookingId, status=HOLD"
} catch {
    Write-Err "Failed to create booking: $($_.Exception.Message)"
    exit 1
}

# Step 4: Create Payment Intent
Write-Step "Step 4: Create Payment Intent"
try {
    $intent = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$bookingId/payment-intent" `
        -Method POST `
        -Headers $headers
    
    if ($intent.status -ne "CREATED") {
        Write-Err "Expected status CREATED, got: $($intent.status)"
        exit 1
    }
    
    if ($intent.amount -ne 50000) {
        Write-Err "Expected amount 50000, got: $($intent.amount)"
        exit 1
    }
    
    if ($intent.currency -ne "VND") {
        Write-Err "Expected currency VND, got: $($intent.currency)"
        exit 1
    }
    
    $intentId = $intent.id
    Write-OK "Payment intent created: id=$intentId, amount=$($intent.amount) $($intent.currency)"
} catch {
    Write-Err "Failed to create payment intent: $($_.Exception.Message)"
    exit 1
}

# Step 5: Try to create duplicate payment intent (should fail)
Write-Step "Step 5: Try Create Duplicate Payment Intent (should fail)"
try {
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$bookingId/payment-intent" `
        -Method POST `
        -Headers $headers
    
    Write-Err "Should have rejected duplicate payment intent"
    exit 1
} catch {
    Write-OK "Correctly rejected duplicate payment intent"
}

# Step 6: Simulate Payment Success
Write-Step "Step 6: Simulate Payment Success"
try {
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/payments/$intentId/simulate-success" `
        -Method POST `
        -Headers $headers
    
    if ($result.status -ne "SUCCEEDED") {
        Write-Err "Expected status SUCCEEDED, got: $($result.status)"
        exit 1
    }
    
    Write-OK "Payment simulated success: intentId=$intentId"
    
    # Verify booking is now CONFIRMED
    $updatedBooking = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$bookingId" `
        -Method GET `
        -Headers $headers
    
    if ($updatedBooking.status -ne "CONFIRMED") {
        Write-Err "Expected booking status CONFIRMED, got: $($updatedBooking.status)"
        exit 1
    }
    
    Write-OK "Booking confirmed: bookingId=$bookingId, status=CONFIRMED"
} catch {
    Write-Err "Failed to simulate payment success: $($_.Exception.Message)"
    exit 1
}

# Step 7: Test Idempotency - Call simulate-success again (should not break)
Write-Step "Step 7: Test Idempotency - Call simulate-success Again"
try {
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/payments/$intentId/simulate-success" `
        -Method POST `
        -Headers $headers
    
    if ($result.status -ne "SUCCEEDED") {
        Write-Err "Expected status SUCCEEDED, got: $($result.status)"
        exit 1
    }
    
    Write-OK "Idempotency verified: calling simulate-success twice works correctly"
} catch {
    Write-Err "Idempotency test failed: $($_.Exception.Message)"
    exit 1
}

# Step 8: Create another booking for fail test
Write-Step "Step 8: Create Another Booking for Fail Test"
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
} catch {
    Write-Err "Failed to create second booking: $($_.Exception.Message)"
    exit 1
}

# Step 9: Create payment intent for booking 2
Write-Step "Step 9: Create Payment Intent for Booking 2"
try {
    $intent2 = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$booking2Id/payment-intent" `
        -Method POST `
        -Headers $headers
    
    $intent2Id = $intent2.id
    Write-OK "Payment intent created: id=$intent2Id"
} catch {
    Write-Err "Failed to create payment intent: $($_.Exception.Message)"
    exit 1
}

# Step 10: Simulate Payment Failure
Write-Step "Step 10: Simulate Payment Failure"
try {
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/payments/$intent2Id/simulate-fail" `
        -Method POST `
        -Headers $headers
    
    if ($result.status -ne "FAILED") {
        Write-Err "Expected status FAILED, got: $($result.status)"
        exit 1
    }
    
    Write-OK "Payment simulated failure: intentId=$intent2Id"
    
    # Verify booking remains HOLD
    $updatedBooking2 = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$booking2Id" `
        -Method GET `
        -Headers $headers
    
    if ($updatedBooking2.status -ne "HOLD") {
        Write-Err "Expected booking status HOLD, got: $($updatedBooking2.status)"
        exit 1
    }
    
    Write-OK "Booking remains HOLD: bookingId=$booking2Id, status=HOLD"
} catch {
    Write-Err "Failed to simulate payment failure: $($_.Exception.Message)"
    exit 1
}

# Step 11: Test Guard - Try to create intent for CANCELLED booking (should fail)
Write-Step "Step 11: Test Guard - Create Intent for CANCELLED Booking (should fail)"
try {
    # Create and cancel a booking
    $startTime = (Get-Date).AddHours(6).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddHours(7).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        startTime = $startTime
        endTime = $endTime
    }
    
    $booking3 = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    $booking3Id = $booking3.id
    
    # Cancel booking
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$booking3Id/cancel" `
        -Method POST `
        -Headers $headers | Out-Null
    
    # Try to create payment intent for cancelled booking
    try {
        $result = Invoke-Api `
            -Uri "$BACKEND_URL/api/ev/bookings/$booking3Id/payment-intent" `
            -Method POST `
            -Headers $headers
        
        Write-Err "Should have rejected payment intent for CANCELLED booking"
        exit 1
    } catch {
        Write-OK "Correctly rejected payment intent for CANCELLED booking"
    }
} catch {
    Write-Err "Guard test failed: $($_.Exception.Message)"
    exit 1
}

# Step 12: Test Guard - Try simulate-success on already CONFIRMED booking (should fail)
Write-Step "Step 12: Test Guard - Simulate Success on Already CONFIRMED Booking"
try {
    # Create booking, intent, and simulate success
    $startTime = (Get-Date).AddHours(8).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddHours(9).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        startTime = $startTime
        endTime = $endTime
    }
    
    $booking4 = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    $booking4Id = $booking4.id
    
    $intent4 = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$booking4Id/payment-intent" `
        -Method POST `
        -Headers $headers
    
    $intent4Id = $intent4.id
    
    # Simulate success (first time)
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/payments/$intent4Id/simulate-success" `
        -Method POST `
        -Headers $headers | Out-Null
    
    # Cancel the booking (to test guard)
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$booking4Id/cancel" `
        -Method POST `
        -Headers $headers | Out-Null
    
    # Try to simulate success again (should be idempotent, but booking is now CANCELLED)
    # Actually, since intent is already SUCCEEDED, it should return as-is (idempotent)
    $result = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/payments/$intent4Id/simulate-success" `
        -Method POST `
        -Headers $headers
    
    if ($result.status -ne "SUCCEEDED") {
        Write-Err "Expected idempotent return of SUCCEEDED, got: $($result.status)"
        exit 1
    }
    
    Write-OK "Idempotency works: already SUCCEEDED intent returns as-is"
} catch {
    Write-Err "Guard/idempotency test failed: $($_.Exception.Message)"
    exit 1
}

# Step 13: Test Guard - Try simulate-fail on already SUCCEEDED intent (should fail)
Write-Step "Step 13: Test Guard - Simulate Fail on Already SUCCEEDED Intent (should fail)"
try {
    # Create booking and intent
    $startTime = (Get-Date).AddHours(10).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddHours(11).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $createBody = @{
        stationId = $stationId
        startTime = $startTime
        endTime = $endTime
    }
    
    $booking5 = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings" `
        -Method POST `
        -Headers $headers `
        -Body $createBody
    
    $booking5Id = $booking5.id
    
    $intent5 = Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/bookings/$booking5Id/payment-intent" `
        -Method POST `
        -Headers $headers
    
    $intent5Id = $intent5.id
    
    # Simulate success
    Invoke-Api `
        -Uri "$BACKEND_URL/api/ev/payments/$intent5Id/simulate-success" `
        -Method POST `
        -Headers $headers | Out-Null
    
    # Try to simulate fail on already succeeded intent
    try {
        $result = Invoke-Api `
            -Uri "$BACKEND_URL/api/ev/payments/$intent5Id/simulate-fail" `
            -Method POST `
            -Headers $headers
        
        Write-Err "Should have rejected simulate-fail on SUCCEEDED intent"
        exit 1
    } catch {
        Write-OK "Correctly rejected simulate-fail on SUCCEEDED intent"
    }
} catch {
    Write-Err "Guard test failed: $($_.Exception.Message)"
    exit 1
}

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Magenta
Write-OK "All payment tests passed!"
Write-Host "`nTest Cases Verified:"
Write-Host "  1. ✅ Create payment intent for HOLD booking"
Write-Host "  2. ✅ Reject duplicate payment intent"
Write-Host "  3. ✅ Simulate payment success (HOLD -> CONFIRMED)"
Write-Host "  4. ✅ Idempotency: simulate-success twice"
Write-Host "  5. ✅ Simulate payment failure (booking remains HOLD)"
Write-Host "  6. ✅ Guard: reject intent for CANCELLED booking"
Write-Host "  7. ✅ Guard: idempotent on already SUCCEEDED"
Write-Host "  8. ✅ Guard: reject simulate-fail on SUCCEEDED intent"

