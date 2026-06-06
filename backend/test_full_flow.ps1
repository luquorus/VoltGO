$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8080"
$email = "testcollab456@gmail.com"

Write-Host "=== Step 1: Register account ===" -ForegroundColor Cyan
$regBody = @{
    email = $email
    password = "VoltGo123456"
    name = "Test Collab"
    role = "COLLABORATOR"
} | ConvertTo-Json
$reg = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method POST -ContentType "application/json" -Body $regBody
$token = $reg.token
Write-Host "OK - Token: $($token.Substring(0, [Math]::Min(30, $token.Length)))..." -ForegroundColor Green

Write-Host ""
Write-Host "=== Step 2: Submit registration form ===" -ForegroundColor Cyan
$headers = @{"Authorization"="Bearer $token"}
$formBody = @{
    email = $email
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
} | ConvertTo-Json
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/public/registration-requests" -Method POST -ContentType "application/json" -Headers $headers -Body $formBody
    Write-Host "OK - Request ID: $($response.id)" -ForegroundColor Green
    Write-Host "Message: $($response.message)" -ForegroundColor Green
} catch {
    $statusCode = [int]$_.Exception.Response.StatusCode
    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
    $body = $reader.ReadToEnd()
    $reader.Close()
    Write-Host "ERROR $statusCode : $body" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Step 3: Admin approves ===" -ForegroundColor Cyan
$adminHeaders = @{"Authorization"="Bearer "}
$adminLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin@local","password":"Admin@123"}'
$adminToken = $adminLogin.token
$adminHeaders = @{"Authorization"="Bearer $adminToken"}
$reqs = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests?status=PENDING&page=0&size=20" -Method GET -Headers $adminHeaders
$newReq = $reqs.content | Where-Object { $_.email -eq $email }
if ($newReq) {
    Write-Host "Found pending request: $($newReq.id)" -ForegroundColor Green
    $approve = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$($newReq.id)/approve" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body '{"region":"Ha Noi","note":"Test"}'
    Write-Host "APPROVED: $($approve.status)" -ForegroundColor Green
} else {
    Write-Host "No pending request found for $email" -ForegroundColor Yellow
    Write-Host "All requests:" -ForegroundColor Yellow
    $reqs.content | ForEach-Object { Write-Host "  $($_.email) | $($_.status)" }
}
