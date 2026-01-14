# Test CSV Import for Stations
# This script tests importing a few stations from the CSV file

$baseUrl = "http://localhost:8080"
$csvFile = "data/stations_template.csv"

# Get admin token (you need to login first)
Write-Host "Please login as admin first to get token"
Write-Host "Example: POST $baseUrl/auth/login"
Write-Host "Body: { `"email`": `"admin@example.com`", `"password`": `"password`" }"
$token = Read-Host "Enter JWT token"

if ([string]::IsNullOrEmpty($token)) {
    Write-Host "Token is required. Exiting."
    exit 1
}

# Create a test CSV with only first 3 stations (excluding header)
$testCsv = @"
name,address,latitude,longitude,ports_250kw,ports_180kw,ports_150kw,ports_120kw,ports_80kw,ports_60kw,ports_40kw,ports_ac,operatingHours,parking,stationType,status
Nhuong quyen - Ho kinh doanh Ha Thi Xuan Thanh,"Phu Xuyen District, Hanoi",20.785429,105.919281,0,0,0,4,0,2,0,0,24/7,Paid,Public,active
Vincom Plaza Long Bien,"Hoa Phuong Street, Vinhomes Riverside, Long Bien District, Hanoi City",21.05052,105.91581,4,0,0,8,0,0,0,1,24/7,Paid,Public,active
Vincom Mega Mall Ocean Park,"Ocean Park Shopping Mall Parking Lot, Vinhomes Ocean Park, Kieu Ky Commune, Gia Lam District, Hanoi City",20.994547,105.959602,5,0,0,0,0,4,0,0,24/7,Paid,Public,active
"@

$testCsvFile = "data/test_stations.csv"
$testCsv | Out-File -FilePath $testCsvFile -Encoding UTF8

Write-Host "`nTesting CSV Import..."
Write-Host "Using test file: $testCsvFile"
Write-Host "This will import 3 stations"

try {
    # Create multipart form data
    $boundary = [System.Guid]::NewGuid().ToString()
    $fileBytes = [System.IO.File]::ReadAllBytes($testCsvFile)
    $fileName = [System.IO.Path]::GetFileName($testCsvFile)
    
    $bodyLines = @()
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`""
    $bodyLines += "Content-Type: text/csv"
    $bodyLines += ""
    $bodyLines += [System.Text.Encoding]::UTF8.GetString($fileBytes)
    $bodyLines += "--$boundary--"
    
    $body = $bodyLines -join "`r`n"
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations/import-csv" `
        -Method Post `
        -Headers $headers `
        -Body $bodyBytes
    
    Write-Host "`nImport Results:" -ForegroundColor Green
    Write-Host "Total Rows: $($response.totalRows)"
    Write-Host "Success: $($response.successCount)" -ForegroundColor Green
    Write-Host "Failed: $($response.failureCount)" -ForegroundColor $(if ($response.failureCount -gt 0) { "Red" } else { "Green" })
    
    Write-Host "`nDetails:" -ForegroundColor Cyan
    foreach ($result in $response.results) {
        if ($result.success) {
            Write-Host "✓ Row $($result.rowNumber): $($result.stationName) - Station ID: $($result.stationId)" -ForegroundColor Green
        } else {
            Write-Host "✗ Row $($result.rowNumber): $($result.stationName) - Error: $($result.errorMessage)" -ForegroundColor Red
        }
    }
    
    # Clean up test file
    Remove-Item $testCsvFile -ErrorAction SilentlyContinue
    
    Write-Host "`nTest completed!" -ForegroundColor Green
    
} catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

