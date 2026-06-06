$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

# ============================
# CONFIG
# ============================
$adminEmail = "admin2@local"
$adminPass = "Admin@456"
$collabEmail = "collab1@testt"
$collabPass = "Admin@123"
$imagePath = "C:\Users\luquo\Downloads\1387883b-6210-4a40-8760-26fbaf567e49.jpeg"
$gatewayIp = "192.168.65.254"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " VOLTGO - Full Verification Task Test (Charging + Battery Swap)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Admin : $adminEmail" -ForegroundColor White
Write-Host " Collab: $collabEmail" -ForegroundColor White
Write-Host " Image : $imagePath" -ForegroundColor White
Write-Host ""

# ============================
# 1. LOGIN
# ============================
Write-Host "[1] Login Admin..." -ForegroundColor Yellow
try {
    $adminLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"=$adminEmail;"password"=$adminPass} | ConvertTo-Json)
    $adminToken = $adminLogin.token
    $adminHeaders = @{"Authorization"="Bearer $adminToken"}
    Write-Host "    [OK] Admin: $adminEmail | userId=$($adminLogin.userId)" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2] Login Collaborator..." -ForegroundColor Yellow
try {
    $collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"=$collabEmail;"password"=$collabPass} | ConvertTo-Json)
    $collabToken = $collabLogin.token
    $collabHeaders = @{"Authorization"="Bearer $collabToken"}
    $collabUserId = $collabLogin.userId
    Write-Host "    [OK] Collab: $collabEmail | userId=$collabUserId" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================
# 2. GET COLLABORATOR PROFILE
# ============================
Write-Host ""
Write-Host "[3] Get collaborator profile..." -ForegroundColor Yellow
try {
    $profile = Invoke-RestMethod -Uri "$baseUrl/api/collab/web/me/profile" -Method GET -Headers $collabHeaders
    $collabLat = $profile.lat
    $collabLng = $profile.lng
    Write-Host "    [OK] Name=$($profile.fullName) | lat=$collabLat | lng=$collabLng" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

# ============================
# 3. ENSURE ACTIVE CONTRACT
# ============================
Write-Host ""
Write-Host "[4] Ensure active contract..." -ForegroundColor Yellow
try {
    $collaborators = Invoke-RestMethod -Uri "$baseUrl/api/admin/collaborators?page=0&size=100" -Method GET -Headers $adminHeaders
    $collab = $collaborators.content | Where-Object { $_.email -eq $collabEmail } | Select-Object -First 1
    $collabId = $collab.id
    Write-Host "    [OK] Collab profile: id=$collabId" -ForegroundColor Green

    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $adminHeaders
    $activeContract = $contracts | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -First 1

    if (-not $activeContract) {
        $cb = @{ collaboratorId = $collabId; region = "Hanoi"; startDate = "2026-06-06"; endDate = "2027-06-06" } | ConvertTo-Json
        $activeContract = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $cb
        Write-Host "    [OK] Contract created: $($activeContract.id)" -ForegroundColor Green
    } else {
        Write-Host "    [OK] Has active contract: $($activeContract.id)" -ForegroundColor Green
    }
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

# ============================
# 4. LIST STATIONS
# ============================
Write-Host ""
Write-Host "[5] List stations (Charging + Battery Swap)..." -ForegroundColor Yellow
try {
    # Charging stations
    $chargingStations = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations?page=0&size=50" -Method GET -Headers $adminHeaders
    $chargingList = $chargingStations.content
    Write-Host "    [OK] Charging stations: $($chargingStations.totalElements)" -ForegroundColor Green

    # Filter out Hoang Mai
    $chargingSelected = @()
    $filteredCharging = $chargingList | Where-Object {
        $name = ($_.name -replace " ", "").ToLower()
        $name -notlike "*hoangmai*"
    }
    if ($filteredCharging.Count -ge 1) {
        $chargingSelected = @($filteredCharging[0])
    } else {
        $chargingSelected = @($chargingList[0])
        Write-Host "    [WARN] Using first available charging station" -ForegroundColor Yellow
    }

    # Battery swap stations
    $bsStations = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/stations?page=0&size=50" -Method GET -Headers $adminHeaders
    $bsList = $bsStations.content
    Write-Host "    [OK] Battery Swap stations: $($bsStations.totalElements)" -ForegroundColor Green

    $bsSelected = @()
    $filteredBS = $bsList | Where-Object {
        $name = ($_.name -replace " ", "").ToLower()
        $name -notlike "*hoangmai*"
    }
    if ($filteredBS.Count -ge 3) {
        $bsSelected = @($filteredBS[0], $filteredBS[1], $filteredBS[2])
    } elseif ($filteredBS.Count -gt 0) {
        $bsSelected = $filteredBS
        Write-Host "    [WARN] Only $($filteredBS.Count) non-HoangMai BS stations" -ForegroundColor Yellow
    } else {
        $bsSelected = @($bsList[0], $bsList[1], $bsList[2])
        Write-Host "    [WARN] Using first 3 available BS stations" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "    Charging station for test:" -ForegroundColor Cyan
    Write-Host "      $($chargingSelected[0].name) [$($chargingSelected[0].id)]" -ForegroundColor White
    Write-Host "      Location: lat=$($chargingSelected[0].lat), lng=$($chargingSelected[0].lng)" -ForegroundColor Gray

    Write-Host ""
    Write-Host "    Battery Swap stations for test:" -ForegroundColor Cyan
    foreach ($s in $bsSelected) {
        Write-Host "      $($s.name) [$($s.id)]" -ForegroundColor White
        Write-Host "        Location: lat=$($s.lat), lng=$($s.lng)" -ForegroundColor Gray
    }
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
    exit 1
}

# ============================
# 5. UPLOAD EVIDENCE IMAGE
# ============================
Write-Host ""
Write-Host "[6] Upload evidence image to MinIO..." -ForegroundColor Yellow

if (-not (Test-Path $imagePath)) {
    Write-Host "    [FAIL] Image not found: $imagePath" -ForegroundColor Red
    exit 1
}

$objectKeys = @()  # Store multiple object keys for different submissions
$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
$imageSizeKB = [Math]::Round($imageBytes.Length / 1024, 1)
Write-Host "    Image: $imagePath ($imageSizeKB KB)" -ForegroundColor Gray

function Upload-Image {
    param([string]$contentType = "image/jpeg")

    $presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = $contentType } | ConvertTo-Json)
    $objectKey = $presign.objectKey
    $uploadUrl = $presign.uploadUrl

    # FIX: Replace Docker gateway IP with localhost, keep Host header for signature
    $urlFixed = $uploadUrl -replace [regex]::Escape($gatewayIp), "localhost"

    $ext = [System.IO.Path]::GetExtension($imagePath)
    $temp = [System.IO.Path]::GetTempFileName() + $ext
    [System.IO.File]::WriteAllBytes($temp, $imageBytes)

    Write-Host "    URL: $urlFixed" -ForegroundColor Gray
    $code = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp -H "Host: $gatewayIp`:9000" $urlFixed 2>&1)
    Remove-Item $temp -Force

    if ($code -eq "200" -or $code -eq "204") {
        Write-Host "    [OK] Uploaded: $objectKey" -ForegroundColor Green
        return $objectKey
    } else {
        Write-Host "    [FAIL] curl returned: $code" -ForegroundColor Red
        return $null
    }
}

$objectKeys += Upload-Image "image/jpeg"
if (-not $objectKeys[0]) {
    Write-Host "    [FAIL] Upload failed, cannot proceed" -ForegroundColor Red
    exit 1
}
Write-Host "    [OK] Primary evidence: $($objectKeys[0])" -ForegroundColor Green

# ============================
# 6. HELPER: Get station lat/lng
# ============================
function Get-StationLocation {
    param($station)

    # Try to get lat/lng from the station object
    $lat = $station.lat
    $lng = $station.lng

    if (-not $lat -or -not $lng) {
        # Try location object
        if ($station.location) {
            $lat = $station.location.lat
            $lng = $station.location.lng
        }
    }

    if (-not $lat -or -not $lng) {
        # Use collab location or default
        $lat = if ($collabLat) { $collabLat } else { 21.028511 }
        $lng = if ($collabLng) { $collabLng } else { 105.854456 }
        Write-Host "    [WARN] Station has no location, using collab location: lat=$lat, lng=$lng" -ForegroundColor Yellow
    }

    return @{ lat = $lat; lng = $lng }
}

# ============================
# 7a. CHARGING VERIFICATION FLOW
# ============================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PART A: CHARGING STATION VERIFICATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$chargingStation = $chargingSelected[0]
    $csId = $chargingStation.stationId
    $csName = $chargingStation.name
$csLoc = Get-StationLocation $chargingStation
Write-Host "Station: $csName" -ForegroundColor White
Write-Host "Location: lat=$($csLoc.lat), lng=$($csLoc.lng)" -ForegroundColor Gray

$chargingTaskId = $null

Write-Host ""
Write-Host "[A1] Create Charging Verification Task..." -ForegroundColor Yellow
try {
    $task = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ stationId = $csId; priority = 2 } | ConvertTo-Json)
    $chargingTaskId = $task.id
    Write-Host "    [OK] Task: $chargingTaskId | status=$($task.status)" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[A2] Assign Charging Task to $collabEmail..." -ForegroundColor Yellow
try {
    $assign = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId/assign" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ collaboratorUserId = $collabUserId } | ConvertTo-Json)
    Write-Host "    [OK] Assigned: $($assign.status)" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[A3] Check-in Charging Task (lat=$($csLoc.lat), lng=$($csLoc.lng))..." -ForegroundColor Yellow
try {
    $ci = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/check-in" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ lat = $csLoc.lat; lng = $csLoc.lng; deviceNote = "Auto-test check-in at $csName" } | ConvertTo-Json)
    Write-Host "    [OK] Checked-in: $($ci.status)" -ForegroundColor Green
    if ($ci.checkin) {
        Write-Host "    Distance: $($ci.checkin.distanceM)m" -ForegroundColor Gray
    }
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[A4] Submit evidence for Charging Task..." -ForegroundColor Yellow
try {
    $ev = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/tasks/$chargingTaskId/submit-evidence" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ photoObjectKey = $objectKeys[0]; note = "Evidence photo for $csName - auto-test" } | ConvertTo-Json)
    Write-Host "    [OK] Evidence submitted: $($ev.status)" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[A5] Admin reviews Charging Task..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
try {
    $detail = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId" -Method GET -Headers $adminHeaders
    Write-Host "    Current status: $($detail.status)" -ForegroundColor Gray

    if ($detail.status -eq "SUBMITTED") {
        $review = Invoke-RestMethod -Uri "$baseUrl/api/admin/verification-tasks/$chargingTaskId/review" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ result = "PASS"; adminNote = "Admin review - $csName - auto-test PASS" } | ConvertTo-Json)
        Write-Host "    [OK] Reviewed as PASS! Final status: $($review.status)" -ForegroundColor Green
    } else {
        Write-Host "    [SKIP] Not SUBMITTED (current: $($detail.status))" -ForegroundColor Yellow
    }
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

# ============================
# 7b. BATTERY SWAP VERIFICATION FLOW (3 stations)
# ============================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PART B: BATTERY SWAP VERIFICATION (3 STATIONS)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$bsResults = @()

for ($i = 0; $i -lt $bsSelected.Count; $i++) {
    $bs = $bsSelected[$i]
    $bsId = $bs.id
    $bsName = $bs.name
    $bsLoc = Get-StationLocation $bs

    Write-Host ""
    Write-Host "--------------------------------------------------------" -ForegroundColor Magenta
    Write-Host " BS STATION [$($i+1)/$($bsSelected.Count)]: $bsName [$bsId]" -ForegroundColor Magenta
    Write-Host "--------------------------------------------------------" -ForegroundColor Magenta
    Write-Host "Location: lat=$($bsLoc.lat), lng=$($bsLoc.lng)" -ForegroundColor Gray

    $bsTaskId = $null

    # Upload fresh image for each station
    Write-Host ""
    Write-Host "[B$($i+1)a] Upload evidence image..." -ForegroundColor Yellow
    $freshKey = Upload-Image "image/jpeg"
    if ($freshKey) {
        $objectKeys += $freshKey
    }

    # Create task
    Write-Host ""
    Write-Host "[B$($i+1)b] Create BS Verification Task..." -ForegroundColor Yellow
    try {
        $bsTask = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{ stationId = $bsId; priority = 2 } | ConvertTo-Json)
        $bsTaskId = $bsTask.id
        Write-Host "    [OK] Task: $bsTaskId | status=$($bsTask.status)" -ForegroundColor Green
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    # Assign
    Write-Host ""
    Write-Host "[B$($i+1)c] Assign BS Task..." -ForegroundColor Yellow
    try {
        $bsAssign = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId/assign" -Method PUT -Headers $adminHeaders -ContentType "application/json" -Body (@{ collaboratorUserId = $collabUserId } | ConvertTo-Json)
        Write-Host "    [OK] Assigned: $($bsAssign.status)" -ForegroundColor Green
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    # Check-in
    Write-Host ""
    Write-Host "[B$($i+1)d] Check-in at station (lat=$($bsLoc.lat), lng=$($bsLoc.lng))..." -ForegroundColor Yellow
    try {
        $bsCi = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/checkin" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{
            lat = $bsLoc.lat
            lng = $bsLoc.lng
            deviceNote = "Auto-test check-in at $bsName"
            actualTotalBatteries = 24
            actualAvailableBatteries = 18
            observedAvgChargePowerKw = 40.0
        } | ConvertTo-Json)

        Write-Host "    [OK] Checked-in: $($bsCi.status)" -ForegroundColor Green
        if ($bsCi.checkin) {
            Write-Host "    Distance: $($bsCi.checkin.distanceM)m" -ForegroundColor Gray
            Write-Host "    Batteries: total=$($bsCi.checkin.actualTotalBatteries), available=$($bsCi.checkin.actualAvailableBatteries)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    # Submit evidence
    Write-Host ""
    Write-Host "[B$($i+1)e] Submit evidence..." -ForegroundColor Yellow
    if ($freshKey) {
        try {
            $bsEv = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$bsTaskId/evidence" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{
                photoObjectKey = $freshKey
                note = "Evidence for $bsName - auto-test"
            } | ConvertTo-Json)

            Write-Host "    [OK] Evidence submitted: $($bsEv.status)" -ForegroundColor Green
            if ($bsEv.evidences) {
                Write-Host "    Evidence count: $($bsEv.evidences.Count)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "    [SKIP] No uploaded image" -ForegroundColor Yellow
    }

    # Admin review
    Write-Host ""
    Write-Host "[B$($i+1)f] Admin reviews..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    try {
        $bsDetail = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId" -Method GET -Headers $adminHeaders
        Write-Host "    Current status: $($bsDetail.status)" -ForegroundColor Gray

        if ($bsDetail.status -eq "SUBMITTED") {
            $bsReview = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$bsTaskId/review" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body (@{
                result = "PASS"
                adminNote = "Admin review - $bsName - auto-test PASS"
            } | ConvertTo-Json)

            Write-Host "    [OK] Reviewed as PASS! Final status: $($bsReview.status)" -ForegroundColor Green
            if ($bsReview.review) {
                Write-Host "    Reviewed at: $($bsReview.review.reviewedAt)" -ForegroundColor Gray
            }
            $bsResults += @{ Station = $bsName; TaskId = $bsTaskId; Status = $bsReview.status }
        } else {
            Write-Host "    [SKIP] Not SUBMITTED (current: $($bsDetail.status))" -ForegroundColor Yellow
            $bsResults += @{ Station = $bsName; TaskId = $bsTaskId; Status = $bsDetail.status }
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        $bsResults += @{ Station = $bsName; TaskId = $bsTaskId; Status = "ERROR" }
    }
}

# ============================
# 8. SUMMARY
# ============================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " TEST SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Collaborator : $collabEmail ($collabUserId)" -ForegroundColor White
Write-Host "  Admin       : $adminEmail" -ForegroundColor White
Write-Host "  Images      : $($objectKeys.Count) uploaded" -ForegroundColor White
foreach ($k in $objectKeys) { Write-Host "    - $k" -ForegroundColor Gray }
Write-Host ""

Write-Host "  [A] Charging Station Verification:" -ForegroundColor Yellow
Write-Host "    Station : $csName" -ForegroundColor White
Write-Host "    Task ID : $chargingTaskId" -ForegroundColor Gray

Write-Host ""
Write-Host "  [B] Battery Swap Verification ($($bsResults.Count) stations):" -ForegroundColor Yellow
Write-Host "  " + ("-" * 65) -ForegroundColor DarkGray
foreach ($r in $bsResults) {
    $icon = if ($r.Status -eq "REVIEWED") { "[PASS]" } elseif ($r.Status -eq "SUBMITTED") { "[SUB]" } else { "[---]" }
    $color = if ($r.Status -eq "REVIEWED") { "Green" } elseif ($r.Status -eq "SUBMITTED") { "Yellow" } else { "Red" }
    Write-Host "  $icon $($r.Station)" -ForegroundColor $color
    Write-Host "       Task: $($r.TaskId) | Status: $($r.Status)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ALL TESTS COMPLETE!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
