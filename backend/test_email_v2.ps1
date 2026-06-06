$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"
$lat = 20.990147
$lng = 105.855614

Write-Host "=== Setup + Full Email Test ===" -ForegroundColor Cyan

# Admin login
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}

# Collaborator login
$login2 = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$token2 = $login2.token
$headers2 = @{"Authorization"="Bearer $token2"}
$userId = $login2.userId
$collabId = "1d1f510d-ac32-43fa-9359-a66dffeae622"

Write-Host "[1] Update collaborator location..." -ForegroundColor Yellow
try {
    $locBody = @{ lat = $lat; lng = $lng } | ConvertTo-Json
    $loc = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/me/location" -Method PUT -Headers $headers2 -ContentType "application/json" -Body $locBody
    Write-Host "    [OK] Location: lat=$($loc.lat), lng=$($loc.lng)" -ForegroundColor Green
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# Find the DRAFT BS CR from earlier
Write-Host ""
Write-Host "[2] Get DRAFT BS change requests..." -ForegroundColor Yellow
try {
    $crs = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests?status=DRAFT" -Method GET -Headers $headers
    Write-Host "    DRAFT CRs: $($crs.Count)"
    $crs | ForEach-Object { Write-Host "    - CR=$($_.id) | stationId=$($_.stationId) | status=$($_.status)" -ForegroundColor Gray }
    $draftCr = $crs | Select-Object -First 1
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# Publish the DRAFT CR
Write-Host ""
Write-Host "[3] Publish DRAFT BS CR..." -ForegroundColor Yellow
if ($draftCr) {
    try {
        $publish = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests/$($draftCr.id)/publish" -Method POST -Headers $headers -ContentType "application/json"
        $bsStationId = $publish.stationId
        Write-Host "    [OK] Published! stationId=$bsStationId" -ForegroundColor Green
        Write-Host "    CR status: $($publish.status)" -ForegroundColor Gray
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        try {
            $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $body = $stream.ReadToEnd()
            $stream.Dispose()
            Write-Host "    Response: $body" -ForegroundColor Red
        } catch {}
    }
}

# Ensure active contract
Write-Host ""
Write-Host "[4] Ensure active contract..." -ForegroundColor Yellow
try {
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $headers
    $active = $contracts | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -First 1
    if (-not $active) {
        $cb = @{ collaboratorId = $collabId; region = "Hanoi"; startDate = "2026-06-06"; endDate = "2027-06-06" } | ConvertTo-Json
        $active = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $headers -ContentType "application/json" -Body $cb
        Write-Host "    [+] Created contract: $($active.id)" -ForegroundColor Green
    } else {
        Write-Host "    [+] Has active contract: $($active.id)" -ForegroundColor Green
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# Upload evidence image
Write-Host ""
Write-Host "[5] Upload evidence image..." -ForegroundColor Yellow
$imagePath = "C:\Users\luquo\Downloads\Thiet ke chua co ten (13).png"
$foundPath = $null
if (Test-Path $imagePath) { $foundPath = $imagePath }
else {
    $altPath = "C:\Users\luquo\Downloads\Thiết kế chưa có tên (13).png"
    if (Test-Path $altPath) { $foundPath = $altPath }
    else {
        Get-ChildItem "C:\Users\luquo\Downloads\" -Filter "*.png" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($foundPath -eq $null) { $foundPath = $_.FullName }
        }
    }
}
if ($foundPath) {
    Write-Host "    Found image: $foundPath" -ForegroundColor Gray
    try {
        $presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $headers2 -ContentType "application/json" -Body (@{ contentType = "image/png" } | ConvertTo-Json)
        $objectKey = $presign.objectKey
        $uploadUrl = $presign.uploadUrl
        $imageBytes = [System.IO.File]::ReadAllBytes($foundPath)
        $wc = New-Object System.Net.WebClient
        $wc.Headers["Content-Type"] = "image/png"
        $wc.UploadData($uploadUrl, "PUT", $imageBytes)
        $wc.Dispose()
        Write-Host "    [OK] Uploaded: $objectKey" -ForegroundColor Green
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
} else {
    Write-Host "    [SKIP] No image found in Downloads" -ForegroundColor Yellow
}

# Get charging station ID
$chargingStationId = "6bc5e47b-fbd0-4bad-a05b-09ad1ef3b4d3"

# Create + assign task for Charging station
Write-Host ""
Write-Host "[6] Create + assign task (Charging)..." -ForegroundColor Yellow
try {
    $tb = @{ stationId = $chargingStationId; priority = 2 } | ConvertTo-Json
    $task = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks" -Method POST -Headers $headers -ContentType "application/json" -Body $tb
    $ab = @{ collaboratorUserId = $userId } | ConvertTo-Json
    $assign = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$($task.id)/assign" -Method POST -Headers $headers -ContentType "application/json" -Body $ab
    Write-Host "    [OK] Created + assigned task: $($task.id)" -ForegroundColor Green
    Write-Host "    [OK] TASK_ASSIGNED email sent" -ForegroundColor Cyan
    $chargingTaskId = $task.id
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# Create + assign BS task
Write-Host ""
Write-Host "[7] Create + assign task (Battery Swap)..." -ForegroundColor Yellow
if ($bsStationId) {
    try {
        $bsTb = @{ stationId = $bsStationId; priority = 2 } | ConvertTo-Json
        $bsTask = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks" -Method POST -Headers $headers -ContentType "application/json" -Body $bsTb
        $bsAb = @{ collaboratorUserId = $userId } | ConvertTo-Json
        $bsAssign = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$($bsTask.id)/assign" -Method PUT -Headers $headers -ContentType "application/json" -Body $bsAb
        Write-Host "    [OK] Created + assigned BS task: $($bsTask.id)" -ForegroundColor Green
        Write-Host "    [OK] TASK_ASSIGNED email sent (Battery Swap)" -ForegroundColor Cyan
        $bsTaskId = $bsTask.id
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

# Check-in + submit Charging task
Write-Host ""
Write-Host "[8] Check-in + submit (Charging task)..." -ForegroundColor Yellow
if ($chargingTaskId) {
    try {
        $ci = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/check-in" -Method POST -Headers $headers2 -ContentType "application/json" -Body (@{ lat = $lat; lng = $lng; deviceNote = "Test" } | ConvertTo-Json)
        Write-Host "    [OK] Checked-in: $($ci.status)" -ForegroundColor Green
        if ($objectKey) {
            $ev = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/submit-evidence" -Method POST -Headers $headers2 -ContentType "application/json" -Body (@{ photoObjectKey = $objectKey; note = "Test" } | ConvertTo-Json)
            Write-Host "    [OK] Evidence submitted: $($ev.status)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Check-in + submit Battery Swap task
Write-Host ""
Write-Host "[9] Check-in + submit (Battery Swap task)..." -ForegroundColor Yellow
if ($bsTaskId) {
    try {
        $bsCi = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/checkin" -Method POST -Headers $headers2 -ContentType "application/json" -Body (@{ lat = $lat; lng = $lng; deviceNote = "Test BS" } | ConvertTo-Json)
        Write-Host "    [OK] BS Checked-in: $($bsCi.status)" -ForegroundColor Green
        if ($objectKey) {
            $bsEv = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/evidence" -Method POST -Headers $headers2 -ContentType "application/json" -Body (@{ photoObjectKey = $objectKey; note = "Test BS" } | ConvertTo-Json)
            Write-Host "    [OK] BS Evidence submitted: $($bsEv.status)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Admin reviews
Write-Host ""
Write-Host "[10] Admin reviews tasks..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

if ($chargingTaskId) {
    $taskDetail = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId" -Method GET -Headers $headers
    if ($taskDetail.status -eq "SUBMITTED") {
        try {
            $r = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId/review" -Method POST -Headers $headers -ContentType "application/json" -Body (@{ result = "PASS"; adminNote = "Test PASS" } | ConvertTo-Json)
            Write-Host "    [OK] TASK_REVIEWED_PASS (Charging) -> Email sent" -ForegroundColor Cyan
        } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
    } else {
        Write-Host "    [SKIP] Charging task status: $($taskDetail.status)" -ForegroundColor Yellow
    }
}

if ($bsTaskId) {
    $bsTaskDetail = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId" -Method GET -Headers $headers
    if ($bsTaskDetail.status -eq "SUBMITTED") {
        try {
            $bsR = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId/review" -Method POST -Headers $headers -ContentType "application/json" -Body (@{ result = "FAIL"; adminNote = "Test FAIL" } | ConvertTo-Json)
            Write-Host "    [OK] TASK_REVIEWED_FAIL (Battery Swap) -> Email sent" -ForegroundColor Cyan
        } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
    } else {
        Write-Host "    [SKIP] BS task status: $($bsTaskDetail.status)" -ForegroundColor Yellow
    }
}

# Verify notifications
Write-Host ""
Write-Host "=== Notifications ===" -ForegroundColor Cyan
try {
    $notifs = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications?page=0&size=50" -Method GET -Headers $headers2
    Write-Host "Total: $($notifs.totalElements), Unread: $($notifs.unreadCount)"
    $notifs.notifications | Select-Object -First 20 | ForEach-Object {
        Write-Host "  [$($_.type)] $($_.title)" -ForegroundColor White
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

Write-Host ""
Write-Host "Done! Check email inbox + spam." -ForegroundColor Green
