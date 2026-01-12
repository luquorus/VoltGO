# PowerShell script to insert test data for Admin Verification Tasks UI testing

Write-Host "Inserting test data for Admin Verification Tasks..." -ForegroundColor Cyan

# Read database connection from .env or use defaults
$POSTGRES_DB = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { "voltgo" }
$POSTGRES_USER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "voltgo_user" }
$POSTGRES_PASSWORD = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { "admin123" }

# Path to SQL file (relative to script location)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SQL_FILE = Join-Path $ScriptDir "..\backend\src\main\resources\db\migration\V99__insert_test_data_for_verification_tasks.sql"

# Check if SQL file exists
if (-Not (Test-Path $SQL_FILE)) {
    Write-Host "❌ SQL file not found: $SQL_FILE" -ForegroundColor Red
    exit 1
}

# Check if postgres container is running
$containerRunning = docker ps --filter "name=voltgo-postgres" --format "{{.Names}}"
if (-Not $containerRunning) {
    Write-Host "❌ PostgreSQL container 'voltgo-postgres' is not running!" -ForegroundColor Red
    Write-Host "Please start it with: docker-compose up -d postgres" -ForegroundColor Yellow
    exit 1
}

# Execute SQL file using docker exec
Write-Host "Executing SQL file..." -ForegroundColor Yellow
Get-Content $SQL_FILE | docker exec -i voltgo-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Test data inserted successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Test accounts:" -ForegroundColor Cyan
    Write-Host "  - Admin: admin@local / Admin@123"
    Write-Host "  - Collaborator 1: collab1@local / Admin@123"
    Write-Host "  - Collaborator 2: collab2@local / Admin@123"
    Write-Host ""
    Write-Host "Created:" -ForegroundColor Cyan
    Write-Host "  - 4 stations with published versions"
    Write-Host "  - 2 change requests (PENDING, APPROVED)"
    Write-Host "  - 10 verification tasks with various statuses"
    Write-Host "  - Checkin records, evidences, and reviews"
    Write-Host ""
    Write-Host "You can now test the Admin Verification Tasks UI!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to insert test data" -ForegroundColor Red
    exit 1
}

