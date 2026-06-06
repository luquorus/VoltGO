$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== Test: Register New Collaborator (luquorusmail@gmail.com) ===" -ForegroundColor Cyan
$regBody = '{"email":"luquorusmail@gmail.com","password":"VoltGo123456","fullName":"Quoc Luu","phone":"0912345678","dateOfBirth":"1990-01-01","address":"123 Test St","idCardNumber":"123456789","bankName":"VCB","bankAccountNumber":"1234567890","referralCode":"","contractAgreedAt":"2026-06-05T10:00:00Z"}'
$reg = Invoke-RestMethod -Uri "$baseUrl/api/public/registration-requests" -Method POST -ContentType "application/json" -Body $regBody
Write-Host "Register: $($reg | ConvertTo-Json)"
Write-Host ""

Write-Host "=== Test: Admin Login ===" -ForegroundColor Cyan
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin@local","password":"Admin@123"}'
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}
Write-Host "Admin login OK"
Write-Host ""

Write-Host "=== Test: Approve Registration ===" -ForegroundColor Cyan
$reqs = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests?status=PENDING&page=0&size=20" -Method GET -Headers $headers
$newReq = $reqs.content | Where-Object { $_.email -eq "luquorusmail@gmail.com" }
if ($newReq) {
    Write-Host "Found request: $($newReq.id)" -ForegroundColor Green
    $approve = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$($newReq.id)/approve" -Method POST -Headers $headers -ContentType "application/json" -Body '{"region":"Ha Noi","note":"Test real email - sending to luquorusmail@gmail.com"}'
    Write-Host "Approved: status=$($approve.status)"
    Write-Host ""
    Write-Host "=== Check Backend Logs for Email ===" -ForegroundColor Cyan
    Start-Sleep -Seconds 3
} else {
    Write-Host "Request not found. Listing all:" -ForegroundColor Yellow
    $reqs.content | ForEach-Object { Write-Host "  - $($_.email) | $($_.status)" }
}

Write-Host ""
Write-Host "=== Done - Check Gmail Inbox ===" -ForegroundColor Green
