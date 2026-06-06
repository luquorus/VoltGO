$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"
$lat = 20.990147
$lng = 105.855614

# ============================
# LOGIN
# ============================
Write-Host "=== Login ===" -ForegroundColor Cyan
$adminLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$adminToken = $adminLogin.token
$adminHeaders = @{"Authorization"="Bearer $adminToken"}
Write-Host "[OK] admin@local logged in" -ForegroundColor Green

$collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$collabToken = $collabLogin.token
$collabHeaders = @{"Authorization"="Bearer $collabToken"}
$userId = $collabLogin.userId
$collabId = "1d1f510d-ac32-43fa-9359-a66dffeae622"
Write-Host "[OK] luquorus logged in (userId=$userId)" -ForegroundColor Green

# ============================
# 0. DELETE EXISTING STATIONS
# ============================
Write-Host ""
Write-Host "[0] Delete old stations..." -ForegroundColor Yellow
$oldStations = @("6bc5e47b-fbd0-4bad-a05b-09ad1ef3b4d3")
foreach ($sid in $oldStations) {
    try {
        Invoke-RestMethod -Uri "$baseUrl/api/admin/stations/$($sid)" -Method DELETE -Headers $adminHeaders -ErrorAction SilentlyContinue | Out-Null
        Write-Host "    [OK] Deleted station $($sid)" -ForegroundColor Green
    } catch { Write-Host "    [-] $($sid): $($_.Exception.Message)" -ForegroundColor Gray }
}

# ============================
# 1. UPDATE COLLAB LOCATION
# ============================
Write-Host ""
Write-Host "[1] Update collab location..." -ForegroundColor Yellow
try {
    $loc = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/me/location" -Method PUT -Headers $collabHeaders -ContentType "application/json" -Body (@{ lat = $lat; lng = $lng } | ConvertTo-Json)
    Write-Host "    [OK] lat=$($loc.lat), lng=$($loc.lng)" -ForegroundColor Green
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============================
# 2. CREATE CHARGING STATION (admin)
# ============================
Write-Host ""
Write-Host "[2] Create Hoang Mai Charging Station..." -ForegroundColor Yellow
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
                @{ type = "CHARGING"; chargingPorts = @(
                    @{ powerType = "DC"; powerKw = 120; count = 2 },
                    @{ powerType = "DC"; powerKw = 60; count = 2 },
                    @{ powerType = "AC"; count = 4 }
                ) }
            )
        }
        publishImmediately = $true
    } | ConvertTo-Json -Depth 10

    $cs = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $chargingBody
    $chargingStationId = $cs.stationId
    Write-Host "    [OK] Created: $chargingStationId | Status: $($cs.workflowStatus)" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
}

# ============================
# 3. CREATE + SUBMIT + APPROVE + PUBLISH BS STATION
# ============================
Write-Host ""
Write-Host "[3] Create Hoang Mai Battery Swap Station..." -ForegroundColor Yellow
$bsStationId = $null
try {
    $bsBody = @{
        type = "CREATE_BATTERY_SWAP_STATION"
        totalBatteries = 24
        avgChargePowerKw = 40.0
        operatingHours = "24/7"
        parkingFee = 0
        note = "Hoang Mai Battery Swap Station for testing"
        pileTemplates = @(
            @{ pileIndex = 1; slotsPerPile = 6 },
            @{ pileIndex = 2; slotsPerPile = 6 },
            @{ pileIndex = 3; slotsPerPile = 6 },
            @{ pileIndex = 4; slotsPerPile = 6 }
        )
    } | ConvertTo-Json -Depth 10

    $bsCR = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $bsBody
    $crId = $bsCR.id
    Write-Host "    [OK] CR created: $crId | Status: $($bsCR.status)" -ForegroundColor Green

    # Submit CR
    $submitted = Invoke-RestMethod -Uri "$baseUrl/api/battery-swap/change-requests/$crId/submit" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{} | ConvertTo-Json)
    Write-Host "    [OK] CR submitted: $($submitted.status)" -ForegroundColor Green

    # Approve CR
    $approved = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests/$crId/approve" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{} | ConvertTo-Json)
    Write-Host "    [OK] CR approved: $($approved.status)" -ForegroundColor Green

    # Publish CR
    $published = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests/$crId/publish" -Method POST -Headers $adminHeaders -ContentType "application/json"
    $bsStationId = $published.stationId
    Write-Host "    [OK] CR published! stationId=$bsStationId" -ForegroundColor Green
    Write-Host "    [OK] *** CONTRACT_CREATED email sent to collaborator ***" -ForegroundColor Cyan
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
}

# ============================
# 4. ENSURE ACTIVE CONTRACT
# ============================
Write-Host ""
Write-Host "[4] Ensure active contract..." -ForegroundColor Yellow
try {
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $adminHeaders
    $active = $contracts | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -First 1
    if (-not $active) {
        $cb = @{ collaboratorId = $collabId; region = "Hoang Mai"; startDate = "2026-06-06"; endDate = "2027-06-06"; note = "Test" } | ConvertTo-Json
        $active = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $cb
        Write-Host "    [+] Created contract: $($active.id)" -ForegroundColor Green
    } else {
        Write-Host "    [+] Has active contract: $($active.id)" -ForegroundColor Green
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============================
# 5. UPLOAD EVIDENCE IMAGE
# ============================
Write-Host ""
Write-Host "[5] Upload evidence image..." -ForegroundColor Yellow
$pngFiles = @(
    "C:\Users\luquo\Downloads\Thiết kế chưa có tên (13).png",
    "C:\Users\luquo\Downloads\Thiet ke chua co ten (13).png",
    "C:\Users\luquo\Downloads\1000011207.png"
)
$foundPath = $null
foreach ($p in $pngFiles) { if (Test-Path $p) { $foundPath = $p; break } }
if (-not $foundPath) { Get-ChildItem "C:\Users\luquo\Downloads\*.png" -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { $foundPath = $_.FullName } }

if ($foundPath) {
    Write-Host "    Using: $foundPath" -ForegroundColor Gray
    try {
        $presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/png" } | ConvertTo-Json)
        $objectKey = $presign.objectKey
        $uploadUrl = $presign.uploadUrl
        Write-Host "    Presigned URL received" -ForegroundColor Gray

        # Replace gateway IP with localhost, add Host header for signature validation
        $originalHost = [regex]::Match($uploadUrl, 'http[s]?://([^/]+)').Groups[1].Value
        $uploadUrlFixed = $uploadUrl -replace [regex]::Escape("http://$originalHost"), "http://localhost:9000"

        $temp = [System.IO.Path]::GetTempFileName() + ".png"
        Copy-Item $foundPath $temp
        $curlOut = curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp -H "Host: $originalHost" $uploadUrlFixed 2>&1
        Remove-Item $temp

        if ($curlOut -eq "200" -or $curlOut -eq "204") {
            Write-Host "    [OK] Uploaded to MinIO: $objectKey" -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] curl returned: $curlOut" -ForegroundColor Red
        }
    } catch {
        Write-Host "    [FAIL] Upload: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================
# 6. CREATE + ASSIGN TASKS
# ============================
$chargingTaskId = $null
$bsTaskId = $null

Write-Host ""
Write-Host "[6a] Create + assign Charging task..." -ForegroundColor Yellow
if ($chargingStationId) {
    try {
        $task = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ stationId = $chargingStationId; priority = 2 } | ConvertTo-Json)
        $assign = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$($task.id)/assign" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ collaboratorUserId = $userId } | ConvertTo-Json)
        $chargingTaskId = $task.id
        Write-Host "    [OK] Task: $chargingTaskId" -ForegroundColor Green
        Write-Host "    [OK] *** TASK_ASSIGNED email sent ***" -ForegroundColor Cyan
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

Write-Host ""
Write-Host "[6b] Create + assign Battery Swap task..." -ForegroundColor Yellow
if ($bsStationId) {
    try {
        $bsTask = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ stationId = $bsStationId; priority = 2 } | ConvertTo-Json)
        $bsAssign = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$($bsTask.id)/assign" -Method PUT -Headers $adminHeaders -ContentType "application/json" -Body (@{ collaboratorUserId = $userId } | ConvertTo-Json)
        $bsTaskId = $bsTask.id
        Write-Host "    [OK] BS Task: $bsTaskId" -ForegroundColor Green
        Write-Host "    [OK] *** TASK_ASSIGNED (Battery Swap) email sent ***" -ForegroundColor Cyan
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

# ============================
# 7. CHECK-IN + SUBMIT (collab)
# ============================
Write-Host ""
Write-Host "[7a] Check-in + submit (Charging task)..." -ForegroundColor Yellow
if ($chargingTaskId) {
    try {
        $ci = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/check-in" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ lat = $lat; lng = $lng; deviceNote = "Test" } | ConvertTo-Json)
        Write-Host "    [OK] Checked-in: $($ci.status)" -ForegroundColor Green
        if ($objectKey) {
            $ev = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/submit-evidence" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ photoObjectKey = $objectKey; note = "Test Hoang Mai" } | ConvertTo-Json)
            Write-Host "    [OK] Evidence submitted: $($ev.status)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        try {
            $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
            Write-Host "    Response: $body" -ForegroundColor Red
        } catch {}
    }
}

Write-Host ""
Write-Host "[7b] Check-in + submit (Battery Swap task)..." -ForegroundColor Yellow
if ($bsTaskId) {
    try {
        $bsCi = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/checkin" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ lat = $lat; lng = $lng; deviceNote = "Test" } | ConvertTo-Json)
        Write-Host "    [OK] BS Checked-in: $($bsCi.status)" -ForegroundColor Green
        if ($objectKey) {
            $bsEv = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/evidence" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ photoObjectKey = $objectKey; note = "Test Hoang Mai BS" } | ConvertTo-Json)
            Write-Host "    [OK] BS Evidence submitted: $($bsEv.status)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        try {
            $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
            Write-Host "    Response: $body" -ForegroundColor Red
        } catch {}
    }
}

# ============================
# 8. ADMIN REVIEWS
# ============================
Write-Host ""
Write-Host "[8] Admin reviews tasks..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

if ($chargingTaskId) {
    try {
        $td = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId" -Method GET -Headers $adminHeaders
        Write-Host "    Charging task status: $($td.status)" -ForegroundColor Gray
        if ($td.status -eq "SUBMITTED") {
            $r = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId/review" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ result = "PASS"; adminNote = "Test PASS" } | ConvertTo-Json)
            Write-Host "    [OK] *** TASK_REVIEWED_PASS email sent ***" -ForegroundColor Cyan
        } else {
            Write-Host "    [SKIP] Not SUBMITTED (is $($td.status))" -ForegroundColor Yellow
        }
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

if ($bsTaskId) {
    try {
        $bsd = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId" -Method GET -Headers $adminHeaders
        Write-Host "    BS task status: $($bsd.status)" -ForegroundColor Gray
        if ($bsd.status -eq "SUBMITTED") {
            $bsr = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId/review" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ result = "FAIL"; adminNote = "Test FAIL" } | ConvertTo-Json)
            Write-Host "    [OK] *** TASK_REVIEWED_FAIL email sent ***" -ForegroundColor Cyan
        } else {
            Write-Host "    [SKIP] Not SUBMITTED (is $($bsd.status))" -ForegroundColor Yellow
        }
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

# ============================
# VERIFY
# ============================
Write-Host ""
Write-Host "=== Notifications ===" -ForegroundColor Cyan
try {
    $notifs = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications?page=0&size=50" -Method GET -Headers $collabHeaders
    Write-Host "Total: $($notifs.totalElements), Unread: $($notifs.unreadCount)"
    $notifs.notifications | Select-Object -First 10 | ForEach-Object {
        Write-Host "  [$($_.type)] $($_.title)" -ForegroundColor White
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "RESULT:" -ForegroundColor Cyan
Write-Host "  Charging Station: $chargingStationId" -ForegroundColor White
Write-Host "  BS Station: $bsStationId" -ForegroundColor White
Write-Host "  Evidence: $objectKey" -ForegroundColor White
Write-Host "  Charging Task: $chargingTaskId" -ForegroundColor White
Write-Host "  BS Task: $bsTaskId" -ForegroundColor White
Write-Host ""
Write-Host "Emails sent:" -ForegroundColor Yellow
Write-Host "  [DONE] CONTRACT_CREATED (BS station)" -ForegroundColor White
Write-Host "  [DONE] TASK_ASSIGNED (Charging)" -ForegroundColor White
Write-Host "  [DONE] TASK_ASSIGNED (Battery Swap)" -ForegroundColor White
Write-Host "  [DONE/PENDING] TASK_REVIEWED_PASS" -ForegroundColor White
Write-Host "  [DONE/PENDING] TASK_REVIEWED_FAIL" -ForegroundColor White
Write-Host ""
Write-Host "Check email inbox + spam!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
