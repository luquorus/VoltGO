$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== Test 1: Admin Login ===" -ForegroundColor Cyan
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin@local","password":"Admin@123"}'
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}
Write-Host "Login OK. Token: $($token.Substring(0, 40))..."
Write-Host ""

Write-Host "=== Test 2: Register New Test User ===" -ForegroundColor Cyan
$regBody = '{"email":"testnotif@voltgo.com","password":"Test123456","fullName":"Notification Test","phone":"0912345678","dateOfBirth":"1990-01-01","address":"123 Test St","idCardNumber":"123456789","bankName":"VCB","bankAccountNumber":"1234567890","referralCode":"","contractAgreedAt":"2026-06-05T10:00:00Z"}'
$reg = Invoke-RestMethod -Uri "$baseUrl/api/public/registration-requests" -Method POST -ContentType "application/json" -Body $regBody
Write-Host "Register: $($reg | ConvertTo-Json)"
Write-Host ""

Write-Host "=== Test 3: Get Pending Requests ===" -ForegroundColor Cyan
$reqs = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests?status=PENDING&page=0&size=20" -Method GET -Headers $headers
Write-Host "Total pending: $($reqs.totalElements)"
$newReq = $reqs.content | Where-Object { $_.email -eq "testnotif@voltgo.com" }
if ($newReq) {
    Write-Host "Found request: $($newReq.id) - $($newReq.email)" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Test 4: Approve Registration ===" -ForegroundColor Cyan
    $approve = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$($newReq.id)/approve" -Method POST -Headers $headers -ContentType "application/json" -Body '{"region":"Ha Noi","note":"Test notification system"}'
    Write-Host "Approve: OK - status=$($approve.status)"
    Write-Host ""

    Write-Host "=== Test 5: Login New User & Get Notifications ===" -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    $newLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"testnotif@voltgo.com","password":"Test123456"}'
    $newToken = $newLogin.token
    $newHeaders = @{"Authorization"="Bearer $newToken"}
    $notifs = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications" -Method GET -Headers $newHeaders
    Write-Host "Notifications:"
    $notifs.notifications | ForEach-Object {
        Write-Host "  - [$($_.type)] $($_.title)"
        Write-Host "    $($_.body)"
    }
    Write-Host "Unread count: $($notifs.unreadCount)"
    Write-Host ""

    Write-Host "=== Test 6: Mark as Read ===" -ForegroundColor Cyan
    if ($notifs.notifications.Count -gt 0) {
        $firstNotifId = $notifs.notifications[0].id
        $patch = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications/$firstNotifId/read" -Method PATCH -Headers $newHeaders
        Write-Host "Mark as read: OK"
        $notifs2 = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications" -Method GET -Headers $newHeaders
        Write-Host "Unread count after mark: $($notifs2.unreadCount)"
    }
} else {
    Write-Host "Request not found, listing all:" -ForegroundColor Yellow
    $reqs.content | ForEach-Object { Write-Host "  - $($_.email) | $($_.status)" }
}

Write-Host ""
Write-Host "=== Test Done ===" -ForegroundColor Green
