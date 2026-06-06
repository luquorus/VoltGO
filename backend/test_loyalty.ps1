$ErrorActionPreference = "Stop"

# Login as EV user
Write-Host "=== LOGIN EV USER ==="
$login = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"test@1","password":"Admin@123"}'
$evToken = $login.token
$evUserId = $login.userId
Write-Host "Token: $($evToken.Substring(0, [Math]::Min(30, $evToken.Length)))..."
Write-Host "UserId: $evUserId"

# Login as Admin
Write-Host "`n=== LOGIN ADMIN ==="
$adminLogin = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin2@local","password":"Admin@456"}'
$adminToken = $adminLogin.token
$adminUserId = $adminLogin.userId
Write-Host "Admin Token: $($adminToken.Substring(0, [Math]::Min(30, $adminToken.Length)))..."
Write-Host "Admin UserId: $adminUserId"

# Test GET /api/ev/loyalty/me
Write-Host "`n=== TEST GET /api/ev/loyalty/me ==="
try {
    $profile = Invoke-RestMethod -Uri "http://localhost:8080/api/ev/loyalty/me" -Method GET -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $evToken" }
    Write-Host "Status: OK"
    Write-Host "Profile: $($profile | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Test GET /api/ev/loyalty/ratings/eligible
Write-Host "`n=== TEST GET /api/ev/loyalty/ratings/eligible ==="
try {
    $eligible = Invoke-RestMethod -Uri "http://localhost:8080/api/ev/loyalty/ratings/eligible" -Method GET -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $evToken" }
    Write-Host "Status: OK"
    Write-Host "Eligible stations: $($eligible | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Test GET /api/ev/loyalty/badges
Write-Host "`n=== TEST GET /api/ev/loyalty/badges ==="
try {
    $badges = Invoke-RestMethod -Uri "http://localhost:8080/api/ev/loyalty/badges" -Method GET -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $evToken" }
    Write-Host "Status: OK"
    Write-Host "Badges: $($badges | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Test GET /api/ev/loyalty/badges/available
Write-Host "`n=== TEST GET /api/ev/loyalty/badges/available ==="
try {
    $allBadges = Invoke-RestMethod -Uri "http://localhost:8080/api/ev/loyalty/badges/available" -Method GET -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $evToken" }
    Write-Host "Status: OK"
    Write-Host "All Badges: $($allBadges | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Test GET /api/ev/loyalty/points/history
Write-Host "`n=== TEST GET /api/ev/loyalty/points/history ==="
try {
    $history = Invoke-RestMethod -Uri "http://localhost:8080/api/ev/loyalty/points/history" -Method GET -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $evToken" }
    Write-Host "Status: OK"
    Write-Host "History: $($history | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Test Admin endpoint
Write-Host "`n=== TEST ADMIN GET /api/admin/loyalty/users/$evUserId ==="
try {
    $adminProfile = Invoke-RestMethod -Uri "http://localhost:8080/api/admin/loyalty/users/$evUserId" -Method GET -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $adminToken" }
    Write-Host "Status: OK"
    Write-Host "Admin Profile: $($adminProfile | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Test Admin badges
Write-Host "`n=== TEST ADMIN GET /api/admin/loyalty/badges ==="
try {
    $adminBadges = Invoke-RestMethod -Uri "http://localhost:8080/api/admin/loyalty/badges" -Method GET -ContentType "application/json" -Headers @{ "Authorization" = "Bearer $adminToken" }
    Write-Host "Status: OK"
    Write-Host "Admin Badges: $($adminBadges | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Test Public endpoint (no auth) - just verify the endpoint responds
Write-Host "`n=== TEST PUBLIC GET /api/ev/loyalty/public/stations/{stationId}/summary ==="
try {
    $summary = Invoke-RestMethod -Uri "http://localhost:8080/api/ev/loyalty/public/stations/00000000-0000-0000-0000-000000000001/summary" -Method GET
    Write-Host "Status: OK (no auth required)"
    Write-Host "Response: $($summary | ConvertTo-Json -Depth 2)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

Write-Host "`n=== ALL TESTS COMPLETE ==="
