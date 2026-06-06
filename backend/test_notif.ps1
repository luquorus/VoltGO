$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== Test 1: Admin Login ===" -ForegroundColor Cyan
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin@local","password":"Admin@123"}'
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}
Write-Host "Login success. Token: $($token.Substring(0, [Math]::Min(60, $token.Length)))..."
Write-Host ""

Write-Host "=== Test 2: Get Pending Registration Requests ===" -ForegroundColor Cyan
try {
    $reqs = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests?status=PENDING&page=0&size=10" -Method GET -Headers $headers
    Write-Host "Total pending: $($reqs.totalElements)"
    if ($reqs.totalElements -gt 0) {
        $reqs.content | ForEach-Object {
            Write-Host "  - $($_.id) | $($_.email) | $($_.fullName) | $($_.status)"
        }
        $testReq = $reqs.content[0]

        Write-Host ""
        Write-Host "=== Test 3: Approve Registration (should trigger CONTRACT_APPROVED notification + email) ===" -ForegroundColor Cyan
        $approve = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$($testReq.id)/approve" -Method POST -Headers $headers -ContentType "application/json" -Body '{"region":"Ho Chi Minh City","note":"Approved - notification system test"}'
        Write-Host "Approve success: $($approve | ConvertTo-Json)"

        Write-Host ""
        Write-Host "=== Test 4: Check Notifications for new user ===" -ForegroundColor Cyan
        # Login as new user
        $newLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body ("{`"email`":`"$($testReq.email)`",`"password`":`"VoltGo123456`"}")
        $newToken = $newLogin.token
        $newHeaders = @{"Authorization"="Bearer $newToken"}
        $notifs = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications" -Method GET -Headers $newHeaders
        Write-Host "Notifications for $($testReq.email): $($notifs | ConvertTo-Json -Depth 5)"
    } else {
        Write-Host "No pending requests found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Response: $($_.Exception.Response | Out-String)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Test Done ===" -ForegroundColor Green
