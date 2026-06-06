$baseUrl = "http://localhost:8080"
$collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$collabHeaders = @{"Authorization"="Bearer $($collabLogin.token)"}

Write-Host "=== Test MinIO Upload ===" -ForegroundColor Cyan

# Get presigned URL
$presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/png" } | ConvertTo-Json)
$objectKey = $presign.objectKey
$uploadUrl = $presign.uploadUrl
Write-Host "ObjectKey: $objectKey" -ForegroundColor Gray
Write-Host "UploadUrl: $uploadUrl" -ForegroundColor Gray

# Read image
$imagePath = "C:\Users\luquo\Downloads\1000011207.png"
if (-not (Test-Path $imagePath)) {
    Get-ChildItem "C:\Users\luquo\Downloads\*.png" -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { $imagePath = $_.FullName }
}
Write-Host "Image: $imagePath" -ForegroundColor Gray

if (Test-Path $imagePath) {
    try {
        $imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
        $wc = New-Object System.Net.WebClient
        $wc.Headers["Content-Type"] = "image/png"
        Write-Host "Uploading..." -ForegroundColor Yellow
        $wc.UploadData($uploadUrl, "PUT", $imageBytes)
        $wc.Dispose()
        Write-Host "[OK] Uploaded successfully!" -ForegroundColor Green
        Write-Host "ObjectKey: $objectKey" -ForegroundColor White
    } catch {
        Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
        # Try with localhost
        Write-Host "Trying localhost:9000..." -ForegroundColor Yellow
        try {
            $altUrl = $uploadUrl -replace "192\.168\.65\.254", "localhost"
            $wc2 = New-Object System.Net.WebClient
            $wc2.Headers["Content-Type"] = "image/png"
            $wc2.UploadData($altUrl, "PUT", $imageBytes)
            $wc2.Dispose()
            Write-Host "[OK] Uploaded via localhost!" -ForegroundColor Green
            Write-Host "ObjectKey: $objectKey" -ForegroundColor White
        } catch {
            Write-Host "[FAIL] localhost: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "[SKIP] Image not found" -ForegroundColor Yellow
}
