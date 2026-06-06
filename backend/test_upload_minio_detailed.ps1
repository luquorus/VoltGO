$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== MinIO Upload Test (Presigned URL v4) ===" -ForegroundColor Cyan

# Login
$collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="collab1@testt";"password"="Admin@123"} | ConvertTo-Json)
$collabHeaders = @{"Authorization"="Bearer $($collabLogin.token)"}
$objectKey = $null

# Get a REAL presigned URL
$presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/jpeg" } | ConvertTo-Json)
$objectKey = $presign.objectKey
$uploadUrl = $presign.uploadUrl
Write-Host "ObjectKey: $objectKey" -ForegroundColor Gray
Write-Host "UploadUrl: $uploadUrl" -ForegroundColor Gray

$imagePath = "C:\Users\luquo\Downloads\1387883b-6210-4a40-8760-26fbaf567e49.jpeg"
if (-not (Test-Path $imagePath)) {
    Write-Host "[FAIL] Image not found: $imagePath" -ForegroundColor Red
    exit 1
}
Write-Host "Image: $imagePath ($([Math]::Round((Get-Item $imagePath).Length / 1KB, 1)) KB)" -ForegroundColor Gray

$temp = [System.IO.Path]::GetTempFileName() + ".jpg"
Copy-Item $imagePath $temp

# Try 1: Direct original URL (might work if backend is on localhost)
Write-Host ""
Write-Host "[TEST 1] Direct original URL (no replacement)..." -ForegroundColor Yellow
$code1 = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp $uploadUrl 2>&1)
Write-Host "    Code: $code1" -ForegroundColor $(if ($code1 -eq "200" -or $code1 -eq "204") { "Green" } else { "Gray" })

# Try 2: Replace Docker gateway IP with localhost, keep Host header
$gatewayIp = "192.168.65.254"
if ($uploadUrl -match "192\.168\.(\d+)\.(\d+)") {
    Write-Host ""
    Write-Host "[TEST 2] Replace IP with localhost + Host header..." -ForegroundColor Yellow
    $url2 = $uploadUrl -replace [regex]::Escape("192.168.65.254"), "localhost"
    Write-Host "    URL: $url2" -ForegroundColor Gray
    $code2 = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp -H "Host: 192.168.65.254:9000" $url2 2>&1)
    Write-Host "    Code: $code2" -ForegroundColor $(if ($code2 -eq "200" -or $code2 -eq "204") { "Green" } else { "Gray" })

    # Try 2b: Same as above but try with just the IP (no port)
    Write-Host ""
    Write-Host "[TEST 2b] Replace IP with localhost:9000 + Host:192.168.65.254..." -ForegroundColor Yellow
    $url2b = $url2 -replace "//localhost", "//localhost:9000"
    Write-Host "    URL: $url2b" -ForegroundColor Gray
    $code2b = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp -H "Host: 192.168.65.254:9000" $url2b 2>&1)
    Write-Host "    Code: $code2b" -ForegroundColor $(if ($code2b -eq "200" -or $code2b -eq "204") { "Green" } else { "Gray" })

    # Try 2c: Try with 172.17.0.1 (Docker bridge gateway)
    Write-Host ""
    Write-Host "[TEST 2c] Try with 172.17.0.1 (bridge gateway)..." -ForegroundColor Yellow
    $url2c = $uploadUrl -replace [regex]::Escape("192.168.65.254"), "172.17.0.1"
    Write-Host "    URL: $url2c" -ForegroundColor Gray
    $code2c = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp $url2c 2>&1)
    Write-Host "    Code: $code2c" -ForegroundColor $(if ($code2c -eq "200" -or $code2c -eq "204") { "Green" } else { "Gray" })
}

# Try 3: Verbose output to see exact error
if ($code1 -notmatch "200|204" -and $code2 -notmatch "200|204" -and $code2b -notmatch "200|204") {
    Write-Host ""
    Write-Host "[TEST 3] Verbose to see 403 details..." -ForegroundColor Yellow
    $url3 = $uploadUrl -replace [regex]::Escape("192.168.65.254"), "localhost:9000"
    curl.exe -v --upload-file $temp -H "Host: 192.168.65.254:9000" $url3 2>&1 | Select-Object -First 25
}

Remove-Item $temp -Force

if ($code1 -eq "200" -or $code1 -eq "204") {
    Write-Host ""
    Write-Host "[SUCCESS] Direct upload works! objectKey=$objectKey" -ForegroundColor Green
} elseif ($code2 -eq "200" -or $code2 -eq "204" -or $code2b -eq "200" -or $code2b -eq "204") {
    Write-Host ""
    Write-Host "[SUCCESS] Host-header trick works! objectKey=$objectKey" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[FAIL] All methods failed. objectKey=$objectKey (backend accepted it)" -ForegroundColor Red
    Write-Host "       But MinIO direct upload failed from Windows host." -ForegroundColor Red
}
