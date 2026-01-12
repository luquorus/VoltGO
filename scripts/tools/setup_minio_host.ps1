# Setup MinIO hostname for presigned URL to work
# Run this script with Administrator privileges

Write-Host "=== MinIO Hostname Setup ===" -ForegroundColor Magenta
Write-Host @"
This script adds 'minio' hostname to your Windows hosts file.
This is required because:
1. Backend runs in Docker and connects to MinIO via hostname 'minio'
2. Presigned URLs contain this hostname
3. Your Windows machine needs to resolve 'minio' to 127.0.0.1

"@

$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$hostsEntry = "127.0.0.1 minio"

# Check if already configured
$content = Get-Content $hostsPath -Raw
if ($content -match "^\s*127\.0\.0\.1\s+minio") {
    Write-Host "[OK] 'minio' hostname already configured in hosts file" -ForegroundColor Green
    Write-Host "Testing resolution..."
    try {
        $result = [System.Net.Dns]::GetHostAddresses("minio")
        Write-Host "[OK] 'minio' resolves to: $($result.IPAddressToString)" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] DNS resolution failed, but hosts file is configured" -ForegroundColor Yellow
    }
    exit 0
}

# Check if running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ERROR] This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host @"

Please run one of the following:

Option 1 - Run this script as Administrator:
  Right-click PowerShell -> Run as Administrator
  cd $PWD
  .\setup_minio_host.ps1

Option 2 - Add manually:
  1. Open Notepad as Administrator
  2. Open file: C:\Windows\System32\drivers\etc\hosts
  3. Add this line at the end:
     127.0.0.1 minio
  4. Save and close

"@
    exit 1
}

# Add entry
Write-Host "Adding '$hostsEntry' to hosts file..." -ForegroundColor Yellow
try {
    Add-Content -Path $hostsPath -Value "`n$hostsEntry" -ErrorAction Stop
    Write-Host "[OK] Successfully added 'minio' to hosts file" -ForegroundColor Green
    
    # Flush DNS cache
    Write-Host "Flushing DNS cache..."
    ipconfig /flushdns | Out-Null
    
    # Test resolution
    Write-Host "Testing resolution..."
    Start-Sleep -Seconds 1
    try {
        $result = [System.Net.Dns]::GetHostAddresses("minio")
        Write-Host "[OK] 'minio' now resolves to: $($result.IPAddressToString)" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] DNS resolution test failed. Try restarting your terminal." -ForegroundColor Yellow
    }
    
    Write-Host @"

Setup complete! You can now run:
  .\test_upload_real_file.ps1

"@ -ForegroundColor Cyan

} catch {
    Write-Host "[ERROR] Failed to modify hosts file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

