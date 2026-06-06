$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

# Helper function
function Get-AdminToken {
    $body = @{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body $body
    return $login.token
}

Write-Host "=== Test: Send Real Email Notifications ===" -ForegroundColor Cyan
Write-Host ""

# Admin login
Write-Host "[1/8] Admin Login..." -ForegroundColor Yellow
try {
    $token = Get-AdminToken
    $headers = @{"Authorization"="Bearer $token"}
    Write-Host "    OK. Token: $($token.Substring(0, 40))..." -ForegroundColor Green
} catch {
    Write-Host "    FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 1: Check luquorus.author@gmail.com in system
Write-Host ""
Write-Host "[2/8] Check if luquorus.author@gmail.com has account..." -ForegroundColor Yellow
# First check via pending requests
try {
    $reqs = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests?page=0&size=50" -Method GET -Headers $headers
    $existingReq = $reqs.content | Where-Object { $_.email -eq "luquorus.author@gmail.com" }
    if ($existingReq) {
        Write-Host "    Found existing request: $($existingReq.id) | Status: $($existingReq.status)" -ForegroundColor Green
        $reqId = $existingReq.id
        $userStatus = $existingReq.status
    } else {
        Write-Host "    No existing request for this email." -ForegroundColor Yellow
        $reqId = $null
    }
} catch {
    Write-Host "    Could not fetch requests: $($_.Exception.Message)" -ForegroundColor Yellow
    $reqId = $null
}

# Step 2: Register collaborator if not exists
if (-not $reqId) {
    Write-Host ""
    Write-Host "[3/8] Register luquorus.author@gmail.com as collaborator..." -ForegroundColor Yellow
    $regBody = @{
        email = "luquorus.author@gmail.com"
        password = "VoltGoTest123"
        fullName = "Lu Quorus Test"
        phone = "0912345678"
        dateOfBirth = "1995-01-01"
        address = "123 Test Street, Vietnam"
        idCardNumber = "123456789"
        bankName = "VietComBank"
        bankAccountNumber = "1234567890"
        referralCode = ""
        contractAgreedAt = "2026-06-06T10:00:00Z"
    } | ConvertTo-Json

    try {
        $reg = Invoke-RestMethod -Uri "$baseUrl/api/public/registration-requests" -Method POST -ContentType "application/json" -Body $regBody
        Write-Host "    Registered. Request ID: $($reg.id)" -ForegroundColor Green
        $reqId = $reg.id
        Start-Sleep -Seconds 2

        # Fetch the pending request
        $reqs = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests?status=PENDING&page=0&size=50" -Method GET -Headers $headers
        $pendingReq = $reqs.content | Where-Object { $_.email -eq "luquorus.author@gmail.com" }
        if ($pendingReq) { $reqId = $pendingReq.id }
        $userStatus = "PENDING"
    } catch {
        Write-Host "    Registration error (may already exist): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Step 3: Get the request and check status
Write-Host ""
Write-Host "[4/8] Getting registration request details..." -ForegroundColor Yellow
if ($reqId) {
    try {
        $req = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$reqId" -Method GET -Headers $headers
        Write-Host "    Request: $($req.email) | Status: $($req.status)" -ForegroundColor Green
        $userStatus = $req.status
    } catch {
        Write-Host "    Could not fetch details: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Step 4: APPROVE registration -> triggers CONTRACT_APPROVED email + notification
if ($reqId -and $userStatus -eq "PENDING") {
    Write-Host ""
    Write-Host "[5/8] APPROVE Registration (triggers CONTRACT_APPROVED + email)..." -ForegroundColor Yellow
    $approveBody = @{
        region = "Ho Chi Minh City"
        note = "Test email notification"
    } | ConvertTo-Json
    try {
        $approve = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$reqId/approve" -Method POST -Headers $headers -ContentType "application/json" -Body $approveBody
        Write-Host "    APPROVED! Status: $($approve.status)" -ForegroundColor Green
        Write-Host "    -> Check email: luquorus.author@gmail.com" -ForegroundColor Cyan
        Write-Host "    -> Subject: VoltGo - Registration Approved" -ForegroundColor Cyan
        Start-Sleep -Seconds 3
    } catch {
        Write-Host "    Approve error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 5: Check user notifications
Write-Host ""
Write-Host "[6/8] Check notifications for luquorus.author@gmail.com..." -ForegroundColor Yellow
try {
    $login2 = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="VoltGoTest123"} | ConvertTo-Json)
    $token2 = $login2.token
    $headers2 = @{"Authorization"="Bearer $token2"}
    $notifs = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications?page=0&size=10" -Method GET -Headers $headers2
    Write-Host "    Notifications: $($notifs.totalElements) total, $($notifs.unreadCount) unread"
    $notifs.notifications | ForEach-Object {
        Write-Host "    - [$($_.type)] $($_.title)"
    }
} catch {
    Write-Host "    Could not check notifications: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 6: Get contracts and try to test CONTRACT_UPDATED/TERMINATED
Write-Host ""
Write-Host "[7/8] Get contracts for test user..." -ForegroundColor Yellow
try {
    # First find the collaborator by email - use the collab detail endpoint
    $collabList = Invoke-RestMethod -Uri "$baseUrl/api/admin/collaborators?page=0&size=50" -Method GET -Headers $headers
    $collab = $collabList.content | Where-Object { $_.email -eq "luquorus.author@gmail.com" }
    if ($collab) {
        Write-Host "    Found collaborator: $($collab.id) | $($collab.email)" -ForegroundColor Green
        $collabId = $collab.id

        $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/collaborators/$collabId/contracts" -Method GET -Headers $headers
        Write-Host "    Contracts: $($contracts.Count)"
        if ($contracts.Count -gt 0) {
            $contractId = $contracts[0].id

            Write-Host ""
            Write-Host "[8/8] UPDATE Contract (triggers CONTRACT_UPDATED + email)..." -ForegroundColor Yellow
            $updateBody = @{
                note = "Updated at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            } | ConvertTo-Json
            try {
                $update = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts/$contractId" -Method PUT -Headers $headers -ContentType "application/json" -Body $updateBody
                Write-Host "    UPDATED! Contract: $($update.id) | Status: $($update.status)" -ForegroundColor Green
                Write-Host "    -> Check email: luquorus.author@gmail.com" -ForegroundColor Cyan
                Write-Host "    -> Subject: Contract Updated" -ForegroundColor Cyan
                Start-Sleep -Seconds 2
            } catch {
                Write-Host "    Update error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    No contracts found." -ForegroundColor Yellow
        }
    } else {
        Write-Host "    Collaborator not found in system." -ForegroundColor Yellow
    }
} catch {
    Write-Host "    Error checking collaborators: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SUMMARY: Email notifications sent to luquorus.author@gmail.com" -ForegroundColor Cyan
Write-Host "Check inbox (also spam folder) for:" -ForegroundColor Cyan
Write-Host "  1. VoltGo - Registration Approved" -ForegroundColor White
Write-Host "  2. Contract Updated (via in-app notification)" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Task assignments and SLA notifications require:" -ForegroundColor Yellow
Write-Host "  - Active contracts" -ForegroundColor White
Write-Host "  - Admin to assign verification tasks" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
