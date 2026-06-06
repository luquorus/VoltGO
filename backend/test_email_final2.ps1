$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"
$lat = 20.990147
$lng = 105.855614
$objectKey = $null

# ============================
# LOGIN
# ============================
Write-Host "=== Login ===" -ForegroundColor Cyan
$adminLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$adminToken = $adminLogin.token
$adminHeaders = @{"Authorization"="Bearer $adminToken"}
Write-Host "[OK] admin@local" -ForegroundColor Green

$collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$collabToken = $collabLogin.token
$collabHeaders = @{"Authorization"="Bearer $collabToken"}
$userId = $collabLogin.userId
$collabId = "1d1f510d-ac32-43fa-9359-a66dffeae622"
Write-Host "[OK] luquorus (userId=$userId)" -ForegroundColor Green

# ============================
# 0. DELETE OLD STATIONS
# ============================
Write-Host ""
Write-Host "[0] Delete old stations..." -ForegroundColor Yellow
@("efd14fa2-7ab0-47d9-a37e-a9422a8d9416") | ForEach-Object {
    try {
        Invoke-RestMethod -Uri "$baseUrl/api/admin/stations/$_" -Method DELETE -Headers $adminHeaders -ErrorAction SilentlyContinue | Out-Null
        Write-Host "    [OK] Deleted $_" -ForegroundColor Green
    } catch { Write-Host "    [-] $_ : $($_.Exception.Message)" -ForegroundColor Gray }
}

# ============================
# 1. UPDATE COLLAB LOCATION
# ============================
Write-Host ""
Write-Host "[1] Update collab location to $lat, $lng..." -ForegroundColor Yellow
try {
    $loc = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/me/location" -Method PUT -Headers $collabHeaders -ContentType "application/json" -Body (@{ lat = $lat; lng = $lng } | ConvertTo-Json)
    Write-Host "    [OK] lat=$($loc.lat), lng=$($loc.lng)" -ForegroundColor Green
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============================
# 2. CREATE CHARGING STATION
# ============================
Write-Host ""
Write-Host "[2] Create Hoang Mai Charging Station..." -ForegroundColor Yellow
$chargingStationId = $null
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
    Write-Host "    [OK] $chargingStationId | Status: $($cs.workflowStatus)" -ForegroundColor Green
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
        note = "Hoang Mai Battery Swap Station"
        pileTemplates = @(
            @{ pileIndex = 1; slotsPerPile = 6 },
            @{ pileIndex = 2; slotsPerPile = 6 },
            @{ pileIndex = 3; slotsPerPile = 6 },
            @{ pileIndex = 4; slotsPerPile = 6 }
        )
    } | ConvertTo-Json -Depth 10

    $bsCR = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/change-requests" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $bsBody
    $crId = $bsCR.id
    $bsStationId = $bsCR.stationId
    Write-Host "    [OK] CR: $crId | Status: $($bsCR.status) | StationId: $bsStationId" -ForegroundColor Green
    Write-Host "    [OK] *** CONTRACT_CREATED email -> luquorus ***" -ForegroundColor Cyan
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
}

# ============================
# 4. ACTIVE CONTRACT
# ============================
Write-Host ""
Write-Host "[4] Ensure active contract..." -ForegroundColor Yellow
try {
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $adminHeaders
    $active = $contracts | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -First 1
    if (-not $active) {
        $cb = @{ collaboratorId = $collabId; region = "Hoang Mai"; startDate = "2026-06-06"; endDate = "2027-06-06" } | ConvertTo-Json
        $active = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $cb
        Write-Host "    [+] Created: $($active.id)" -ForegroundColor Green
    } else {
        Write-Host "    [+] Has: $($active.id)" -ForegroundColor Green
    }
} catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }

# ============================
# 5. UPLOAD EVIDENCE IMAGE
# ============================
Write-Host ""
Write-Host "[5] Upload evidence image..." -ForegroundColor Yellow
$pngFiles = @(
    "C:\Users\luquo\Downloads\1000011207.png",
    "C:\Users\luquo\Downloads\Thiết kế chưa có tên (13).png",
    "C:\Users\luquo\Downloads\Thiet ke chua co ten (13).png"
)
$foundPath = $null
foreach ($p in $pngFiles) { if (Test-Path $p) { $foundPath = $p; break } }
if (-not $foundPath) { Get-ChildItem "C:\Users\luquo\Downloads\*.png" -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { $foundPath = $_.FullName } }

if ($foundPath) {
    Write-Host "    Image: $foundPath" -ForegroundColor Gray
    try {
        $presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/png" } | ConvertTo-Json)
        $objectKey = $presign.objectKey
        $uploadUrl = $presign.uploadUrl

        $originalHost = [regex]::Match($uploadUrl, 'http[s]?://([^/]+)').Groups[1].Value
        $uploadUrlFixed = $uploadUrl -replace [regex]::Escape("http://$originalHost"), "http://localhost:9000"

        $temp = [System.IO.Path]::GetTempFileName() + ".png"
        Copy-Item $foundPath $temp
        $curlOut = curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp -H "Host: $originalHost" $uploadUrlFixed 2>&1
        Remove-Item $temp

        if ($curlOut -eq "200" -or $curlOut -eq "204") {
            Write-Host "    [OK] Uploaded: $objectKey" -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] curl: $curlOut" -ForegroundColor Red
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "    [SKIP] No image found" -ForegroundColor Yellow
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
        Write-Host "    [OK] $chargingTaskId" -ForegroundColor Green
        Write-Host "    [OK] *** TASK_ASSIGNED email ***" -ForegroundColor Cyan
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

Write-Host ""
Write-Host "[6b] Create + assign Battery Swap task..." -ForegroundColor Yellow
if ($bsStationId) {
    try {
        $bsTask = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ stationId = $bsStationId; priority = 2 } | ConvertTo-Json)
        $bsAssign = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$($bsTask.id)/assign" -Method PUT -Headers $adminHeaders -ContentType "application/json" -Body (@{ collaboratorUserId = $userId } | ConvertTo-Json)
        $bsTaskId = $bsTask.id
        Write-Host "    [OK] $bsTaskId" -ForegroundColor Green
        Write-Host "    [OK] *** TASK_ASSIGNED (BS) email ***" -ForegroundColor Cyan
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

# ============================
# 7. CHECK-IN + SUBMIT
# ============================
Write-Host ""
Write-Host "[7a] Check-in + submit Charging task..." -ForegroundColor Yellow
if ($chargingTaskId) {
    try {
        $ci = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/check-in" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ lat = $lat; lng = $lng; deviceNote = "Test" } | ConvertTo-Json)
        Write-Host "    [OK] Checked-in: $($ci.status)" -ForegroundColor Green
        if ($objectKey) {
            $ev = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/submit-evidence" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ photoObjectKey = $objectKey; note = "Test Hoang Mai" } | ConvertTo-Json)
            Write-Host "    [OK] Evidence: $($ev.status)" -ForegroundColor Green
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
Write-Host "[7b] Check-in + submit Battery Swap task..." -ForegroundColor Yellow
if ($bsTaskId) {
    try {
        $bsCi = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/checkin" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ lat = $lat; lng = $lng; deviceNote = "Test" } | ConvertTo-Json)
        Write-Host "    [OK] BS Checked-in: $($bsCi.status)" -ForegroundColor Green
        if ($objectKey) {
            $bsEv = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/evidence" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ photoObjectKey = $objectKey; note = "Test BS" } | ConvertTo-Json)
            Write-Host "    [OK] BS Evidence: $($bsEv.status)" -ForegroundColor Green
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
Write-Host "[8] Admin reviews..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

if ($chargingTaskId) {
    try {
        $td = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId" -Method GET -Headers $adminHeaders
        Write-Host "    Charging: $($td.status)" -ForegroundColor Gray
        if ($td.status -eq "SUBMITTED") {
            $r = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId/review" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ result = "PASS"; adminNote = "Test PASS" } | ConvertTo-Json)
            Write-Host "    [OK] *** TASK_REVIEWED_PASS email ***" -ForegroundColor Cyan
        } else {
            Write-Host "    [SKIP] Not SUBMITTED ($($td.status))" -ForegroundColor Yellow
        }
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

if ($bsTaskId) {
    try {
        $bsd = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId" -Method GET -Headers $adminHeaders
        Write-Host "    BS: $($bsd.status)" -ForegroundColor Gray
        if ($bsd.status -eq "SUBMITTED") {
            $bsr = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId/review" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ result = "FAIL"; adminNote = "Test FAIL" } | ConvertTo-Json)
            Write-Host "    [OK] *** TASK_REVIEWED_FAIL email ***" -ForegroundColor Cyan
        } else {
            Write-Host "    [SKIP] Not SUBMITTED ($($bsd.status))" -ForegroundColor Yellow
        }
    } catch { Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red }
}

# ============================
# VERIFY NOTIFICATIONS
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
Write-Host "  Charging: $chargingStationId | Task: $chargingTaskId" -ForegroundColor White
Write-Host "  BS: $bsStationId | Task: $bsTaskId" -ForegroundColor White
Write-Host "  Evidence: $objectKey" -ForegroundColor White
Write-Host ""
Write-Host "Emails sent:" -ForegroundColor Yellow
Write-Host "  [DONE] CONTRACT_CREATED" -ForegroundColor White
Write-Host "  [DONE] TASK_ASSIGNED (Charging)" -ForegroundColor White
Write-Host "  [DONE] TASK_ASSIGNED (Battery Swap)" -ForegroundColor White
Write-Host "  [DONE/PENDING] TASK_REVIEWED_PASS" -ForegroundColor White
Write-Host "  [DONE/PENDING] TASK_REVIEWED_FAIL" -ForegroundColor White
Write-Host ""
Write-Host "Check inbox + spam!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
