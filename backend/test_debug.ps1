$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}
Write-Host "Admin logged in" -ForegroundColor Green

$login2 = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$token2 = $login2.token
$headers2 = @{"Authorization"="Bearer $token2"}
$userId = $login2.userId
Write-Host "luquorus logged in, userId: $userId" -ForegroundColor Green
Write-Host ""

# Debug 1: CONTRACT_UPDATED
Write-Host "[DEBUG] CONTRACT_UPDATED..." -ForegroundColor Yellow
try {
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=1d1f510d-ac32-43fa-9359-a66dffeae622" -Method GET -Headers $headers
    Write-Host "Contracts: $($contracts.Count)"
    if ($contracts.Count -gt 0) {
        $c = $contracts[0]
        Write-Host "Contract: $($c | ConvertTo-Json -Depth 3)"
        $updateBody = @{ note = "Debug update" } | ConvertTo-Json
        $r = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts/$($c.id)" -Method PUT -Headers $headers -ContentType "application/json" -Body $updateBody -ErrorAction SilentlyContinue
        Write-Host "Update result: $($r | ConvertTo-Json)" -ForegroundColor Green
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $stream.ReadToEnd()
        $stream.Dispose()
        Write-Host "Response body: $body" -ForegroundColor Red
    } catch {}
}

# Debug 2: Station list
Write-Host ""
Write-Host "[DEBUG] Station list..." -ForegroundColor Yellow
try {
    $stations = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations?page=0&size=5" -Method GET -Headers $headers
    Write-Host "Stations total: $($stations.totalElements)"
    Write-Host "First station: $($stations.content[0] | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Debug 3: Registration rejection
Write-Host ""
Write-Host "[DEBUG] Registration rejection..." -ForegroundColor Yellow
try {
    # First register a test user
    $regBody = @{
        email = "debugreject$(Get-Random)@test.com"
        password = "VoltGoTest123"
        fullName = "Debug Test"
        phone = "0912345678"
        dateOfBirth = "1995-01-01"
        address = "123 Test"
        idCardNumber = "999999999"
        bankName = "VCB"
        bankAccountNumber = "9999999999"
        contractAgreedAt = "2026-06-06T10:00:00Z"
    } | ConvertTo-Json
    $reg = Invoke-RestMethod -Uri "$baseUrl/api/public/registration-requests" -Method POST -ContentType "application/json" -Body $regBody
    Write-Host "Registered: $($reg | ConvertTo-Json -Depth 3)"
    Start-Sleep -Seconds 2
    # Find it
    $reqs = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests?status=PENDING&page=0&size=100" -Method GET -Headers $headers
    $newReq = $reqs.content | Where-Object { $_.email -match "debugreject" }
    if ($newReq) {
        Write-Host "Found request: $($newReq | ConvertTo-Json -Depth 3)"
        $rejectBody = @{ reason = "Debug rejection" } | ConvertTo-Json
        $reject = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$($newReq.id)/reject" -Method POST -Headers $headers -ContentType "application/json" -Body $rejectBody -ErrorAction SilentlyContinue
        Write-Host "Reject result: $($reject | ConvertTo-Json -Depth 3)" -ForegroundColor Green
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $stream.ReadToEnd()
        $stream.Dispose()
        Write-Host "Response body: $body" -ForegroundColor Red
    } catch {}
}
