# VoltGo - Referral System Full Flow Test
# Tests: generate code -> register with code -> create booking -> payment success -> check points
# ============================================
param(
    [string]$BackendUrl = "http://localhost:8080",
    [string]$ReferrerEmail = "test@1",
    [string]$ReferrerPassword = "Admin@123",
    [string]$StationId = "8d869123-1b11-4ea6-b308-e5a5112726c4",
    [string]$ChargerUnitId = "e62df9b3-63f5-4398-bd19-ce8921e83122"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step {
    param([string]$Msg)
    Write-Host "`n==> $Msg" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Msg)
    Write-Host "    [OK] $Msg" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Msg)
    Write-Host "    [FAIL] $Msg" -ForegroundColor Red
}

function Invoke-Api {
    param(
        [string]$Method = "GET",
        [string]$Endpoint,
        [string]$Token = $null,
        [string]$Body = $null,
        [string]$Description = ""
    )
    $headers = @{"Content-Type" = "application/json"}
    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }
    try {
        $params = @{
            Uri = "$BackendUrl$Endpoint"
            Method = $Method
            Headers = $headers
        }
        if ($Body) {
            $params.Body = $Body
        }
        $resp = Invoke-RestMethod @params -ErrorAction Stop
        return $resp
    } catch {
        $ex = $_.Exception
        $detail = $null
        $statusCode = 0
        if ($ex.Response) {
            $statusCode = [int]$ex.Response.StatusCode
            try {
                $reader = [System.IO.StreamReader]::new($ex.Response.GetResponseStream())
                $respBody = $reader.ReadToEnd()
                $reader.Close()
                $detail = $respBody
            } catch {}
        }
        if ($detail) {
            Write-Host "    HTTP $statusCode : $detail" -ForegroundColor Yellow
        } else {
            Write-Host "    Error: $($ex.Message)" -ForegroundColor Yellow
        }
        return $null
    }
}

# ============================================
# PHASE 1: Setup - Get referrer's referral code
# ============================================
Write-Host "`n========== VoltGo Referral Full-Flow Test ==========" -ForegroundColor Yellow
Write-Host "Backend: $BackendUrl"
Write-Host "Station: $StationId"
Write-Host "======================================================"

Write-Step "STEP 1: Login as referrer ($ReferrerEmail)"
$login = Invoke-Api -Method "POST" -Endpoint "/auth/login" -Body (@{email=$ReferrerEmail; password=$ReferrerPassword} | ConvertTo-Json)
if (-not $login) {
    Write-Fail "Login failed"
    exit 1
}
$referrerToken = $login.token
$referrerUserId = $login.userId
Write-Success "Logged in as referrer: $ReferrerEmail"
Write-Success "User ID: $referrerUserId"

Write-Step "STEP 2: Generate referral code for referrer"
$ref = Invoke-Api -Method "POST" -Endpoint "/api/ev/loyalty/referral/generate" -Token $referrerToken
if (-not $ref) {
    Write-Fail "Generate referral code failed"
    exit 1
}
$refCode = $ref.code
$refLink = $ref.referralLink
Write-Success "Referral code: $refCode"
Write-Success "Referral link: $refLink"

Write-Step "STEP 3: Show referrer's current loyalty profile (before)"
$profileBefore = Invoke-Api -Method "GET" -Endpoint "/api/ev/loyalty/me" -Token $referrerToken
if ($profileBefore) {
    Write-Success "Current points: $($profileBefore.currentPoints)"
    Write-Success "Lifetime points: $($profileBefore.lifetimePoints)"
}

# ============================================
# PHASE 2: Register referee with referral code
# ============================================
Write-Step "STEP 4: Register new EV user (referee) with referral code"
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$refereeEmail = "referee_$timestamp@test.com"
$refereePassword = "Ref@${timestamp}123"
Write-Host "    Email: $refereeEmail"

$reg = Invoke-Api -Method "POST" -Endpoint "/auth/register" -Body (@{
    email = $refereeEmail
    password = $refereePassword
    role = "EV_USER"
    referralCode = $refCode
} | ConvertTo-Json)
if (-not $reg) {
    Write-Fail "Registration failed"
    exit 1
}
$refereeToken = $reg.token
$refereeUserId = $reg.userId
Write-Success "Referee registered: $refereeEmail"
Write-Success "User ID: $refereeUserId"

# ============================================
# PHASE 3: Referee creates booking -> payment
# ============================================
Write-Step "STEP 5: Login as referee"
$refLogin = Invoke-Api -Method "POST" -Endpoint "/auth/login" -Body (@{email=$refereeEmail; password=$refereePassword} | ConvertTo-Json)
if (-not $refLogin) {
    Write-Fail "Referee login failed"
    exit 1
}
$refereeToken = $refLogin.token
Write-Success "Logged in as referee"

Write-Step "STEP 6: Check referee's loyalty profile (before payment - 0 points expected)"
$refProfileBefore = Invoke-Api -Method "GET" -Endpoint "/api/ev/loyalty/me" -Token $refereeToken
if ($refProfileBefore) {
    Write-Success "Referee current points: $($refProfileBefore.currentPoints)"
}

Write-Step "STEP 7: Create booking for referee"
$nowUtc = (Get-Date).ToUniversalTime()
$startTime = $nowUtc.AddMinutes(45).ToString("o")
$endTime = $nowUtc.AddHours(1).AddMinutes(45).ToString("o")
Write-Host "    Start: $startTime"
Write-Host "    End  : $endTime"
$booking = Invoke-Api -Method "POST" -Endpoint "/api/ev/bookings" -Token $refereeToken -Body (@{
    stationId = $StationId
    chargerUnitId = $ChargerUnitId
    startTime = $startTime
    endTime = $endTime
} | ConvertTo-Json)
if (-not $booking) {
    Write-Fail "Create booking failed"
    exit 1
}
$bookingId = $booking.id
$bookingStatus = $booking.status
Write-Success "Booking created: $bookingId"
Write-Success "Booking status: $bookingStatus"

Write-Step "STEP 8: Create payment intent for booking"
$intent = Invoke-Api -Method "POST" -Endpoint "/api/ev/bookings/$bookingId/payment-intent" -Token $refereeToken
if (-not $intent) {
    Write-Fail "Create payment intent failed"
    exit 1
}
$intentId = $intent.id
Write-Success "Payment intent created: $intentId"

Write-Step "STEP 9: Simulate payment success (this triggers referral bonus!)"
$paid = Invoke-Api -Method "POST" -Endpoint "/api/ev/payments/$intentId/simulate-success" -Token $refereeToken
if (-not $paid) {
    Write-Fail "Payment simulation failed"
    exit 1
}
$paymentStatus = $paid.status
$bookingAfter = Invoke-Api -Method "GET" -Endpoint "/api/ev/bookings/$bookingId" -Token $refereeToken
$bookingStatusAfter = $bookingAfter.status
Write-Success "Payment status: $paymentStatus"
Write-Success "Booking status after payment: $bookingStatusAfter"

# ============================================
# PHASE 4: Verify results
# ============================================
Write-Step "STEP 10: Verify referral status in database"
$refRows = docker exec voltgo-postgres psql -U voltgo_user -d voltgo -c "SELECT referral_code, referee_id::text, status FROM referral WHERE referral_code = '$refCode';" 2>$null
if ($refRows) {
    Write-Host $refRows -ForegroundColor White
    if ($refRows -match "REGISTERED") {
        Write-Success "Referral status: REGISTERED (referee signed up)"
    } elseif ($refRows -match "EARNED") {
        Write-Success "Referral status: EARNED (points awarded!)"
    }
}

Write-Step "STEP 11: Check referee's loyalty points after payment"
$refProfileAfter = Invoke-Api -Method "GET" -Endpoint "/api/ev/loyalty/me" -Token $refereeToken
if ($refProfileAfter) {
    Write-Success "Referee points after payment: $($refProfileAfter.currentPoints)"
    Write-Success "Referee lifetime points: $($refProfileAfter.lifetimePoints)"
    if ($refProfileAfter.lifetimePoints -gt 0) {
        Write-Success "Referee earned loyalty points!"
    }
}

Write-Step "STEP 12: Check referrer's loyalty points after referee's payment"
$profileAfter = Invoke-Api -Method "GET" -Endpoint "/api/ev/loyalty/me" -Token $referrerToken
if ($profileAfter) {
    Write-Success "Referrer points after referral: $($profileAfter.currentPoints)"
    Write-Success "Referrer lifetime points: $($profileAfter.lifetimePoints)"
}

Write-Step "STEP 13: Show all referral point transactions"
$refTx = docker exec voltgo-postgres psql -U voltgo_user -d voltgo -c "SELECT source, points, description, created_at FROM loyalty_point_transaction WHERE source = 'REFERRAL' ORDER BY created_at DESC LIMIT 5;" 2>$null
if ($refTx) {
    Write-Host $refTx -ForegroundColor White
}

# ============================================
# SUMMARY
# ============================================
Write-Host "`n==========================================" -ForegroundColor Yellow
Write-Host "            TEST SUMMARY" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Referral Code Used : $refCode" -ForegroundColor White
Write-Host "  Referee Email      : $refereeEmail" -ForegroundColor White
Write-Host "  Booking ID         : $bookingId" -ForegroundColor White
Write-Host "  Payment Intent     : $intentId" -ForegroundColor White
Write-Host "  Payment Status     : $paymentStatus" -ForegroundColor White
Write-Host "  Booking Status     : $bookingStatusAfter" -ForegroundColor White
Write-Host "  Referee Points    : $($refProfileAfter.currentPoints)" -ForegroundColor White
Write-Host "  Referrer Points    : $($profileAfter.currentPoints)" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Yellow
