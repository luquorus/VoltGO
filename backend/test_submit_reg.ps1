$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== Step 1: Register new account ===" -ForegroundColor Cyan
$regBody = '{"email":"testcollab123@gmail.com","password":"VoltGo123456","name":"Test Collab","role":"COLLABORATOR"}'
$reg = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method POST -ContentType "application/json" -Body $regBody
Write-Host "Token: $($reg.token | Select-Object -First 1)..."
$token = $reg.token
Write-Host "UserId: $($reg.userId)"
Write-Host "Role: $($reg.role)"
Write-Host ""

Write-Host "=== Step 2: Submit registration form ===" -ForegroundColor Cyan
$headers = @{"Authorization"="Bearer $token"}
$formBody = @{
    email = "testcollab123@gmail.com"
    password = "VoltGo123456"
    fullName = "Test Collab"
    phone = "0912345678"
    dateOfBirth = "1995-01-01"
    address = "123 Test St"
    idCardNumber = "123456789"
    bankAccountNumber = "1234567890"
    bankName = "VCB"
    referralCode = ""
    contractAgreedAt = "2026-06-05T10:00:00Z"
}
$jsonBody = $formBody | ConvertTo-Json -Compress
Write-Host "Request Body: $jsonBody"
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/public/registration-requests" -Method POST -ContentType "application/json" -Headers $headers -Body $jsonBody
    Write-Host "SUCCESS: $($response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $statusCode = [int]$_.Exception.Response.StatusCode
    $responseBody = ""
    try {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        $reader.Close()
    } catch {}
    Write-Host "Status: $statusCode" -ForegroundColor Red
    Write-Host "Response: $responseBody" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Check backend logs NOW ===" -ForegroundColor Yellow
