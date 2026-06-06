$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== Debug MinIO Upload ===" -ForegroundColor Cyan

# Login collab
$collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$collabHeaders = @{"Authorization"="Bearer $($collabLogin.token)"}
Write-Host "[OK] Logged in" -ForegroundColor Green

# Get presigned URL
$presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/png" } | ConvertTo-Json)
Write-Host "ObjectKey: $($presign.objectKey)" -ForegroundColor Gray
Write-Host "UploadUrl: $($presign.uploadUrl)" -ForegroundColor Gray

# Try upload to localhost:9000 (Windows host)
$uploadUrl = $presign.uploadUrl -replace "host.docker.internal", "localhost"
Write-Host "Trying localhost: $uploadUrl" -ForegroundColor Yellow

$imagePath = "C:\Users\luquo\Downloads\1000011207.png"
if (Test-Path $imagePath) {
    try {
        $imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
        $wc = New-Object System.Net.WebClient
        $wc.Headers["Content-Type"] = "image/png"
        $wc.UploadData($uploadUrl, "PUT", $imageBytes)
        $wc.Dispose()
        Write-Host "[OK] Uploaded via localhost!" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[SKIP] Image not found" -ForegroundColor Yellow
}

# Also check what the upload URL looks like
Write-Host ""
Write-Host "Original URL host:" -ForegroundColor Cyan
$originalHost = [regex]::Match($presign.uploadUrl, 'http[s]?://([^/]+)').Groups[1].Value
Write-Host "  $originalHost" -ForegroundColor White
