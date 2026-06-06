$baseUrl = "http://localhost:8080"
$collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="Admin@123"} | ConvertTo-Json)
$collabHeaders = @{"Authorization"="Bearer $($collabLogin.token)"}

Write-Host "=== Test MinIO Upload with Host header ===" -ForegroundColor Cyan

# Get presigned URL
$presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/png" } | ConvertTo-Json)
$objectKey = $presign.objectKey
$uploadUrl = $presign.uploadUrl
Write-Host "ObjectKey: $objectKey" -ForegroundColor Gray
Write-Host "Original: $uploadUrl" -ForegroundColor Gray

# Extract host from original URL for signature
$originalHost = [regex]::Match($uploadUrl, 'http[s]?://([^/]+)').Groups[1].Value
Write-Host "Signature host: $originalHost" -ForegroundColor Gray

# Replace host.docker.internal with localhost in the URL
$uploadUrlFixed = $uploadUrl -replace [regex]::Escape("http://$originalHost"), "http://localhost:9000"
Write-Host "Fixed:     $uploadUrlFixed" -ForegroundColor Gray

# Find image
$imagePath = "C:\Users\luquo\Downloads\1000011207.png"
if (-not (Test-Path $imagePath)) {
    Get-ChildItem "C:\Users\luquo\Downloads\*.png" -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { $imagePath = $_.FullName }
}
Write-Host "Image: $imagePath" -ForegroundColor Gray

if (Test-Path $imagePath) {
    $temp = [System.IO.Path]::GetTempFileName() + ".png"
    Copy-Item $imagePath $temp

    Write-Host "Uploading (with Host header)..." -ForegroundColor Yellow
    # Use curl with explicit Host header so signature validates
    $curlOutput = curl.exe -s -o /dev/null -w "%{http_code}" `
        --upload-file $temp `
        -H "Host: $originalHost" `
        $uploadUrlFixed 2>&1
    Remove-Item $temp

    Write-Host "curl response: $curlOutput" -ForegroundColor Gray
    if ($curlOutput -eq "200" -or $curlOutput -eq "204") {
        Write-Host "[OK] Uploaded! ObjectKey: $objectKey" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] curl returned: $curlOutput" -ForegroundColor Red
    }
}
