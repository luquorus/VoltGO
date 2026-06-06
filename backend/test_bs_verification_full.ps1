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

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VOLTGO - Full Battery Swap Verification Task Test" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Admin : $adminEmail" -ForegroundColor White
Write-Host " Collab: $collabEmail" -ForegroundColor White
Write-Host " Image : $imagePath" -ForegroundColor White
Write-Host ""

# ============================
# 1. LOGIN ADMIN + COLLAB
# ============================
Write-Host "[1] Login Admin..." -ForegroundColor Yellow
try {
    $adminLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"=$adminEmail;"password"=$adminPass} | ConvertTo-Json)
    $adminToken = $adminLogin.token
    $adminUserId = $adminLogin.userId
    $adminHeaders = @{"Authorization"="Bearer $adminToken"}
    Write-Host "    [OK] Admin: $adminEmail | userId=$adminUserId" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2] Login Collaborator..." -ForegroundColor Yellow
try {
    $collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"=$collabEmail;"password"=$collabPass} | ConvertTo-Json)
    $collabToken = $collabLogin.token
    $collabUserId = $collabLogin.userId
    $collabHeaders = @{"Authorization"="Bearer $collabToken"}
    $collabName = $collabLogin.name
    Write-Host "    [OK] Collab: $collabEmail | userId=$collabUserId | name=$collabName" -ForegroundColor Green
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================
# 3. GET COLLAB LOCATION (for proximity check)
# ============================
Write-Host ""
Write-Host "[3] Get collaborator profile + location..." -ForegroundColor Yellow
try {
    $profile = Invoke-RestMethod -Uri "$baseUrl/api/collab/web/me/profile" -Method GET -Headers $collabHeaders
    $collabLat = $profile.lat
    $collabLng = $profile.lng
    Write-Host "    [OK] Collab location: lat=$collabLat, lng=$collabLng" -ForegroundColor Green

    # Fallback location if not set
    if (-not $collabLat -or -not $collabLng) {
        $collabLat = 21.028511
        $collabLng = 105.854456
        Write-Host "    [WARN] No location set, using default: lat=$collabLat, lng=$collabLng" -ForegroundColor Yellow
    }
} catch {
    $collabLat = 21.028511
    $collabLng = 105.854456
    Write-Host "    [WARN] Could not get location, using default: lat=$collabLat, lng=$collabLng" -ForegroundColor Yellow
}

# ============================
# 4. LIST BATTERY SWAP STATIONS
# ============================
Write-Host ""
Write-Host "[4] List all Battery Swap stations..." -ForegroundColor Yellow
try {
    $stations = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/stations?page=0&size=50" -Method GET -Headers $adminHeaders
    $allStations = $stations.content
    Write-Host "    [OK] Total BS stations: $($stations.totalElements)" -ForegroundColor Green

    # Filter out Hoang Mai
    $filtered = $allStations | Where-Object {
        $name = $_.name -replace " ", ""
        $name -notlike "*HoangMai*" -and $name -notlike "*hoangmai*"
    }

    $selected = @()
    if ($filtered.Count -ge 3) {
        $selected = @($filtered[0], $filtered[1], $filtered[2])
    } elseif ($filtered.Count -gt 0) {
        $selected = $filtered
        Write-Host "    [WARN] Only $($filtered.Count) non-HoangMai stations found, will use what is available" -ForegroundColor Yellow
    } else {
        # If no other stations, just pick any 3
        $selected = @($allStations[0], $allStations[1], $allStations[2])
        Write-Host "    [WARN] No non-HoangMai stations found, using first 3 available" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "    Selected stations for testing:" -ForegroundColor Cyan
    foreach ($s in $selected) {
        Write-Host "      - $($s.name) [$($s.id)]" -ForegroundColor White
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
# 5. ENSURE ACTIVE CONTRACT
# ============================
Write-Host ""
Write-Host "[5] Ensure active contract for collab..." -ForegroundColor Yellow
try {
    $collaborators = Invoke-RestMethod -Uri "$baseUrl/api/admin/collaborators?page=0&size=100" -Method GET -Headers $adminHeaders
    $collab = $collaborators.content | Where-Object { $_.email -eq $collabEmail } | Select-Object -First 1

    if (-not $collab) {
        Write-Host "    [WARN] No collaborator profile found for $collabEmail - trying to create..." -ForegroundColor Yellow
        # Try to find the user account by userId
        $collabId = $null
    } else {
        $collabId = $collab.id
        Write-Host "    [OK] Collab profile: id=$collabId | email=$($collab.email)" -ForegroundColor Green
    }

    # Check contracts
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $adminHeaders
    $activeContract = $contracts | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -First 1

    if (-not $activeContract) {
        Write-Host "    [+] Creating active contract..." -ForegroundColor Yellow
        $cb = @{
            collaboratorId = $collabId
            region = "Hanoi"
            startDate = "2026-06-06"
            endDate = "2027-06-06"
        } | ConvertTo-Json
        $activeContract = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $cb
        Write-Host "    [OK] Contract created: $($activeContract.id)" -ForegroundColor Green
    } else {
        Write-Host "    [OK] Has active contract: $($activeContract.id)" -ForegroundColor Green
    }
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
}

# ============================
# 6. UPLOAD EVIDENCE IMAGE
# ============================
Write-Host ""
Write-Host "[6] Upload evidence image..." -ForegroundColor Yellow

if (-not (Test-Path $imagePath)) {
    Write-Host "    [FAIL] Image not found: $imagePath" -ForegroundColor Red
    exit 1
}

$objectKey = $null
$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
$imageSizeKB = [Math]::Round($imageBytes.Length / 1024, 1)
Write-Host "    Image: $imagePath ($imageSizeKB KB)" -ForegroundColor Gray

try {
    # Get presigned URL
    $presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/jpeg" } | ConvertTo-Json)
    $objectKey = $presign.objectKey
    $uploadUrl = $presign.uploadUrl
    Write-Host "    [OK] Got presigned URL: $($presign.objectKey)" -ForegroundColor Green

    # Try upload via WebClient approach
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers["Content-Type"] = "image/jpeg"
        $wc.UploadData($uploadUrl, "PUT", $imageBytes)
        $wc.Dispose()
        Write-Host "    [OK] Uploaded directly!" -ForegroundColor Green
        $uploadOk = $true
    } catch {
        # Fallback: try with localhost
        $altUrl = $uploadUrl -replace "192\.168\.\d+\.\d+", "localhost" -replace "localhost\.minio\.svc\.cluster\.local", "localhost" -replace "minio", "localhost:9000"
        $altUrl = $uploadUrl -replace "192\.168\.65\.254", "localhost"
        Write-Host "    [TRY] Trying with localhost:9000..." -ForegroundColor Yellow
        try {
            $wc2 = New-Object System.Net.WebClient
            $wc2.Headers["Content-Type"] = "image/jpeg"
            $wc2.UploadData($altUrl, "PUT", $imageBytes)
            $wc2.Dispose()
            Write-Host "    [OK] Uploaded via localhost!" -ForegroundColor Green
            $uploadOk = $true
        } catch {
            # Last try with curl
            Write-Host "    [TRY] Trying with curl..." -ForegroundColor Yellow
            $tempFile = [System.IO.Path]::GetTempFileName() + ".jpg"
            [System.IO.File]::WriteAllBytes($tempFile, $imageBytes)

            $originalHost = [regex]::Match($uploadUrl, 'http[s]?://([^/]+)').Groups[1].Value
            $curlUrl = $altUrl

            $curlCode = (curl.exe -s -o $null -w "%{http_code}" --upload-file $tempFile -H "Host: $originalHost" $curlUrl 2>&1)
            Remove-Item $tempFile -Force

            if ($curlCode -eq "200" -or $curlCode -eq "204") {
                Write-Host "    [OK] Uploaded via curl!" -ForegroundColor Green
                $uploadOk = $true
            } else {
                Write-Host "    [FAIL] All upload methods failed. curl code: $curlCode" -ForegroundColor Red
                $uploadOk = $false
            }
        }
    }
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    try {
        $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
        Write-Host "    Response: $body" -ForegroundColor Red
    } catch {}
}

if (-not $objectKey) {
    Write-Host "    [WARN] Upload failed, will try to proceed without evidence image" -ForegroundColor Yellow
}

# ============================
# 7. TEST 3 STATIONS - FULL FLOW
# ============================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " TESTING 3 BATTERY SWAP STATIONS - FULL VERIFICATION FLOW" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$results = @()

for ($i = 0; $i -lt $selected.Count; $i++) {
    $station = $selected[$i]
    $stationId = $station.id
    $stationName = $station.name
    $taskId = $null

    Write-Host ""
    Write-Host "--------------------------------------------------------" -ForegroundColor Magenta
    Write-Host " STATION [$($i+1)/$($selected.Count)]: $stationName [$stationId]" -ForegroundColor Magenta
    Write-Host "--------------------------------------------------------" -ForegroundColor Magenta

    # 7a. Create verification task
    Write-Host ""
    Write-Host "[$($i+1)a] Create BS Verification Task..." -ForegroundColor Yellow
    try {
        $createTaskBody = @{
            stationId = $stationId
            priority = 3
        } | ConvertTo-Json

        $newTask = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $createTaskBody
        $taskId = $newTask.id
        $taskStatus = $newTask.status
        Write-Host "    [OK] Task created: $taskId | status=$taskStatus" -ForegroundColor Green
        Write-Host "    Station: $($newTask.stationName)" -ForegroundColor Gray
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        try {
            $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
            Write-Host "    Response: $body" -ForegroundColor Red
        } catch {}
        continue
    }

    # 7b. Assign to collaborator
    Write-Host ""
    Write-Host "[$($i+1)b] Assign task to $collabEmail..." -ForegroundColor Yellow
    try {
        $assignBody = @{
            collaboratorUserId = $collabUserId
        } | ConvertTo-Json

        $assignResp = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$taskId/assign" -Method PUT -Headers $adminHeaders -ContentType "application/json" -Body $assignBody
        Write-Host "    [OK] Task assigned: $taskId" -ForegroundColor Green
        Write-Host "    Assigned to: $($assignResp.assignedToEmail)" -ForegroundColor Gray
        Write-Host "    Status: $($assignResp.status)" -ForegroundColor Gray
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        try {
            $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
            Write-Host "    Response: $body" -ForegroundColor Red
        } catch {}
        continue
    }

    # 7c. Get task (mobile endpoint)
    Write-Host ""
    Write-Host "[$($i+1)c] Get task via mobile API (as collab)..." -ForegroundColor Yellow
    try {
        $tasks = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks" -Method GET -Headers $collabHeaders
        $myTask = $tasks | Where-Object { $_.id -eq $taskId } | Select-Object -First 1
        if ($myTask) {
            Write-Host "    [OK] Found task: id=$($myTask.id) | status=$($myTask.status)" -ForegroundColor Green
            Write-Host "    Station: $($myTask.stationName)" -ForegroundColor Gray
        } else {
            Write-Host "    [WARN] Task not found in mobile list (may not be visible yet or status mismatch)" -ForegroundColor Yellow
            Write-Host "    Available tasks count: $($tasks.Count)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }

    # 7d. Check-in
    Write-Host ""
    Write-Host "[$($i+1)d] Check-in at station..." -ForegroundColor Yellow
    try {
        # Use station's lat/lng if available, otherwise collab's location
        $checkinLat = if ($station.lat) { $station.lat } else { $collabLat }
        $checkinLng = if ($station.lng) { $station.lng } else { $collabLng }

        $checkinBody = @{
            lat = $checkinLat
            lng = $checkinLng
            deviceNote = "Auto-test check-in for $stationName"
            actualTotalBatteries = 24
            actualAvailableBatteries = 18
            observedAvgChargePowerKw = 40.0
        } | ConvertTo-Json

        $checkin = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$taskId/checkin" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body $checkinBody
        Write-Host "    [OK] Checked-in! Status: $($checkin.status)" -ForegroundColor Green
        if ($checkin.checkin) {
            Write-Host "    Distance: $($checkin.checkin.distanceM)m" -ForegroundColor Gray
            Write-Host "    Batteries: total=$($checkin.checkin.actualTotalBatteries), available=$($checkin.checkin.actualAvailableBatteries)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        try {
            $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
            Write-Host "    Response: $body" -ForegroundColor Red
        } catch {}
        continue
    }

    # 7e. Submit evidence
    Write-Host ""
    Write-Host "[$($i+1)e] Submit evidence photo..." -ForegroundColor Yellow
    if ($objectKey) {
        try {
            $evidenceBody = @{
                photoObjectKey = $objectKey
                note = "Verification evidence photo for $stationName - auto-test"
            } | ConvertTo-Json

            $evidence = Invoke-RestMethod -Uri "$baseUrl/api/mobile/collab/battery-swap/verification/tasks/$taskId/evidence" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body $evidenceBody
            Write-Host "    [OK] Evidence submitted! Status: $($evidence.status)" -ForegroundColor Green
            if ($evidence.evidences) {
                Write-Host "    Evidence count: $($evidence.evidences.Count)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
            try {
                $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
                Write-Host "    Response: $body" -ForegroundColor Red
            } catch {}
        }
    } else {
        Write-Host "    [SKIP] No uploaded image, skipping evidence submission" -ForegroundColor Yellow
    }

    # 7f. Admin reviews
    Write-Host ""
    Write-Host "[$($i+1)f] Admin reviews task..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    try {
        $taskDetail = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$taskId" -Method GET -Headers $adminHeaders
        Write-Host "    Current status: $($taskDetail.status)" -ForegroundColor Gray

        if ($taskDetail.status -eq "SUBMITTED") {
            $reviewResult = if ($i % 2 -eq 0) { "PASS" } else { "PASS" }  # All PASS for clean test
            $reviewBody = @{
                result = $reviewResult
                adminNote = "Admin review - $stationName - auto-test PASS"
                riskConfirmed = "false"
            } | ConvertTo-Json

            $review = Invoke-RestMethod -Uri "$baseUrl/api/admin/battery-swap/verification/tasks/$taskId/review" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $reviewBody
            Write-Host "    [OK] Reviewed as $reviewResult! Final status: $($review.status)" -ForegroundColor Green
            if ($review.review) {
                Write-Host "    Reviewed by: $($review.review.reviewedBy) at $($review.review.reviewedAt)" -ForegroundColor Gray
            }
        } else {
            Write-Host "    [SKIP] Task not in SUBMITTED state (current: $($taskDetail.status))" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        try {
            $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream()); $body = $stream.ReadToEnd(); $stream.Dispose()
            Write-Host "    Response: $body" -ForegroundColor Red
        } catch {}
    }

    # Record result
    $results += @{
        Station = $stationName
        StationId = $stationId
        TaskId = $taskId
        Status = $taskDetail.status
    }
}

# ============================
# 8. SUMMARY
# ============================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Collaborator : $collabEmail ($collabUserId)" -ForegroundColor White
Write-Host "  Admin        : $adminEmail" -ForegroundColor White
Write-Host "  Evidence     : $objectKey" -ForegroundColor White
Write-Host ""
Write-Host "  Station Test Results:" -ForegroundColor Yellow
Write-Host "  " + ("-" * 70) -ForegroundColor DarkGray
foreach ($r in $results) {
    $statusIcon = if ($r.Status -eq "REVIEWED") { "[PASS]" } elseif ($r.Status -eq "SUBMITTED") { "[SUB]" } else { "[---]" }
    $color = if ($r.Status -eq "REVIEWED") { "Green" } elseif ($r.Status -eq "SUBMITTED") { "Yellow" } else { "Red" }
    Write-Host "  $statusIcon $($r.Station)" -ForegroundColor $color
    Write-Host "         Task: $($r.TaskId)" -ForegroundColor Gray
    Write-Host "         Status: $($r.Status)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  FULL FLOW COMPLETE!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
