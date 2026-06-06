$ErrorActionPreference = "Continue"

Write-Host "=== Test 1: Admin Login ===" -ForegroundColor Cyan
try {
    $login = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin@local","password":"admin123"}'
    $token = $login.token
    Write-Host "Token: $($token.Substring(0, [Math]::Min(50, $token.Length)))..."
    $script::AUTH_TOKEN = $token
} catch {
    Write-Host "Login error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Test 2: Get Notifications (should be empty) ===" -ForegroundColor Cyan
try {
    $notifs = Invoke-RestMethod -Uri "http://localhost:8080/api/collab/notifications" -Method GET -Headers @{"Authorization"="Bearer $AUTH_TOKEN"}
    Write-Host "Notifications: $($notifs | ConvertTo-Json -Depth 5)"
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Test 3: Submit Real Registration for luquorus.work@gmail.com ===" -ForegroundColor Cyan
try {
    $body = @{
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
    } | ConvertTo-Json -Compress
    $reg = Invoke-RestMethod -Uri "http://localhost:8080/auth/register" -Method POST -ContentType "application/json" -Body $body
    Write-Host "Register: $($reg | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Register error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Response: $($_.Exception.Response | Out-String)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
