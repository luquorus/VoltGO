$baseUrl = "http://localhost:8080"
$collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$collabHeaders = @{"Authorization"="Bearer $($collabLogin.token)"}
Write-Host "Testing MinIO presigned URL..." -ForegroundColor Cyan
$presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/png" } | ConvertTo-Json)
Write-Host "UploadUrl: $($presign.uploadUrl)" -ForegroundColor Gray
if ($presign.uploadUrl -like "http://localhost:9000/*") {
    Write-Host "[OK] Presigned URL now uses localhost:9000!" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Still using host.docker.internal" -ForegroundColor Red
}
