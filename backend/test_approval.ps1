$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== Test 1: Admin Login ===" -ForegroundColor Cyan
$loginBody = '{"email":"admin@local","password":"Admin@123"}'
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body $loginBody
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}
Write-Host "Token: $($token.Substring(0, [Math]::Min(60, $token.Length)))..."
Write-Host ""

Write-Host "=== Test 2: Get Pending Registration Requests ===" -ForegroundColor Cyan
$reqs = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests?status=PENDING&page=0&size=10" -Method GET -Headers $headers
Write-Host "Total: $($reqs.totalElements)"
Write-Host "Requests: $($reqs.content | ConvertTo-Json -Depth 3)"
Write-Host ""

if ($reqs.totalElements -gt 0) {
    $testReq = $reqs.content[0]
    Write-Host "Found request: $($testReq.id) - $($testReq.email) - $($testReq.status)" -ForegroundColor Green

    Write-Host ""
    Write-Host "=== Test 3: Approve Registration ===" -ForegroundColor Cyan
    $approveBody = '{"region":"Ho Chi Minh City","note":"Approved for testing - notification system"}'
    $approve = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$($testReq.id)/approve" -Method POST -Headers $headers -ContentType "application/json" -Body $approveBody
    Write-Host "Approve result: $($approve | ConvertTo-Json -Depth 3)"
} else {
    Write-Host "No pending requests found." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
