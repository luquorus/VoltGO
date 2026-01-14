# Quick test CSV import
$baseUrl = "http://localhost:8080"
$csvFile = "data/test_stations.csv"

# Login to get token
Write-Host "Logging in as admin..." -ForegroundColor Cyan
$loginBody = @{
    email = "admin@local"
    password = "Admin@123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
$token = $loginResponse.token
Write-Host "Login successful! Token: $($token.Substring(0, 50))..." -ForegroundColor Green

# Test CSV import
Write-Host ""
Write-Host "Testing CSV Import..." -ForegroundColor Cyan
Write-Host "Using file: $csvFile" -ForegroundColor Yellow

try {
    # Use Invoke-WebRequest for multipart form data
    $filePath = Resolve-Path $csvFile
    $form = @{
        file = Get-Item $filePath
    }
    
    $headers = @{
        "Authorization" = "Bearer $token"
    }
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations/import-csv" `
        -Method Post `
        -Headers $headers `
        -Form $form
    
    Write-Host ""
    Write-Host "=== Import Results ===" -ForegroundColor Green
    Write-Host "Total Rows: $($response.totalRows)" -ForegroundColor White
    Write-Host "Success: $($response.successCount)" -ForegroundColor Green
    $failColor = if ($response.failureCount -gt 0) { "Red" } else { "Green" }
    Write-Host "Failed: $($response.failureCount)" -ForegroundColor $failColor
    
    Write-Host ""
    Write-Host "=== Details ===" -ForegroundColor Cyan
    foreach ($result in $response.results) {
        if ($result.success) {
            Write-Host "SUCCESS Row $($result.rowNumber): $($result.stationName)" -ForegroundColor Green
            Write-Host "  Station ID: $($result.stationId)" -ForegroundColor Gray
        } else {
            Write-Host "FAILED Row $($result.rowNumber): $($result.stationName)" -ForegroundColor Red
            Write-Host "  Error: $($result.errorMessage)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Test completed!" -ForegroundColor Green
    
    # Show full response
    Write-Host ""
    Write-Host "Full Response:" -ForegroundColor Yellow
    $response | ConvertTo-Json -Depth 10
    
} catch {
    Write-Host ""
    Write-Host "Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ErrorDetails) {
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }
    exit 1
}

