# Test script for Collaborator Self-Registration API
# Run this after starting the backend server

$BASE_URL = "http://localhost:8080"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Testing Collaborator Registration APIs" -ForegroundColor Cyan
Write-Host "======================================"
Write-Host ""

# Helper function for API calls
function Call-Api {
    param(
        [string]$Method,
        [string]$Endpoint,
        [string]$Data = $null,
        [string]$Token = $null
    )
    
    $headers = @{"Content-Type" = "application/json"}
    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }
    
    if ($Data) {
        $response = Invoke-RestMethod -Uri "$BASE_URL$Endpoint" -Method $Method -Headers $headers -Body $Data
    } else {
        $response = Invoke-RestMethod -Uri "$BASE_URL$Endpoint" -Method $Method -Headers $headers
    }
    
    return $response
}

Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "1. Testing Submit Registration Request" -ForegroundColor Yellow
Write-Host "----------------------------------------"

$REGISTER_DATA = @{
    email = "test.collaborator@example.com"
    password = "Password123"
    fullName = "Nguyen Van Test"
    phone = "0912345678"
    dateOfBirth = "2000-01-01"
    address = "123 Nguyen Trai, Ha Noi"
    idCardNumber = "001234567890"
    bankAccountNumber = "1234567890"
    bankName = "Vietcombank"
    contractAgreedAt = "2026-06-05T00:00:00Z"
}

$jsonData = $REGISTER_DATA | ConvertTo-Json

Write-Host "Submitting registration request..."
try {
    $response = Invoke-RestMethod -Uri "$BASE_URL/api/public/registration-requests" -Method POST -Headers @{"Content-Type" = "application/json"} -Body $jsonData
    Write-Host "Response:" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 10
    
    $script:REQUEST_ID = $response.id
    Write-Host "Request ID: $REQUEST_ID" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "2. Testing Get Registration Request Status (Public)" -ForegroundColor Yellow
Write-Host "----------------------------------------"

if ($REQUEST_ID) {
    Write-Host "Getting request status for ID: $REQUEST_ID"
    try {
        $response = Invoke-RestMethod -Uri "$BASE_URL/api/public/registration-requests/$REQUEST_ID" -Method GET -Headers @{"Content-Type" = "application/json"}
        Write-Host "Response:" -ForegroundColor Green
        $response | ConvertTo-Json -Depth 10
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Skipped - no REQUEST_ID" -ForegroundColor Gray
}

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "3. Testing DOB Validation (Under 18)" -ForegroundColor Yellow
Write-Host "----------------------------------------"

$UNDERAGE_DATA = @{
    email = "underage@example.com"
    password = "Password123"
    fullName = "Too Young"
    phone = "0912345678"
    dateOfBirth = "2015-01-01"
    address = "123 Test, Ha Noi"
    idCardNumber = "001234567890"
    bankAccountNumber = "1234567890"
    bankName = "Vietcombank"
    contractAgreedAt = "2026-06-05T00:00:00Z"
}

$jsonUnderage = $UNDERAGE_DATA | ConvertTo-Json

Write-Host "Submitting underage registration..."
try {
    $response = Invoke-RestMethod -Uri "$BASE_URL/api/public/registration-requests" -Method POST -Headers @{"Content-Type" = "application/json"} -Body $jsonUnderage
    Write-Host "Response:" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 10
} catch {
    $errorResponse = $_.Exception.Response
    if ($errorResponse.StatusCode -eq 400) {
        Write-Host "Validation Error (expected): 400 Bad Request" -ForegroundColor Yellow
    } else {
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Admin endpoints require authentication" -ForegroundColor Yellow
Write-Host "To test admin endpoints:" -ForegroundColor Yellow
Write-Host "1. Login as admin first" -ForegroundColor Yellow
Write-Host "2. Get JWT token" -ForegroundColor Yellow
Write-Host "3. Run admin-specific tests" -ForegroundColor Yellow
Write-Host "======================================"

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "Sample Admin API Tests (after login)" -ForegroundColor Yellow
Write-Host "----------------------------------------"

Write-Host "GET /api/admin/registration-requests?status=PENDING&page=0&size=20"
Write-Host "GET /api/admin/registration-requests/{id}"
Write-Host "POST /api/admin/registration-requests/{id}/approve"
Write-Host "     Body: {`"region`": `"Hanoi`", `"note`": `"Approved by test`"}"
Write-Host "POST /api/admin/registration-requests/{id}/reject"
Write-Host "     Body: {`"reason`": `"Missing documents`"}"
Write-Host "GET /api/admin/registration-requests/pending-count"

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Test completed" -ForegroundColor Cyan
Write-Host "======================================"
