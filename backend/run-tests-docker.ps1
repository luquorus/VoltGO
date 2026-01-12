# PowerShell script to run BookingService tests using Docker
# Prerequisites: PostgreSQL container must be running (from docker-compose)

Write-Host "Running BookingService tests using Docker..." -ForegroundColor Green

# Check if PostgreSQL container is running
$postgresRunning = docker ps | Select-String "voltgo-postgres"
if (-not $postgresRunning) {
    Write-Host "Error: voltgo-postgres container is not running." -ForegroundColor Red
    Write-Host "Please start it first: cd infra && docker-compose up -d postgres" -ForegroundColor Yellow
    exit 1
}

# Get PostgreSQL container IP or use localhost
$env:POSTGRES_HOST = if ($env:POSTGRES_HOST) { $env:POSTGRES_HOST } else { "localhost" }
$env:POSTGRES_PORT = if ($env:POSTGRES_PORT) { $env:POSTGRES_PORT } else { "5432" }
$env:POSTGRES_DB = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { "voltgo" }
$env:POSTGRES_USER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "voltgo_user" }
$env:POSTGRES_PASSWORD = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { "admin123" }

Write-Host "Connecting to PostgreSQL at $env:POSTGRES_HOST:$env:POSTGRES_PORT" -ForegroundColor Cyan

# Get current directory
$currentDir = (Get-Location).Path

# Run tests in Docker container
docker run --rm `
    --network host `
    -v "${currentDir}:/app" `
    -w /app `
    -e POSTGRES_HOST="$env:POSTGRES_HOST" `
    -e POSTGRES_PORT="$env:POSTGRES_PORT" `
    -e POSTGRES_DB="$env:POSTGRES_DB" `
    -e POSTGRES_USER="$env:POSTGRES_USER" `
    -e POSTGRES_PASSWORD="$env:POSTGRES_PASSWORD" `
    -e SPRING_PROFILES_ACTIVE=local `
    gradle:8.5-jdk17-alpine `
    sh -c "gradle test --tests 'com.example.evstation.booking.application.BookingServiceTest' --no-daemon"

Write-Host "Tests completed!" -ForegroundColor Green

