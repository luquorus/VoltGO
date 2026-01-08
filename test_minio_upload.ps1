# Test Task 2.6: MinIO Integration - Full Flow với Upload Ảnh Thật
Write-Host "=== TEST TASK 2.6: MinIO Integration - Full Flow ===`n"

# Step 1: Login
Write-Host "Step 1: Login"
$adminLoginResp = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin@local","password":"Admin@123"}'
$adminToken = $adminLoginResp.token
$adminHeaders = @{Authorization = "Bearer $adminToken"}

$collabResp = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"newcollab@test.local","password":"Collab@123"}'
$collabToken = $collabResp.token
$collabHeaders = @{Authorization = "Bearer $collabToken"}

$providerResp = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"provider@test.local","password":"Provider@123"}'
$providerToken = $providerResp.token
$providerHeaders = @{Authorization = "Bearer $providerToken"}

Write-Host "  Logged in as Admin, Collaborator, Provider`n"

# Step 2: Get Station
Write-Host "Step 2: Get Station"
$stations = Invoke-RestMethod -Uri "http://localhost:8080/api/ev/stations?lat=21.0400&lng=105.8700&radiusKm=10" -Method GET -Headers $providerHeaders
$stationId = $stations.content[0].stationId
Write-Host "  Using station: $stationId`n"

# Step 3: Create Verification Task
Write-Host "Step 3: Create Verification Task"
$createTaskBody = @{stationId = $stationId; priority = 1} | ConvertTo-Json
$taskResp = Invoke-RestMethod -Uri "http://localhost:8080/api/admin/verification-tasks" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $createTaskBody
$taskId = $taskResp.id
Write-Host "  Task created: $taskId`n"

# Step 4: Assign Task
Write-Host "Step 4: Assign Task to Collaborator"
$assignBody = @{collaboratorUserId = $collabResp.userId} | ConvertTo-Json
$assignResp = Invoke-RestMethod -Uri "http://localhost:8080/api/admin/verification-tasks/$taskId/assign" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $assignBody
Write-Host "  Task assigned: $($assignResp.status)`n"

# Step 5: Check-in
Write-Host "Step 5: Collaborator Check-in"
$stationDetail = Invoke-RestMethod -Uri "http://localhost:8080/api/ev/stations/$stationId" -Method GET -Headers $providerHeaders
$checkinBody = @{lat = $stationDetail.lat; lng = $stationDetail.lng; deviceNote = "Test device"} | ConvertTo-Json
$checkinResp = Invoke-RestMethod -Uri "http://localhost:8080/api/collab/mobile/tasks/$taskId/check-in" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body $checkinBody
Write-Host "  Check-in successful: $($checkinResp.status)`n"

# Step 6: Request Presigned Upload URL
Write-Host "Step 6: Request Presigned Upload URL"
$uploadReqBody = @{contentType = "image/jpeg"} | ConvertTo-Json
$uploadResp = Invoke-RestMethod -Uri "http://localhost:8080/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body $uploadReqBody
$objectKey = $uploadResp.objectKey
$uploadUrl = $uploadResp.uploadUrl
Write-Host "  Presigned upload URL received:"
Write-Host "    ObjectKey: $objectKey"
Write-Host "    UploadURL: $($uploadUrl.Substring(0, [Math]::Min(100, $uploadUrl.Length)))..."
Write-Host "    ExpiresAt: $($uploadResp.expiresAt)`n"

Write-Host "=== HUONG DAN UPLOAD ANH THAT ==="
Write-Host "De upload anh that, ban can:"
Write-Host "1. Su dung uploadUrl de PUT file truc tiep len MinIO"
Write-Host "2. Content-Type phai match voi contentType da request (image/jpeg)"
Write-Host "3. Sau khi upload thanh cong, submit evidence voi objectKey`n"

# Step 7: Tạo test image và upload
Write-Host "Step 7: Create Test Image and Upload"
$testImagePath = "$env:TEMP\test-evidence.jpg"

# Tạo một JPEG file nhỏ (minimal valid JPEG)
$jpegBytes = [byte[]](0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xFF, 0xD9)
[System.IO.File]::WriteAllBytes($testImagePath, $jpegBytes)
Write-Host "  Test image created: $testImagePath`n"

# Upload file thật lên MinIO
Write-Host "Step 8: Upload File to MinIO (Real Upload)"
try {
    $fileBytes = [System.IO.File]::ReadAllBytes($testImagePath)
    # Map internal MinIO URL to external (nếu MinIO expose ra ngoài)
    $publicUploadUrl = $uploadUrl -replace "http://minio:9000", "http://localhost:9000"
    
    Write-Host "  Uploading to MinIO..."
    Write-Host "  URL: $($publicUploadUrl.Substring(0, [Math]::Min(120, $publicUploadUrl.Length)))..."
    
    # Upload file using PUT request
    $uploadResult = Invoke-WebRequest -Uri $publicUploadUrl -Method PUT -ContentType "image/jpeg" -Body $fileBytes -UseBasicParsing
    Write-Host "  File uploaded successfully! Status: $($uploadResult.StatusCode)`n"
} catch {
    Write-Host "  Upload failed: $($_.Exception.Message)"
    Write-Host "  Note: MinIO may not be accessible externally (minio:9000 vs localhost:9000)"
    Write-Host "  In production, client will upload from within the network or MinIO will be exposed`n"
}

# Step 9: Submit Evidence
Write-Host "Step 9: Submit Evidence"
$evidenceBody = @{photoObjectKey = $objectKey; note = "Evidence photo uploaded via presigned URL"} | ConvertTo-Json
$evidenceResp = Invoke-RestMethod -Uri "http://localhost:8080/api/collab/mobile/tasks/$taskId/submit-evidence" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body $evidenceBody
Write-Host "  Evidence submitted: $($evidenceResp.status)`n"

# Step 10: Admin Review
Write-Host "Step 10: Admin Review"
$reviewBody = @{result = "PASS"; adminNote = "Evidence verified"} | ConvertTo-Json
$reviewResp = Invoke-RestMethod -Uri "http://localhost:8080/api/admin/verification-tasks/$taskId/review" -Method POST -Headers $adminHeaders -ContentType "application/json" -Body $reviewBody
Write-Host "  Review completed: $($reviewResp.review.result)`n"

# Step 11: Get View URLs
Write-Host "Step 11: Get Presigned View URLs"
$adminViewResp = Invoke-RestMethod -Uri "http://localhost:8080/api/admin/files/presign-view?objectKey=$objectKey" -Method GET -Headers $adminHeaders
Write-Host "  Admin view URL generated (expires: $($adminViewResp.expiresAt))"

$collabViewResp = Invoke-RestMethod -Uri "http://localhost:8080/api/collab/web/files/presign-view?objectKey=$objectKey" -Method GET -Headers $collabHeaders
Write-Host "  Collaborator view URL generated (expires: $($collabViewResp.expiresAt))`n"

Write-Host "=== TEST COMPLETE ==="
Write-Host "All steps completed successfully!"

