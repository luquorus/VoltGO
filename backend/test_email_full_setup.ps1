$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"
$lat = 20.990147
$lng = 105.855614

Write-Host "=== Setup Stations + Test Email Notifications ===" -ForegroundColor Cyan
Write-Host "Target: $lat, $lng" -ForegroundColor Gray
Write-Host ""

# Admin login
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}
Write-Host "[OK] Admin logged in" -ForegroundColor Green

# Collaborator login
$login2 = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$token2 = $login2.token
$headers2 = @{"Authorization"="Bearer $token2"}
$userId = $login2.userId
$collabId = "1d1f510d-ac32-43fa-9359-a66dffeae622"
Write-Host "[OK] luquorus logged in, userId: $userId" -ForegroundColor Green

# ================================================
# STEP 1: Update collaborator location to target coords
# ================================================
Write-Host ""
Write-Host "[STEP 1] Update collaborator location..." -ForegroundColor Yellow
try {
    $locBody = @{ lat = $lat; lng = $lng } | ConvertTo-Json
    $loc = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/me/location" -Method PUT -Headers $headers2 -ContentType "application/json" -Body $locBody
    Write-Host "    [OK] Location updated: lat=$($loc.lat), lng=$($loc.lng)" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

# ================================================
# STEP 2: Create Hoang Mai Charging Station
# ================================================
Write-Host ""
Write-Host "[STEP 2] Create Hoang Mai Charging Station..." -ForegroundColor Yellow
try {
    $chargingBody = @{
        stationData = @{
            name = "Hoang Mai Charging Station"
            address = "Hoang Mai District, Hanoi, Vietnam"
            location = @{ lat = $lat; lng = $lng }
            operatingHours = "06:00-22:00"
            parking = "FREE"
            visibility = "PUBLIC"
            publicStatus = "ACTIVE"
            services = @(
                @{
                    type = "CHARGING"
                    chargingPorts = @(
                        @{ powerType = "DC"; powerKw = 120; count = 2 }
                        @{ powerType = "DC"; powerKw = 60; count = 2 }
                        @{ powerType = "AC"; count = 4 }
                    )
                }
            )
        }
        publishImmediately = $true
    } | ConvertTo-Json -Depth 10

    $chargingStation = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations" -Method POST -Headers $headers -ContentType "application/json" -Body $chargingBody
    $chargingStationId = $chargingStation.stationId
    Write-Host "    [OK] Created Charging Station: $chargingStationId" -ForegroundColor Green
    Write-Host "    Name: $($chargingStation.name)" -ForegroundColor Gray
    Write-Host "    Workflow: $($chargingStation.workflowStatus)" -ForegroundColor Gray
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $stream.ReadToEnd()
        $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
}

# ================================================
# STEP 3: Create Hoang Mai Battery Swap Station
# ================================================
Write-Host ""
Write-Host "[STEP 3] Create Hoang Mai Battery Swap Station..." -ForegroundColor Yellow
try {
    $swapBody = @{
        type = "CREATE_BATTERY_SWAP_STATION"
        totalBatteries = 24
        avgChargePowerKw = 40.0
        operatingHours = "24/7"
        parkingFee = 0
        note = "Hoang Mai Battery Swap Station for email test"
        pileTemplates = @(
            @{ pileIndex = 1; slotsPerPile = 6 }
            @{ pileIndex = 2; slotsPerPile = 6 }
            @{ pileIndex = 3; slotsPerPile = 6 }
            @{ pileIndex = 4; slotsPerPile = 6 }
        )
    } | ConvertTo-Json -Depth 10

    $swapCR = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests" -Method POST -Headers $headers -ContentType "application/json" -Body $swapBody
    $swapStationId = $swapCR.stationId
    Write-Host "    [OK] Created Battery Swap Station via CR: $swapStationId" -ForegroundColor Green
    Write-Host "    CR Status: $($swapCR.status)" -ForegroundColor Gray
    Write-Host "    CR ID: $($swapCR.id)" -ForegroundColor Gray
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $stream.ReadToEnd()
        $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
}

# ================================================
# STEP 4: Ensure active contract
# ================================================
Write-Host ""
Write-Host "[STEP 4] Ensuring active contract..." -ForegroundColor Yellow
try {
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $headers
    $active = $contracts | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -First 1
    if (-not $active) {
        $createBody = @{
            collaboratorId = $collabId
            region = "Hoang Mai, Hanoi"
            startDate = "2026-06-06"
            endDate = "2027-06-06"
            note = "Active for email test"
        } | ConvertTo-Json
        $active = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $headers -ContentType "application/json" -Body $createBody
        Write-Host "    [+] Created contract: $($active.id)" -ForegroundColor Green
    } else {
        Write-Host "    [+] Has active contract: $($active.id)" -ForegroundColor Green
    }
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

# ================================================
# STEP 5: Upload evidence image to MinIO
# ================================================
Write-Host ""
Write-Host "[STEP 5] Upload evidence image to MinIO..." -ForegroundColor Yellow
$imagePath = "C:\Users\luquo\Downloads\Thiết kế chưa có tên (13).png"
if (-not (Test-Path $imagePath)) {
    Write-Host "    [FAIL] Image not found at: $imagePath" -ForegroundColor Red
} else {
    try {
        # Get presigned upload URL
        $presignBody = @{ contentType = "image/png" } | ConvertTo-Json
        $presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $headers2 -ContentType "application/json" -Body $presignBody
        $objectKey = $presign.objectKey
        $uploadUrl = $presign.uploadUrl
        Write-Host "    Got presigned URL: $objectKey" -ForegroundColor Gray

        # Upload image
        $imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers["Content-Type"] = "image/png"
        $webClient.UploadData($uploadUrl, "PUT", $imageBytes)
        $webClient.Dispose()
        Write-Host "    [OK] Image uploaded to MinIO: $objectKey" -ForegroundColor Green
    } catch {
        Write-Host "    [FAIL] Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================
# STEP 6: Create + assign verification task for charging station
# ================================================
Write-Host ""
Write-Host "[STEP 6] Create + assign verification task (Charging)..." -ForegroundColor Yellow
if ($chargingStationId) {
    try {
        $taskBody = @{ stationId = $chargingStationId; priority = 2 } | ConvertTo-Json
        $task = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks" -Method POST -Headers $headers -ContentType "application/json" -Body $taskBody
        Write-Host "    [OK] Created task: $($task.id)" -ForegroundColor Green

        $assignBody = @{ collaboratorUserId = $userId } | ConvertTo-Json
        $assign = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$($task.id)/assign" -Method POST -Headers $headers -ContentType "application/json" -Body $assignBody
        Write-Host "    [OK] Assigned to luquorus" -ForegroundColor Green
        Write-Host "    [OK] Email sent -> luquorus.author@gmail.com" -ForegroundColor Cyan
        $chargingTaskId = $task.id
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================
# STEP 7: Create + assign battery swap verification task
# ================================================
Write-Host ""
Write-Host "[STEP 7] Create + assign battery swap task..." -ForegroundColor Yellow
if ($swapStationId) {
    try {
        $bsTask = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification-tasks" -Method POST -Headers $headers -ContentType "application/json" -Body (@{ stationId = $swapStationId } | ConvertTo-Json)
        Write-Host "    [OK] Created BS task: $($bsTask.id)" -ForegroundColor Green

        $bsAssign = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification-tasks/$($bsTask.id)/assign" -Method POST -Headers $headers -ContentType "application/json" -Body (@{ collaboratorUserId = $userId } | ConvertTo-Json)
        Write-Host "    [OK] Assigned BS task to luquorus" -ForegroundColor Green
        Write-Host "    [OK] Email sent -> luquorus.author@gmail.com" -ForegroundColor Cyan
        $bsTaskId = $bsTask.id
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================
# STEP 8: Check-in + submit evidence for charging task
# ================================================
Write-Host ""
Write-Host "[STEP 8] Check-in + submit evidence (Charging task)..." -ForegroundColor Yellow
if ($chargingTaskId) {
    try {
        # Check-in at exact station coordinates (collaborator location is same)
        $ciBody = @{ lat = $lat; lng = $lng; deviceNote = "Test check-in Hoang Mai" } | ConvertTo-Json
        $ci = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/check-in" -Method POST -Headers $headers2 -ContentType "application/json" -Body $ciBody
        Write-Host "    [OK] Checked-in: status=$($ci.status)" -ForegroundColor Green

        # Submit evidence
        if ($objectKey) {
            $evBody = @{ photoObjectKey = $objectKey; note = "Test evidence Hoang Mai Charging Station" } | ConvertTo-Json
            $ev = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/submit-evidence" -Method POST -Headers $headers2 -ContentType "application/json" -Body $evBody
            Write-Host "    [OK] Evidence submitted: status=$($ev.status)" -ForegroundColor Green
        }
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

# ================================================
# STEP 9: Check-in + submit for battery swap task
# ================================================
Write-Host ""
Write-Host "[STEP 9] Check-in + submit evidence (Battery Swap task)..." -ForegroundColor Yellow
if ($bsTaskId) {
    try {
        $bsCiBody = @{
            lat = $lat
            lng = $lng
            deviceNote = "Test BS check-in"
            actualTotalBatteries = 24
            actualAvailableBatteries = 18
            observedAvgChargePowerKw = 38.5
        } | ConvertTo-Json
        $bsCi = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/checkin" -Method POST -Headers $headers2 -ContentType "application/json" -Body $bsCiBody
        Write-Host "    [OK] BS Checked-in: status=$($bsCi.status)" -ForegroundColor Green

        if ($objectKey) {
            $bsEvBody = @{ photoObjectKey = $objectKey; note = "Test BS evidence Hoang Mai" } | ConvertTo-Json
            $bsEv = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/evidence" -Method POST -Headers $headers2 -ContentType "application/json" -Body $bsEvBody
            Write-Host "    [OK] BS Evidence submitted: status=$($bsEv.status)" -ForegroundColor Green
        }
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

# ================================================
# STEP 10: Admin reviews tasks as PASS/FAIL
# ================================================
Write-Host ""
Write-Host "[STEP 10] Admin reviews tasks..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# Get submitted tasks
$submittedTasks = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks?status=SUBMITTED&page=0&size=50" -Method GET -Headers $headers
$chargingSubmitted = $submittedTasks.content | Where-Object { $_.id -eq $chargingTaskId }
$bsSubmittedTasks = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification-tasks?status=SUBMITTED&page=0&size=50" -Method GET -Headers $headers
$bsSubmitted = $bsSubmittedTasks.content | Where-Object { $_.id -eq $bsTaskId }

if ($chargingSubmitted) {
    Write-Host "  Reviewing Charging task as PASS..." -ForegroundColor Gray
    try {
        $reviewBody = @{ result = "PASS"; adminNote = "Test review PASS" } | ConvertTo-Json
        $r = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId/review" -Method POST -Headers $headers -ContentType "application/json" -Body $reviewBody
        Write-Host "    [OK] TASK_REVIEWED_PASS email -> luquorus.author@gmail.com" -ForegroundColor Cyan
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($bsSubmitted) {
    Write-Host "  Reviewing Battery Swap task as FAIL..." -ForegroundColor Gray
    try {
        $bsReviewBody = @{ result = "FAIL"; adminNote = "Test review FAIL" } | ConvertTo-Json
        $bsR = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification-tasks/$bsTaskId/review" -Method POST -Headers $headers -ContentType "application/json" -Body $bsReviewBody
        Write-Host "    [OK] TASK_REVIEWED_FAIL email -> luquorus.author@gmail.com" -ForegroundColor Cyan
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================
# VERIFY ALL NOTIFICATIONS
# ================================================
Write-Host ""
Write-Host "=== Verifying all notifications ===" -ForegroundColor Cyan
Start-Sleep -Seconds 2
try {
    $notifs = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications?page=0&size=50" -Method GET -Headers $headers2
    Write-Host "Total: $($notifs.totalElements), Unread: $($notifs.unreadCount)"
    $notifs.notifications | ForEach-Object {
        Write-Host "  [$($_.type)] $($_.title)" -ForegroundColor White
    }
} catch {
    Write-Host "Could not fetch: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "  Created: Hoang Mai Charging Station ($chargingStationId)" -ForegroundColor White
Write-Host "  Created: Hoang Mai Battery Swap Station ($swapStationId)" -ForegroundColor White
Write-Host "  Uploaded: Evidence image ($objectKey)" -ForegroundColor White
Write-Host ""
Write-Host "  Email notifications sent to luquorus.author@gmail.com:" -ForegroundColor Yellow
Write-Host "    1. TASK_ASSIGNED (Charging)" -ForegroundColor White
Write-Host "    2. TASK_ASSIGNED (Battery Swap)" -ForegroundColor White
Write-Host "    3. TASK_REVIEWED_PASS (if submitted)" -ForegroundColor White
Write-Host "    4. TASK_REVIEWED_FAIL (if submitted)" -ForegroundColor White
Write-Host ""
Write-Host "  Check inbox + spam folder!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
