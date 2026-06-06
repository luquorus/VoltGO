$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "=== MinIO Upload Diagnostic ===" -ForegroundColor Cyan

# Login
$collabLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="collab1@testt";"password"="Admin@123"} | ConvertTo-Json)
$collabHeaders = @{"Authorization"="Bearer $($collabLogin.token)"}
Write-Host "Logged in as $($collabLogin.email)" -ForegroundColor Green

# Get presigned URL
$presign = Invoke-RestMethod -Uri "$baseUrl/api/collab/mobile/files/presign-upload" -Method POST -Headers $collabHeaders -ContentType "application/json" -Body (@{ contentType = "image/jpeg" } | ConvertTo-Json)
$objectKey = $presign.objectKey
$uploadUrl = $presign.uploadUrl
Write-Host ""
Write-Host "UploadUrl: $uploadUrl" -ForegroundColor Gray
Write-Host "ObjectKey: $objectKey" -ForegroundColor Gray

# Check if URL contains Docker gateway IP
if ($uploadUrl -match "192\.168\.(\d+)\.(\d+)") {
    $gatewayIp = $matches[0]
    Write-Host "Docker gateway IP found: $gatewayIp" -ForegroundColor Yellow
    $port = if ($uploadUrl -match ":(\d+)") { $matches[1] } else { "9000" }
    Write-Host "Port: $port" -ForegroundColor Gray

    # Test 1: Replace IP with localhost and try with Host header
    Write-Host ""
    Write-Host "[TEST 1] Replace IP with localhost, keep Host header..." -ForegroundColor Cyan
    $uploadUrlFixed = $uploadUrl -replace [regex]::Escape("$gatewayIp"), "localhost"
    Write-Host "Fixed URL: $uploadUrlFixed" -ForegroundColor Gray

    $imagePath = "C:\Users\luquo\Downloads\1387883b-6210-4a40-8760-26fbaf567e49.jpeg"
    if (Test-Path $imagePath) {
        $temp = [System.IO.Path]::GetTempFileName() + ".jpg"
        Copy-Item $imagePath $temp

        $code = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp -H "Host: $gatewayIp" $uploadUrlFixed 2>&1)
        Remove-Item $temp
        Write-Host "curl code: $code" -ForegroundColor $(if ($code -eq "200" -or $code -eq "204") { "Green" } else { "Red" })

        if ($code -eq "200" -or $code -eq "204") {
            Write-Host "[SUCCESS] Test 1 passed!" -ForegroundColor Green
        } else {
            # Test 2: Try without Host header
            Write-Host ""
            Write-Host "[TEST 2] Try without Host header..." -ForegroundColor Cyan
            $temp2 = [System.IO.Path]::GetTempFileName() + ".jpg"
            Copy-Item $imagePath $temp2
            $code2 = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp2 $uploadUrlFixed 2>&1)
            Remove-Item $temp2
            Write-Host "curl code: $code2" -ForegroundColor $(if ($code2 -eq "200" -or $code2 -eq "204") { "Green" } else { "Red" })

            if ($code2 -eq "200" -or $code2 -eq "204") {
                Write-Host "[SUCCESS] Test 2 passed!" -ForegroundColor Green
            } else {
                # Test 3: Try direct localhost URL (no replacement)
                Write-Host ""
                Write-Host "[TEST 3] Try direct localhost:9000 URL (no signature fix)..." -ForegroundColor Cyan
                $directUrl = $uploadUrlFixed -replace "//localhost", "//localhost:9000"
                $temp3 = [System.IO.Path]::GetTempFileName() + ".jpg"
                Copy-Item $imagePath $temp3
                $code3 = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp3 -H "Host: $gatewayIp" $directUrl 2>&1)
                Remove-Item $temp3
                Write-Host "curl code: $code3" -ForegroundColor $(if ($code3 -eq "200" -or $code3 -eq "204") { "Green" } else { "Red" })

                # Test 4: Try with -v to see actual error
                if ($code3 -notmatch "200|204") {
                    Write-Host ""
                    Write-Host "[TEST 4] Verbose upload to see error..." -ForegroundColor Cyan
                    $temp4 = [System.IO.Path]::GetTempFileName() + ".jpg"
                    Copy-Item $imagePath $temp4
                    curl.exe -v --upload-file $temp4 -H "Host: $gatewayIp" $directUrl 2>&1 | Select-Object -First 20
                    Remove-Item $temp4
                }
            }
        }
    }
} else {
    # No gateway IP, try direct
    Write-Host "No Docker gateway IP found, trying direct..." -ForegroundColor Yellow
    $imagePath = "C:\Users\luquo\Downloads\1387883b-6210-4a40-8760-26fbaf567e49.jpeg"
    if (Test-Path $imagePath) {
        $temp = [System.IO.Path]::GetTempFileName() + ".jpg"
        Copy-Item $imagePath $temp
        $code = (curl.exe -s -o /dev/null -w "%{http_code}" --upload-file $temp $uploadUrl 2>&1)
        Remove-Item $temp
        Write-Host "curl code: $code" -ForegroundColor $(if ($code -eq "200" -or $code -eq "204") { "Green" } else { "Red" })
    }
}
