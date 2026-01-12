# PowerShell script to run comprehensive booking API tests using Docker
# This script ensures backend is running and runs API tests

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "BOOKING API TEST RUNNER (Docker)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if backend container is running
Write-Host "Step 1: Checking if backend is running..." -ForegroundColor Yellow
$backendRunning = docker ps --filter "name=voltgo-backend" --format "{{.Names}}" | Select-String "voltgo-backend"

if (-not $backendRunning) {
    Write-Host "Backend container is not running. Starting infrastructure..." -ForegroundColor Yellow
    
    # Check if we're in the right directory
    $currentDir = (Get-Location).Path
    $infraDir = Join-Path $currentDir "infra"
    if (Test-Path $infraDir) {
        Push-Location $infraDir
    } else {
        # Try from backend directory
        $infraDir = Join-Path (Split-Path $currentDir) "infra"
        if (Test-Path $infraDir) {
            Push-Location $infraDir
        } else {
            Write-Host "Error: Cannot find infra directory. Please run from project root or backend directory." -ForegroundColor Red
            exit 1
        }
    }
    
    # Start backend
    Write-Host "Starting backend container..." -ForegroundColor Yellow
    docker-compose up -d backend
    
    # Wait for backend to be healthy
    Write-Host "Waiting for backend to be ready..." -ForegroundColor Yellow
    $maxRetries = 30
    $retryCount = 0
    $backendReady = $false
    
    while ($retryCount -lt $maxRetries -and -not $backendReady) {
        Start-Sleep -Seconds 2
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080/healthz" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $backendReady = $true
                Write-Host "Backend is ready!" -ForegroundColor Green
            }
        } catch {
            $retryCount++
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
    }
    
    Pop-Location
    
    if (-not $backendReady) {
        Write-Host "`nError: Backend did not become ready within timeout period." -ForegroundColor Red
        Write-Host "Please check backend logs: docker logs voltgo-backend" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "Backend container is running." -ForegroundColor Green
    
    # Quick health check
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/healthz" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        Write-Host "Backend health check: OK" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Backend container is running but health check failed." -ForegroundColor Yellow
        Write-Host "The tests may still work, continuing..." -ForegroundColor Yellow
    }
}

Write-Host ""

# Step 2: Run the comprehensive test script
Write-Host "Step 2: Running comprehensive booking API tests..." -ForegroundColor Yellow
Write-Host ""

$currentDir = (Get-Location).Path
$testScript = Join-Path $currentDir "scripts\tests\test_booking_comprehensive.ps1"

# If we're in backend directory, adjust path
if (-not (Test-Path $testScript)) {
    $testScript = Join-Path (Split-Path $currentDir) "scripts\tests\test_booking_comprehensive.ps1"
}

if (-not (Test-Path $testScript)) {
    Write-Host "Error: Cannot find test script at: $testScript" -ForegroundColor Red
    Write-Host "Please run from project root or backend directory." -ForegroundColor Yellow
    exit 1
}

# Run the test script
& $testScript

$testExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TEST RUN COMPLETED" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($testExitCode -eq 0) {
    Write-Host "All tests passed successfully!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed. Check output above for details." -ForegroundColor Red
}

exit $testExitCode

