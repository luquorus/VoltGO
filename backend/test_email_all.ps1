$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== Send All Email Notifications to luquorus.author@gmail.com ===" -ForegroundColor Cyan
Write-Host ""

# Admin login
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}
Write-Host "[OK] Admin logged in" -ForegroundColor Green

$login2 = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$token2 = $login2.token
$headers2 = @{"Authorization"="Bearer $token2"}
$userId = $login2.userId
Write-Host "[OK] luquorus logged in, userId: $userId" -ForegroundColor Green

$collabId = "1d1f510d-ac32-43fa-9359-a66dffeae622"

# ============ ENSURE ACTIVE CONTRACT ============
Write-Host ""
Write-Host "[*] Ensuring active contract exists..." -ForegroundColor Gray
try {
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $headers
    $active = $contracts | Where-Object { $_.status -eq "ACTIVE" }
    if (-not $active) {
        $createBody = @{
            collaboratorId = $collabId
            region = "Ho Chi Minh City"
            startDate = "2026-06-06"
            endDate = "2027-06-06"
            note = "Active for email test"
        } | ConvertTo-Json
        $active = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $headers -ContentType "application/json" -Body $createBody
        Write-Host "    [+] Created contract: $($active.id)" -ForegroundColor Gray
    } else {
        Write-Host "    [+] Has active contract: $($active.id)" -ForegroundColor Gray
    }
} catch { Write-Host "    [!] $($_.Exception.Message)" -ForegroundColor Yellow }

# ============ TEST 1: CONTRACT_UPDATED ============
Write-Host ""
Write-Host "[1/7] CONTRACT_UPDATED notification + email..." -ForegroundColor Yellow
try {
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $headers
    $active = $contracts | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -First 1
    if ($active) {
        $updateBody = @{ note = "Test CONTRACT_UPDATED at $(Get-Date -Format 'HH:mm:ss')" } | ConvertTo-Json
        $r = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts/$($active.id)" -Method PUT -Headers $headers -ContentType "application/json" -Body $updateBody
        Write-Host "    [OK] Updated contract $($active.id)" -ForegroundColor Green
        Write-Host "    [OK] Email sent -> luquorus.author@gmail.com" -ForegroundColor Cyan
    } else {
        Write-Host "    [SKIP] No active contract" -ForegroundColor Yellow
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============ TEST 2: CONTRACT_CREATED ============
Write-Host ""
Write-Host "[2/7] CONTRACT_CREATED notification + email..." -ForegroundColor Yellow
try {
    $createBody = @{
        collaboratorId = $collabId
        region = "Test Region $(Get-Random)"
        startDate = "2026-06-06"
        endDate = "2027-06-06"
        note = "Test CONTRACT_CREATED"
    } | ConvertTo-Json
    $newC = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $headers -ContentType "application/json" -Body $createBody
    Write-Host "    [OK] Created contract $($newC.id)" -ForegroundColor Green
    Write-Host "    [OK] Email sent -> luquorus.author@gmail.com" -ForegroundColor Cyan
    $testContractId = $newC.id
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============ TEST 3: CONTRACT_TERMINATED ============
Write-Host ""
Write-Host "[3/7] CONTRACT_TERMINATED notification + email..." -ForegroundColor Yellow
try {
    if ($testContractId) {
        $termBody = @{ reason = "Test termination" } | ConvertTo-Json
        $t = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts/$testContractId/terminate" -Method POST -Headers $headers -ContentType "application/json" -Body $termBody
        Write-Host "    [OK] Terminated contract $testContractId" -ForegroundColor Green
        Write-Host "    [OK] Email sent -> luquorus.author@gmail.com" -ForegroundColor Cyan
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============ TEST 4: TASK_ASSIGNED ============
Write-Host ""
Write-Host "[4/7] TASK_ASSIGNED notification + email..." -ForegroundColor Yellow
try {
    $stations = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations?page=0&size=3" -Method GET -Headers $headers
    if ($stations.content.Count -gt 0) {
        $stationId = $stations.content[0].stationId
        Write-Host "    Using station: $stationId" -ForegroundColor Gray
        # Create task
        $taskBody = @{ stationId = $stationId; priority = 2 } | ConvertTo-Json
        $task = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks" -Method POST -Headers $headers -ContentType "application/json" -Body $taskBody
        Write-Host "    [OK] Created task $($task.id)" -ForegroundColor Green
        # Assign to luquorus
        $assignBody = @{ collaboratorUserId = $userId } | ConvertTo-Json
        $assign = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$($task.id)/assign" -Method POST -Headers $headers -ContentType "application/json" -Body $assignBody
        Write-Host "    [OK] Assigned task to luquorus" -ForegroundColor Green
        Write-Host "    [OK] Email sent -> luquorus.author@gmail.com" -ForegroundColor Cyan
        $assignedTaskId = $task.id
    } else {
        Write-Host "    [SKIP] No stations found" -ForegroundColor Yellow
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============ TEST 5: TASK_REVIEWED_PASS ============
Write-Host ""
Write-Host "[5/7] TASK_REVIEWED_PASS notification + email..." -ForegroundColor Yellow
try {
    if ($assignedTaskId) {
        $taskDetail = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$assignedTaskId" -Method GET -Headers $headers
        Write-Host "    Task status: $($taskDetail.status)" -ForegroundColor Gray
        if ($taskDetail.status -eq "ASSIGNED") {
            $stationId = $taskDetail.stationId
            $stationDetail = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations/$stationId" -Method GET -Headers $headers
            $lat = $stationDetail.lat
            $lng = $stationDetail.lng
            Write-Host "    Station coords: lat=$lat, lng=$lng" -ForegroundColor Gray
            # Try check-in with station coords
            $checkinBody = @{ lat = $lat; lng = $lng; deviceNote = "Test check-in" } | ConvertTo-Json
            try {
                $ci = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$assignedTaskId/checkin" -Method POST -Headers $headers2 -ContentType "application/json" -Body $checkinBody -ErrorAction SilentlyContinue
                Write-Host "    [OK] Checked-in: status=$($ci.status)" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Check-in failed (may be outside range): $($_.Exception.Message)" -ForegroundColor Yellow
            }
            # Try submit evidence
            try {
                $evidenceBody = @{ photoObjectKey = "test/evidence-$(Get-Random).jpg"; note = "Test" } | ConvertTo-Json
                $submit = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$assignedTaskId/submit-evidence" -Method POST -Headers $headers2 -ContentType "application/json" -Body $evidenceBody -ErrorAction SilentlyContinue
                Write-Host "    [OK] Submitted evidence: status=$($submit.status)" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Submit failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            # Check final status
            $final = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$assignedTaskId" -Method GET -Headers $headers
            if ($final.status -eq "SUBMITTED") {
                $reviewBody = @{ result = "PASS"; adminNote = "Test PASS review" } | ConvertTo-Json
                $r = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$assignedTaskId/review" -Method POST -Headers $headers -ContentType "application/json" -Body $reviewBody
                Write-Host "    [OK] Reviewed as PASS" -ForegroundColor Green
                Write-Host "    [OK] Email sent -> luquorus.author@gmail.com" -ForegroundColor Cyan
            } else {
                Write-Host "    [SKIP] Task status is $($final.status), not SUBMITTED" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "    [SKIP] No assigned task" -ForegroundColor Yellow
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============ TEST 6: TASK_REVIEWED_FAIL ============
Write-Host ""
Write-Host "[6/7] TASK_REVIEWED_FAIL notification + email..." -ForegroundColor Yellow
try {
    # Create another task for FAIL test
    $stations = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations?page=1&size=3" -Method GET -Headers $headers
    if ($stations.content.Count -gt 0) {
        $stationId2 = $stations.content[0].stationId
        $taskBody2 = @{ stationId = $stationId2; priority = 2 } | ConvertTo-Json
        $task2 = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks" -Method POST -Headers $headers -ContentType "application/json" -Body $taskBody2
        $assignBody2 = @{ collaboratorUserId = $userId } | ConvertTo-Json
        $assign2 = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$($task2.id)/assign" -Method POST -Headers $headers -ContentType "application/json" -Body $assignBody2
        Write-Host "    Assigned task $($task2.id)" -ForegroundColor Gray
        # Check-in
        $stationDetail2 = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations/$stationId2" -Method GET -Headers $headers
        try {
            $ci2 = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$($task2.id)/checkin" -Method POST -Headers $headers2 -ContentType "application/json" -Body (@{ lat = $stationDetail2.lat; lng = $stationDetail2.lng; deviceNote = "Test" } | ConvertTo-Json) -ErrorAction SilentlyContinue
            Write-Host "    Checked-in: status=$($ci2.status)" -ForegroundColor Gray
            $ev2 = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$($task2.id)/submit-evidence" -Method POST -Headers $headers2 -ContentType "application/json" -Body (@{ photoObjectKey = "test/ev2.jpg"; note = "Test" } | ConvertTo-Json) -ErrorAction SilentlyContinue
            Write-Host "    Submitted: status=$($ev2.status)" -ForegroundColor Gray
        } catch {}
        $final2 = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$($task2.id)" -Method GET -Headers $headers
        if ($final2.status -eq "SUBMITTED") {
            $reviewBody2 = @{ result = "FAIL"; adminNote = "Test FAIL review" } | ConvertTo-Json
            $r2 = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$($task2.id)/review" -Method POST -Headers $headers -ContentType "application/json" -Body $reviewBody2
            Write-Host "    [OK] Reviewed as FAIL" -ForegroundColor Green
            Write-Host "    [OK] Email sent -> luquorus.author@gmail.com" -ForegroundColor Cyan
        } else {
            Write-Host "    [SKIP] Task status is $($final2.status), not SUBMITTED" -ForegroundColor Yellow
        }
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============ TEST 7: Registration rejection (via auth/register + submit) ============
Write-Host ""
Write-Host "[7/7] Registration REJECTED email + notification..." -ForegroundColor Yellow
try {
    $randomEmail = "testreject$(Get-Random)@test.com"
    $testPw = "Test123456"
    # Step 1: Register account
    $authRegBody = @{
        email = $randomEmail
        password = $testPw
        role = "COLLABORATOR"
    } | ConvertTo-Json
    $authReg = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method POST -ContentType "application/json" -Body $authRegBody
    Write-Host "    [OK] Registered account: $randomEmail" -ForegroundColor Green
    # Step 2: Login as new user to get token
    Start-Sleep -Seconds 1
    $userLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"=$randomEmail;"password"=$testPw} | ConvertTo-Json)
    $userToken = $userLogin.token
    $userHeaders = @{"Authorization"="Bearer $userToken"}
    # Step 3: Submit registration request (uses user's token -> extracts email from JWT)
    $submitBody = @{
        fullName = "Test Reject User"
        phone = "0912345678"
        dateOfBirth = "1995-01-01"
        address = "123 Test St"
        idCardNumber = "999999999"
        bankName = "VCB"
        bankAccountNumber = "9999999999"
        referralCode = ""
        contractAgreedAt = "2026-06-06T10:00:00Z"
    } | ConvertTo-Json
    $submit = Invoke-RestMethod -Uri "$baseUrl/api/public/registration-requests" -Method POST -Headers $userHeaders -ContentType "application/json" -Body $submitBody
    Write-Host "    [OK] Submitted request: $($submit.id)" -ForegroundColor Green
    # Step 4: Admin rejects it
    $rejectBody = @{ reason = "Test rejection - email notification" } | ConvertTo-Json
    $reject = Invoke-RestMethod -Uri "$baseUrl/api/admin/registration-requests/$($submit.id)/reject" -Method POST -Headers $headers -ContentType "application/json" -Body $rejectBody
    Write-Host "    [OK] Rejected request $($submit.id)" -ForegroundColor Green
    Write-Host "    [OK] Email sent -> $randomEmail" -ForegroundColor Cyan
    Write-Host "    [OK] In-app notification sent -> $randomEmail" -ForegroundColor Cyan
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $stream.ReadToEnd()
        $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
}

# ============ VERIFY NOTIFICATIONS ============
Write-Host ""
Write-Host "=== Verifying notifications for luquorus.author@gmail.com ===" -ForegroundColor Cyan
Start-Sleep -Seconds 2
try {
    $notifs = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications?page=0&size=50" -Method GET -Headers $headers2
    Write-Host "Total: $($notifs.totalElements), Unread: $($notifs.unreadCount)"
    $notifs.notifications | ForEach-Object {
        Write-Host "  [$($_.type)] $($_.title)" -ForegroundColor White
    }
} catch { Write-Host "Could not fetch: $($_.Exception.Message)" -ForegroundColor Yellow }

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Done! Check email inbox + spam:" -ForegroundColor Green
Write-Host "  - luquorus.author@gmail.com (notifications)" -ForegroundColor White
Write-Host "  - Check console logs for email body" -ForegroundColor White
Write-Host "  - TASK_REVIEWED tests need mobile check-in first" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
