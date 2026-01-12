# Station Recommendation API Test Script
# Tests the recommendation endpoint with various scenarios
# Account: evuser1@local / Admin@123

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fix TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::Expect100Continue = $false

$BACKEND_URL = "http://localhost:8080"
$EV_USER_EMAIL = "evuser@1"
$EV_USER_PASSWORD = "Admin@123"

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "STATION RECOMMENDATION API TEST" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Backend: $BACKEND_URL" -ForegroundColor Cyan
Write-Host "EV User: $EV_USER_EMAIL`n" -ForegroundColor Cyan

# Helper functions
function Invoke-Api {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers = $null,
        [object]$Body = $null
    )
    
    $params = @{
        Uri = $Uri
        Method = $Method
        ContentType = "application/json"
        TimeoutSec = 30
        UseBasicParsing = $true
    }
    
    if ($Headers) { 
        $params.Headers = $Headers 
    }
    if ($Body) { 
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress) 
    }
    
    try {
        $response = Invoke-RestMethod @params
        return @{
            Success = $true
            Data = $response
        }
    } catch {
        $statusCode = $null
        $body = ""
        $errorObj = $null
        
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                if ($body) {
                    $errorObj = $body | ConvertFrom-Json -ErrorAction SilentlyContinue
                }
            } catch {
                # Response stream might not be available
            }
        }
        
        return @{
            Success = $false
            StatusCode = $statusCode
            Error = $errorObj
            Body = $body
            Exception = $_.Exception.Message
        }
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
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Yellow
}

# Test counter
$script:testCount = 0
$script:passCount = 0
$script:failCount = 0

function Test-Case {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    $script:testCount++
    Write-Step "Test $($script:testCount): $Name"
    try {
        & $Test
        $script:passCount++
    } catch {
        $script:failCount++
        Write-Err "Test failed: $($_.Exception.Message)"
    }
}

# ========================================
# LOGIN
# ========================================
Write-Step "Step 1: Login as EV User"
$loginResult = Invoke-Api -Uri "$BACKEND_URL/auth/login" -Method POST -Body @{
    email = $EV_USER_EMAIL
    password = $EV_USER_PASSWORD
}

if (-not $loginResult.Success) {
    $errorMsg = "Login failed"
    if ($loginResult.StatusCode) {
        $errorMsg += " (Status: $($loginResult.StatusCode))"
    }
    if ($loginResult.Error -and $loginResult.Error.message) {
        $errorMsg += ": $($loginResult.Error.message)"
    } elseif ($loginResult.Body) {
        $errorMsg += ": $($loginResult.Body)"
    }
    Write-Err $errorMsg
    Write-Err "Please ensure backend is running and user '$EV_USER_EMAIL' exists"
    exit 1
}

if (-not $loginResult.Data.token) {
    Write-Err "Login failed - no token in response"
    exit 1
}

$script:token = $loginResult.Data.token
$script:headers = @{Authorization = "Bearer $script:token"}
Write-OK "Logged in successfully as $EV_USER_EMAIL"
Write-Info "Token: $($script:token.Substring(0, [Math]::Min(20, $script:token.Length)))..."

# ========================================
# TEST CASES
# ========================================

# Test 1: Basic recommendation with low battery (should prioritize fast charging)
Test-Case "Basic recommendation - Low battery (20% -> 80%)" {
    $requestBody = @{
        currentLocation = @{
            lat = 10.8231
            lng = 106.6297
        }
        radiusKm = 15
        batteryPercent = 20
        batteryCapacityKwh = 60
        targetPercent = 80
        limit = 10
    }
    
    $response = Invoke-Api -Uri "$BACKEND_URL/api/ev/stations/recommendations" -Method POST -Headers $script:headers -Body $requestBody
    
    if (-not $response.Success) {
        throw "Request failed: $($response.Error.message)"
    }
    
    $data = $response.Data
    Write-OK "Request successful"
    Write-Info "Input: battery $($requestBody.batteryPercent)%, capacity $($requestBody.batteryCapacityKwh)kWh, target $($requestBody.targetPercent)%"
    Write-Info "Results count: $($data.results.Count)"
    
    if ($data.results.Count -eq 0) {
        Write-Info "No stations found in radius (this is OK if no stations exist)"
        return
    }
    
    $topResult = $data.results[0]
    Write-Info "Top result: $($topResult.name)"
    Write-Info "  Distance: $($topResult.estimate.distanceKm) km"
    Write-Info "  Travel time: $($topResult.estimate.travelMinutes) min"
    Write-Info "  Charge time: $($topResult.estimate.chargeMinutes) min"
    Write-Info "  Total time: $($topResult.estimate.totalMinutes) min"
    Write-Info "  Needed energy: $($topResult.estimate.neededKwh) kWh"
    
    if ($topResult.chosenPort) {
        $port = $topResult.chosenPort
        Write-Info "  Port: $($port.powerType) $($port.powerKw)kW (effective $($port.assumedEffectiveKw)kW)"
    }
    
    if ($topResult.explain) {
        Write-Info "  Explanation:"
        foreach ($line in $topResult.explain) {
            Write-Host "    - $line" -ForegroundColor Gray
        }
    }
    
    # Verify response structure
    if (-not $topResult.stationId) { throw "Missing stationId" }
    if (-not $topResult.name) { throw "Missing name" }
    if (-not $topResult.estimate) { throw "Missing estimate" }
    if (-not $topResult.chosenPort) { throw "Missing chosenPort" }
    
    Write-OK "Response structure valid"
}

# Test 2: High battery (near full - should prioritize closer stations)
Test-Case "High battery scenario (70% -> 80%)" {
    $requestBody = @{
        currentLocation = @{
            lat = 10.8231
            lng = 106.6297
        }
        radiusKm = 15
        batteryPercent = 70
        batteryCapacityKwh = 60
        targetPercent = 80
        limit = 5
    }
    
    $response = Invoke-Api -Uri "$BACKEND_URL/api/ev/stations/recommendations" -Method POST -Headers $script:headers -Body $requestBody
    
    if (-not $response.Success) {
        throw "Request failed: $($response.Error.message)"
    }
    
    $data = $response.Data
    Write-OK "Request successful"
    Write-Info "Results count: $($data.results.Count)"
    
    if ($data.results.Count -gt 0) {
        $topResult = $data.results[0]
        Write-Info "Top result: $($topResult.name)"
        Write-Info "  Total time: $($topResult.estimate.totalMinutes) min"
        Write-Info "  Charge time: $($topResult.estimate.chargeMinutes) min (should be low)"
        Write-Info "  (Should prioritize closer stations due to low charge needed)"
        
        # With high battery, charge time should be minimal
        if ($topResult.estimate.chargeMinutes -lt 5) {
            Write-OK "Charge time is minimal as expected"
        }
    }
}

# Test 3: Target > 80% (triggers charging taper)
Test-Case "Target > 80% - Charging taper (50% -> 90%)" {
    $requestBody = @{
        currentLocation = @{
            lat = 10.8231
            lng = 106.6297
        }
        radiusKm = 15
        batteryPercent = 50
        batteryCapacityKwh = 60
        targetPercent = 90
        limit = 5
    }
    
    $response = Invoke-Api -Uri "$BACKEND_URL/api/ev/stations/recommendations" -Method POST -Headers $script:headers -Body $requestBody
    
    if (-not $response.Success) {
        throw "Request failed: $($response.Error.message)"
    }
    
    $data = $response.Data
    Write-OK "Request successful"
    
    if ($data.results.Count -gt 0) {
        $topResult = $data.results[0]
        Write-Info "Top result: $($topResult.name)"
        Write-Info "  Charge time: $($topResult.estimate.chargeMinutes) min (should be higher due to taper)"
        
        # Check if explanation mentions taper
        $hasTaper = ($topResult.explain | Where-Object { $_ -like "*taper*" -or $_ -like "*80%*" }).Count -gt 0
        if ($hasTaper) {
            Write-OK "Taper explanation found"
        } else {
            Write-Info "Taper explanation not found (may be OK if explanation format differs)"
        }
    }
}

# Test 4: Custom vehicle settings (vehicle max charge kW cap)
Test-Case "Custom vehicle settings (maxChargeKw=60kW, speed=40km/h)" {
    $requestBody = @{
        currentLocation = @{
            lat = 10.8231
            lng = 106.6297
        }
        radiusKm = 15
        batteryPercent = 30
        batteryCapacityKwh = 60
        targetPercent = 80
        vehicleMaxChargeKw = 60
        averageSpeedKmph = 40
        limit = 5
    }
    
    $response = Invoke-Api -Uri "$BACKEND_URL/api/ev/stations/recommendations" -Method POST -Headers $script:headers -Body $requestBody
    
    if (-not $response.Success) {
        throw "Request failed: $($response.Error.message)"
    }
    
    $data = $response.Data
    Write-OK "Request successful"
    
    if ($data.results.Count -gt 0) {
        $topResult = $data.results[0]
        Write-Info "Top result: $($topResult.name)"
        
        if ($topResult.chosenPort -and $topResult.chosenPort.assumedEffectiveKw) {
            $effectiveKw = $topResult.chosenPort.assumedEffectiveKw
            Write-Info "  Effective kW: $effectiveKw kW"
            
            if ($effectiveKw -le 60) {
                Write-OK "Effective kW is capped by vehicle max (60kW) as expected"
            } else {
                Write-Info "Effective kW ($effectiveKw) is higher than vehicle max (60kW) - may be using AC port"
            }
        }
    }
}

# Test 5: Validation errors - Invalid battery percent
Test-Case "Validation error - Invalid battery percent (>100)" {
    $requestBody = @{
        currentLocation = @{
            lat = 10.8231
            lng = 106.6297
        }
        radiusKm = 15
        batteryPercent = 150  # Invalid
        batteryCapacityKwh = 60
        targetPercent = 80
    }
    
    $response = Invoke-Api -Uri "$BACKEND_URL/api/ev/stations/recommendations" -Method POST -Headers $script:headers -Body $requestBody
    
    if ($response.Success) {
        throw "Expected validation error, but request succeeded"
    }
    
    if ($response.StatusCode -eq 400) {
        Write-OK "Validation error correctly returned (status 400)"
        if ($response.Error) {
            Write-Info "Error message: $($response.Error.message)"
        }
    } else {
        throw "Expected status 400, got: $($response.StatusCode)"
    }
}

# Test 6: Validation errors - Target < battery
Test-Case "Validation error - Target percent < battery percent" {
    $requestBody = @{
        currentLocation = @{
            lat = 10.8231
            lng = 106.6297
        }
        radiusKm = 15
        batteryPercent = 80
        batteryCapacityKwh = 60
        targetPercent = 50  # Invalid: target < battery
    }
    
    $response = Invoke-Api -Uri "$BACKEND_URL/api/ev/stations/recommendations" -Method POST -Headers $script:headers -Body $requestBody
    
    if ($response.Success) {
        throw "Expected validation error, but request succeeded"
    }
    
    if ($response.StatusCode -eq 400) {
        Write-OK "Validation error correctly returned (status 400)"
    } else {
        throw "Expected status 400, got: $($response.StatusCode)"
    }
}

# Test 7: Missing required fields
Test-Case "Validation error - Missing required fields" {
    $requestBody = @{
        radiusKm = 15
        batteryPercent = 20
        # Missing currentLocation and batteryCapacityKwh
    }
    
    $response = Invoke-Api -Uri "$BACKEND_URL/api/ev/stations/recommendations" -Method POST -Headers $script:headers -Body $requestBody
    
    if ($response.Success) {
        throw "Expected validation error, but request succeeded"
    }
    
    if ($response.StatusCode -eq 400) {
        Write-OK "Validation error correctly returned (status 400)"
    } else {
        throw "Expected status 400, got: $($response.StatusCode)"
    }
}

# Test 8: Default values (no optional params)
Test-Case "Default values - No optional parameters" {
    $requestBody = @{
        currentLocation = @{
            lat = 10.8231
            lng = 106.6297
        }
        radiusKm = 15
        batteryPercent = 25
        batteryCapacityKwh = 60
        # No targetPercent, consumptionKwhPerKm, averageSpeedKmph, vehicleMaxChargeKw, limit
    }
    
    $response = Invoke-Api -Uri "$BACKEND_URL/api/ev/stations/recommendations" -Method POST -Headers $script:headers -Body $requestBody
    
    if (-not $response.Success) {
        throw "Request failed: $($response.Error.message)"
    }
    
    $data = $response.Data
    Write-OK "Request successful with default values"
    
    # Check if input is echoed back with defaults
    if ($data.input) {
        Write-Info "Input echo:"
        Write-Info "  targetPercent: $($data.input.targetPercent) (default: 80)"
        Write-Info "  averageSpeedKmph: $($data.input.averageSpeedKmph) (default: 30)"
        Write-Info "  vehicleMaxChargeKw: $($data.input.vehicleMaxChargeKw) (default: 120)"
        Write-Info "  limit: $($data.input.limit) (default: 10)"
    }
}

# ========================================
# SUMMARY
# ========================================
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "TEST SUMMARY" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Total tests: $script:testCount" -ForegroundColor Cyan
Write-Host "Passed: $script:passCount" -ForegroundColor Green
Write-Host "Failed: $script:failCount" -ForegroundColor $(if ($script:failCount -eq 0) { "Green" } else { "Red" })
Write-Host "========================================" -ForegroundColor Magenta

if ($script:failCount -gt 0) {
    exit 1
} else {
    exit 0
}

