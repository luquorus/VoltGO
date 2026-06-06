# Test notification API
$ErrorActionPreference = "Continue"

Write-Host "=== Test 1: Admin Login ===" -ForegroundColor Cyan
$login = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin@local","password":"admin123"}'
$token = $login.token
Write-Host "Token received: $($token.Substring(0, [Math]::Min(50, $token.Length)))..."
Write-Host ""

Write-Host "=== Test 2: Submit Registration Request ===" -ForegroundColor Cyan
$registerBody = @{
    email = "luquorus.work@gmail.com"
    password = "VoltGo123456"
    role = "COLLABORATOR"
    fullName = "Test Collaborator"
    phone = "0912345678"
    dateOfBirth = "1995-01-01"
    address = "123 Test St"
    idCardNumber = "123456789"
    bankName = "Test Bank"
    bankAccountNumber = "1234567890"
} | ConvertTo-Json
try {
    $register = Invoke-RestMethod -Uri "http://localhost:8080/auth/register" -Method POST -ContentType "application/json" -Body $registerBody
    Write-Host "Register response: $($register | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Register error: $($_.Exception.Message)"
}
Write-Host ""

Write-Host "=== Test 3: Check Notification API Docs ===" -ForegroundColor Cyan
$docs = Invoke-RestMethod -Uri "http://localhost:8080/api/v3/api-docs" -Method GET -Headers @{"Authorization"="Bearer $token"}
Write-Host "Swagger docs available: $($docs.info.title)"
