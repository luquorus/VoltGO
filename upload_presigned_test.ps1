# Standalone Presigned URL Upload Test
# Script: upload_presigned_test.ps1
# Mục đích: Test upload trực tiếp lên MinIO qua presigned URL (tách riêng để debug)
# 
# Usage:
#   .\upload_presigned_test.ps1                          # Chạy với default settings
#   .\upload_presigned_test.ps1 -Debug                   # Bật debug mode
#   .\upload_presigned_test.ps1 -FilePath "C:\path\to\file.jpg"  # Dùng file khác
#   .\upload_presigned_test.ps1 -SkipPresign -UploadUrl "http://..."  # Bỏ qua bước presign, dùng URL sẵn

param(
    [string]$FilePath = 'C:\Users\luquo\Downloads\ltq\sk2.jpg',
    [string]$BackendUrl = "http://localhost:8080",
    [string]$MinioUrl = "http://localhost:9000",
    [switch]$Debug,
    [switch]$SkipPresign,
    [string]$UploadUrl = ""
)

#region Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fix TLS cho PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::Expect100Continue = $false
#endregion

#region Helper Functions
function Write-DbgLog {
    param([string]$Message)
    if ($Debug) {
        Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray
    }
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Err {
    param([string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARNING] $Message" -ForegroundColor Yellow
}
#endregion

#region Main

Write-Host "=== STANDALONE PRESIGNED URL UPLOAD TEST ===" -ForegroundColor Magenta
Write-Host "Backend: $BackendUrl"
Write-Host "MinIO: $MinioUrl"
Write-Host "File: $FilePath"
Write-Host "Debug: $Debug"
Write-Host ""

# Step 1: Verify file exists
Write-Step "Verify test file"
if (-not (Test-Path $FilePath)) {
    Write-Err "File not found: $FilePath"
    exit 1
}
$fileInfo = Get-Item $FilePath
Write-Host "  Size: $($fileInfo.Length) bytes"
Write-Host "  Extension: $($fileInfo.Extension)"
Write-OK "File exists"

# Determine content type
$contentType = switch ($fileInfo.Extension.ToLower()) {
    ".jpg" { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".png" { "image/png" }
    ".gif" { "image/gif" }
    ".webp" { "image/webp" }
    default { "application/octet-stream" }
}
Write-Host "  Content-Type: $contentType"

# Step 2: Login (only if we need presigned URL)
if (-not $SkipPresign) {
    Write-Step "Login to get token"
    try {
        $loginBody = @{email="newcollab@test.local"; password="Collab@123"} | ConvertTo-Json
        Write-DbgLog "POST $BackendUrl/auth/login"
        Write-DbgLog "Body: $loginBody"
        
        $loginResp = Invoke-RestMethod `
            -Uri "$BackendUrl/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body $loginBody `
            -TimeoutSec 30
        
        if ($null -eq $loginResp.token) {
            Write-Err "Login response missing token"
            Write-Host "Response: $($loginResp | ConvertTo-Json)"
            exit 1
        }
        
        $token = $loginResp.token
        Write-OK "Logged in as: $($loginResp.email)"
        Write-DbgLog "Token: $($token.Substring(0, 20))..."
        
    } catch {
        Write-Err "Login failed: $($_.Exception.Message)"
        
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            Write-Host "  Status: $statusCode"
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                Write-Host "  Body: $body"
            } catch {}
        }
        
        Write-Host "`nPossible causes:" -ForegroundColor Yellow
        Write-Host "  1. Backend not running - start with: cd infra; docker compose up -d backend"
        Write-Host "  2. Backend still starting - wait 20-30 seconds after container starts"
        Write-Host "  3. TLS issue - this script sets TLS 1.2, but backend might require different"
        Write-Host "  4. User not exist - run database seed"
        exit 1
    }

    # Step 3: Request presigned URL
    Write-Step "Request presigned upload URL"
    try {
        $presignBody = @{contentType = $contentType} | ConvertTo-Json
        Write-DbgLog "POST $BackendUrl/api/collab/mobile/files/presign-upload"
        Write-DbgLog "Body: $presignBody"
        
        $presignResp = Invoke-RestMethod `
            -Uri "$BackendUrl/api/collab/mobile/files/presign-upload" `
            -Method POST `
            -ContentType "application/json" `
            -Headers @{Authorization = "Bearer $token"} `
            -Body $presignBody `
            -TimeoutSec 30
        
        if ($null -eq $presignResp.uploadUrl) {
            Write-Err "Presign response missing uploadUrl"
            Write-Host "Response: $($presignResp | ConvertTo-Json)"
            exit 1
        }
        
        $UploadUrl = $presignResp.uploadUrl
        $objectKey = $presignResp.objectKey
        
        Write-OK "Presigned URL received"
        Write-Host "  ObjectKey: $objectKey"
        Write-Host "  URL: $($UploadUrl.Substring(0, [Math]::Min(100, $UploadUrl.Length)))..."
        Write-Host "  Expires: $($presignResp.expiresAt)"
        
        # Check if URL uses correct host
        if ($UploadUrl -like "*minio:9000*") {
            Write-Warn "URL uses internal hostname 'minio:9000'"
            Write-Host "  Client cannot reach 'minio' hostname from host machine."
            Write-Host "  Backend should set MINIO_PUBLIC_ENDPOINT=http://localhost:9000"
            
            # Offer to fix it manually
            $fixedUrl = $UploadUrl -replace "minio:9000", "localhost:9000"
            Write-Host "`n  Auto-replacing 'minio:9000' -> 'localhost:9000'"
            Write-Warn "NOTE: This will cause SignatureDoesNotMatch error because signature was computed for 'minio' host"
            $UploadUrl = $fixedUrl
        }
        
    } catch {
        Write-Err "Presign request failed: $($_.Exception.Message)"
        
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            Write-Host "  Status: $statusCode"
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                Write-Host "  Body: $body"
            } catch {}
        }
        exit 1
    }
} else {
    Write-Step "Skip presign (using provided URL)"
    if ([string]::IsNullOrEmpty($UploadUrl)) {
        Write-Err "Must provide -UploadUrl when using -SkipPresign"
        exit 1
    }
    Write-OK "Using provided URL"
    Write-Host "  URL: $($UploadUrl.Substring(0, [Math]::Min(100, $UploadUrl.Length)))..."
}

# Step 4: Upload file to MinIO
Write-Step "Upload file to MinIO"
Write-Host "  Method: PUT"
Write-Host "  Content-Type: $contentType"
Write-Host "  File size: $($fileInfo.Length) bytes"

try {
    Write-DbgLog "PUT $UploadUrl"
    Write-DbgLog "Content-Type: $contentType"
    
    # Use -InFile for binary upload
    $uploadResp = Invoke-WebRequest `
        -Uri $UploadUrl `
        -Method PUT `
        -ContentType $contentType `
        -InFile $FilePath `
        -UseBasicParsing `
        -TimeoutSec 60
    
    Write-OK "Upload successful!"
    Write-Host "  Status: $($uploadResp.StatusCode) $($uploadResp.StatusDescription)"
    
    # Check ETag header (MinIO returns this on successful upload)
    $etag = $uploadResp.Headers["ETag"]
    if ($etag) {
        Write-Host "  ETag: $etag"
    }
    
} catch {
    Write-Err "Upload failed!"
    $errorMsg = $_.Exception.Message
    Write-Host "  Error: $errorMsg"
    
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
        Write-Host "  Status: $statusCode"
        
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $body = $reader.ReadToEnd()
            if ($body) {
                Write-Host "  Response Body:"
                Write-Host $body
            }
        } catch {}
    }
    
    Write-Host "`n=== TROUBLESHOOTING GUIDE ===" -ForegroundColor Yellow
    
    if ($statusCode -eq 403) {
        Write-Host @"
403 Forbidden - Possible causes:
1. Presigned URL expired (default: 15 minutes)
2. SignatureDoesNotMatch:
   - Host in URL doesn't match what client uses
   - Backend presigns with 'minio:9000' but client calls 'localhost:9000'
   - Fix: Set MINIO_PUBLIC_ENDPOINT=http://localhost:9000 in docker-compose.yml
3. Bucket policy doesn't allow anonymous PutObject
   - Check MinIO console: http://localhost:9001
   - Login: minioadmin / minioadmin
   - Check bucket policy for voltgo-evidence
"@
    } elseif ($errorMsg -like "*connection*closed*" -or $errorMsg -like "*refused*") {
        Write-Host @"
Connection error - Possible causes:
1. MinIO not running:
   - cd infra; docker compose ps minio
   - docker compose up -d minio
2. Port 9000 not exposed or blocked by firewall
3. Wrong URL scheme (http vs https)
"@
    } elseif ($errorMsg -like "*name could not be resolved*") {
        Write-Host @"
DNS resolution error - Possible causes:
1. URL contains internal Docker hostname (e.g., 'minio:9000')
   - Should be 'localhost:9000' for host machine access
   - Set MINIO_PUBLIC_ENDPOINT=http://localhost:9000
"@
    }
    
    exit 1
}

# Step 5: Verify upload (optional, only if we have objectKey)
if ($objectKey) {
    Write-Step "Verify file exists in MinIO (via backend)"
    try {
        $viewUrl = "$BackendUrl/api/admin/files/presign-view?objectKey=$objectKey"
        
        # Need admin token for this
        $adminLogin = Invoke-RestMethod `
            -Uri "$BackendUrl/auth/login" `
            -Method POST `
            -ContentType "application/json" `
            -Body (@{email="admin@local"; password="Admin@123"} | ConvertTo-Json)
        
        $viewResp = Invoke-RestMethod `
            -Uri $viewUrl `
            -Method GET `
            -Headers @{Authorization = "Bearer $($adminLogin.token)"}
        
        Write-OK "File verified in MinIO"
        Write-Host "  View URL: $($viewResp.viewUrl.Substring(0, [Math]::Min(80, $viewResp.viewUrl.Length)))..."
        
    } catch {
        Write-Warn "Could not verify file: $($_.Exception.Message)"
    }
}

Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Magenta
Write-OK "Presigned URL upload working correctly!"

Write-Host "`nTo view file in MinIO Console:" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:9001"
Write-Host "  Login: minioadmin / minioadmin"
if ($objectKey) {
    Write-Host "  Object: $objectKey"
}

#endregion

