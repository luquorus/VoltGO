# Test Upload với File Thật - Robust Version
# Script: test_upload_real_file.ps1
# Tác giả: VoltGo Team
# Mục đích: Test full flow upload ảnh lên MinIO qua presigned URL

#region Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Tắt progress bar để log đẹp hơn

# Debug mode - set $true để xem log chi tiết
$DEBUG = $false

# Base URLs
$BACKEND_URL = "http://localhost:8080"
$MINIO_URL = "http://localhost:9000"

# Test file path
$filePath = 'C:\Users\luquo\Downloads\ltq\sk1.jpg'

# Fix TLS cho PowerShell 5.1 trên Windows
# Lỗi "connection closed unexpectedly" thường do TLS version mismatch
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::Expect100Continue = $false
#endregion

#region Helper Functions

function Write-Debug-Log {
    param([string]$Message)
    if ($DEBUG) {
        Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray
    }
}

function Write-Step {
    param([string]$StepNumber, [string]$Message)
    Write-Host "`n$StepNumber`: $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Write-Warning-Message {
    param([string]$Message)
    Write-Host "  [WARNING] $Message" -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Wrapper function để gọi REST API với error handling và logging chi tiết.

.DESCRIPTION
    - Log URL, method, status code
    - Log response body nếu có lỗi
    - Retry logic cho transient errors
    - Fail-fast với exception có thông tin rõ ràng

.PARAMETER Uri
    URL của API endpoint

.PARAMETER Method
    HTTP method (GET, POST, PUT, DELETE)

.PARAMETER Headers
    Headers cho request (thường là Authorization)

.PARAMETER Body
    Body cho POST/PUT request (sẽ tự convert sang JSON nếu là hashtable/object)

.PARAMETER ContentType
    Content-Type header (default: application/json)

.PARAMETER MaxRetries
    Số lần retry khi gặp transient error (default: 3)

.PARAMETER RetryDelaySeconds
    Delay giữa các retry (default: 2)

.EXAMPLE
    $response = Invoke-Api -Uri "http://localhost:8080/auth/login" -Method POST -Body @{email="admin@local"; password="Admin@123"}
#>
function Invoke-Api {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("GET", "POST", "PUT", "DELETE", "PATCH")]
        [string]$Method,
        
        [hashtable]$Headers = @{},
        
        [object]$Body = $null,
        
        [string]$ContentType = "application/json",
        
        [int]$MaxRetries = 3,
        
        [int]$RetryDelaySeconds = 2,
        
        [string]$StepName = ""
    )
    
    Write-Debug-Log ">>> API Call: $Method $Uri"
    if ($StepName) {
        Write-Debug-Log "    Step: $StepName"
    }
    
    # Convert body to JSON if it's a hashtable/PSObject
    $jsonBody = $null
    if ($null -ne $Body) {
        if ($Body -is [string]) {
            $jsonBody = $Body
        } else {
            $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
        }
        Write-Debug-Log "    Body: $jsonBody"
    }
    
    $lastException = $null
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Debug-Log "    Attempt $attempt of $MaxRetries..."
            
            $params = @{
                Uri = $Uri
                Method = $Method
                ContentType = $ContentType
                TimeoutSec = 30
                UseBasicParsing = $true
            }
            
            if ($Headers.Count -gt 0) {
                $params.Headers = $Headers
            }
            
            if ($null -ne $jsonBody) {
                $params.Body = $jsonBody
            }
            
            $response = Invoke-RestMethod @params
            
            Write-Debug-Log "    Response received successfully"
            Write-Debug-Log "    Response: $($response | ConvertTo-Json -Depth 5 -Compress)"
            
            return $response
            
        } catch {
            $lastException = $_
            $errorMessage = $_.Exception.Message
            
            Write-Debug-Log "    Error on attempt $attempt : $errorMessage"
            
            # Check if it's a transient error that we should retry
            $isTransientError = $false
            if ($errorMessage -like "*connection was closed*" -or 
                $errorMessage -like "*Unable to connect*" -or
                $errorMessage -like "*timed out*" -or
                $errorMessage -like "*connection refused*") {
                $isTransientError = $true
            }
            
            # Try to get response body for better error message
            $responseBody = ""
            $statusCode = "N/A"
            if ($_.Exception.Response) {
                try {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                    $stream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                } catch {
                    # Ignore errors reading response
                }
            }
            
            Write-Debug-Log "    Status Code: $statusCode"
            if ($responseBody) {
                Write-Debug-Log "    Response Body: $responseBody"
            }
            
            if ($isTransientError -and $attempt -lt $MaxRetries) {
                Write-Debug-Log "    Transient error, retrying in $RetryDelaySeconds seconds..."
                Start-Sleep -Seconds $RetryDelaySeconds
            } else {
                # Non-retryable error or max retries exceeded
                $fullErrorMessage = @"

API Call Failed!
================
Step: $StepName
Method: $Method
URL: $Uri
Status Code: $statusCode
Error: $errorMessage
Response Body: $responseBody
"@
                Write-Error-Message $fullErrorMessage
                throw $fullErrorMessage
            }
        }
    }
    
    # Should not reach here, but just in case
    throw "API call failed after $MaxRetries attempts. Last error: $($lastException.Exception.Message)"
}

<#
.SYNOPSIS
    Upload file lên MinIO qua presigned URL

.DESCRIPTION
    Dùng Invoke-WebRequest với -InFile để upload binary file trực tiếp

.PARAMETER UploadUrl
    Presigned URL từ backend

.PARAMETER FilePath
    Đường dẫn tới file cần upload

.PARAMETER ContentType
    Content-Type của file (default: image/jpeg)
#>
function Invoke-MinioUpload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$UploadUrl,
        
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [string]$ContentType = "image/jpeg"
    )
    
    Write-Debug-Log ">>> MinIO Upload"
    Write-Debug-Log "    URL: $($UploadUrl.Substring(0, [Math]::Min(120, $UploadUrl.Length)))..."
    Write-Debug-Log "    File: $FilePath"
    Write-Debug-Log "    Content-Type: $ContentType"
    
    # Validate file exists
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $fileInfo = Get-Item $FilePath
    Write-Debug-Log "    File size: $($fileInfo.Length) bytes"
    
    try {
        # Method 1: Using -InFile (recommended for binary files)
        $response = Invoke-WebRequest `
            -Uri $UploadUrl `
            -Method PUT `
            -ContentType $ContentType `
            -InFile $FilePath `
            -UseBasicParsing `
            -TimeoutSec 60
        
        Write-Debug-Log "    Upload successful!"
        Write-Debug-Log "    Status Code: $($response.StatusCode)"
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Content = $response.Content
        }
        
    } catch {
        $errorMessage = $_.Exception.Message
        $statusCode = "N/A"
        $responseBody = ""
        
        if ($_.Exception.Response) {
            try {
                $statusCode = [int]$_.Exception.Response.StatusCode
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
            } catch {}
        }
        
        $fullError = @"

MinIO Upload Failed!
====================
URL: $($UploadUrl.Substring(0, [Math]::Min(120, $UploadUrl.Length)))...
File: $FilePath
Content-Type: $ContentType
Status Code: $statusCode
Error: $errorMessage
Response Body: $responseBody

Possible causes:
1. Presigned URL expired
2. Bucket policy doesn't allow PutObject
3. Content-Type mismatch (if signature includes content-type)
4. Host mismatch (presigned URL host differs from request host)
"@
        Write-Error-Message $fullError
        throw $fullError
    }
}

<#
.SYNOPSIS
    Kiểm tra giá trị không null và không empty

.PARAMETER Value
    Giá trị cần kiểm tra

.PARAMETER Name
    Tên biến (để log khi lỗi)

.PARAMETER StepName
    Tên step hiện tại (để log)
#>
function Assert-NotNull {
    param(
        [object]$Value,
        [string]$Name,
        [string]$StepName = ""
    )
    
    if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) {
        $errorMsg = "Assertion failed: '$Name' is null or empty"
        if ($StepName) {
            $errorMsg += " at step: $StepName"
        }
        Write-Error-Message $errorMsg
        throw $errorMsg
    }
    
    Write-Debug-Log "    Assert: $Name = $Value"
}

#endregion

#region Main Script

Write-Host "=== TEST UPLOAD VỚI FILE THẬT (Robust Version) ===" -ForegroundColor Magenta
Write-Host "Backend URL: $BACKEND_URL"
Write-Host "MinIO URL: $MINIO_URL"
Write-Host "Debug Mode: $DEBUG`n"

# Pre-check: Verify test file exists
Write-Step "Pre-check" "Verify test file"
if (-not (Test-Path $filePath)) {
    Write-Error-Message "File not found: $filePath"
    exit 1
}
$fileInfo = Get-Item $filePath
Write-Host "  Path: $filePath"
Write-Host "  Size: $($fileInfo.Length) bytes"
Write-Host "  Type: $($fileInfo.Extension)"
Write-Success "File exists and readable"

# Pre-check: Verify backend is healthy
Write-Step "Pre-check" "Verify backend health"
try {
    $health = Invoke-Api -Uri "$BACKEND_URL/actuator/health" -Method GET -StepName "Health Check"
    Write-Success "Backend is ready: $($health.status)"
} catch {
    Write-Error-Message "Backend is not responding. Please start backend first."
    Write-Host "`nTo start backend:" -ForegroundColor Yellow
    Write-Host "  cd infra; docker compose up -d backend"
    Write-Host "  Wait 20-30 seconds for Spring Boot to start"
    exit 1
}

# Step 1: Login
Write-Step "Step 1" "Login (Admin, Collaborator, Provider)"

$adminLoginResp = Invoke-Api `
    -Uri "$BACKEND_URL/auth/login" `
    -Method POST `
    -Body @{email="admin@local"; password="Admin@123"} `
    -StepName "Admin Login"
Assert-NotNull -Value $adminLoginResp.token -Name "adminToken" -StepName "Admin Login"
$adminToken = $adminLoginResp.token
$adminHeaders = @{Authorization = "Bearer $adminToken"}
Write-Success "Admin logged in"

$collabResp = Invoke-Api `
    -Uri "$BACKEND_URL/auth/login" `
    -Method POST `
    -Body @{email="newcollab@test.local"; password="Collab@123"} `
    -StepName "Collab Login"
Assert-NotNull -Value $collabResp.token -Name "collabToken" -StepName "Collab Login"
$collabToken = $collabResp.token
$collabHeaders = @{Authorization = "Bearer $collabToken"}
Write-Success "Collaborator logged in (userId: $($collabResp.userId))"

$providerResp = Invoke-Api `
    -Uri "$BACKEND_URL/auth/login" `
    -Method POST `
    -Body @{email="provider@test.local"; password="Provider@123"} `
    -StepName "Provider Login"
Assert-NotNull -Value $providerResp.token -Name "providerToken" -StepName "Provider Login"
$providerToken = $providerResp.token
$providerHeaders = @{Authorization = "Bearer $providerToken"}
Write-Success "Provider logged in"

# Step 2: Get Station
Write-Step "Step 2" "Get Station"
$stationUrl = "$BACKEND_URL/api/ev/stations?lat=21.0400&lng=105.8700&radiusKm=10"
$stations = Invoke-Api -Uri $stationUrl -Method GET -Headers $providerHeaders -StepName "Get Stations"
Assert-NotNull -Value $stations -Name "stations" -StepName "Get Stations"
Assert-NotNull -Value $stations.content -Name "stations.content" -StepName "Get Stations"

if ($stations.content.Count -eq 0) {
    Write-Error-Message "No stations found in the area. Please seed database with test data."
    exit 1
}

$stationId = $stations.content[0].stationId
Assert-NotNull -Value $stationId -Name "stationId" -StepName "Get Stations"
Write-Success "Using station: $stationId"

# Step 3: Create Verification Task
Write-Step "Step 3" "Create Verification Task"
$taskResp = Invoke-Api `
    -Uri "$BACKEND_URL/api/admin/verification-tasks" `
    -Method POST `
    -Headers $adminHeaders `
    -Body @{stationId = $stationId; priority = 1} `
    -StepName "Create Task"
Assert-NotNull -Value $taskResp.id -Name "taskId" -StepName "Create Task"
$taskId = $taskResp.id
Write-Success "Task created: $taskId"

# Step 4: Assign Task
Write-Step "Step 4" "Assign Task"
Assert-NotNull -Value $collabResp.userId -Name "collabUserId" -StepName "Assign Task"
$assignResp = Invoke-Api `
    -Uri "$BACKEND_URL/api/admin/verification-tasks/$taskId/assign" `
    -Method POST `
    -Headers $adminHeaders `
    -Body @{collaboratorUserId = $collabResp.userId} `
    -StepName "Assign Task"
Assert-NotNull -Value $assignResp.status -Name "assignResp.status" -StepName "Assign Task"
Write-Success "Task assigned: $($assignResp.status)"

# Step 5: Check-in
Write-Step "Step 5" "Check-in"
$stationDetail = Invoke-Api `
    -Uri "$BACKEND_URL/api/ev/stations/$stationId" `
    -Method GET `
    -Headers $providerHeaders `
    -StepName "Get Station Detail"
Assert-NotNull -Value $stationDetail.lat -Name "station.lat" -StepName "Get Station Detail"
Assert-NotNull -Value $stationDetail.lng -Name "station.lng" -StepName "Get Station Detail"

$checkinResp = Invoke-Api `
    -Uri "$BACKEND_URL/api/collab/mobile/tasks/$taskId/check-in" `
    -Method POST `
    -Headers $collabHeaders `
    -Body @{lat = $stationDetail.lat; lng = $stationDetail.lng; deviceNote = "Test device"} `
    -StepName "Check-in"
Assert-NotNull -Value $checkinResp.status -Name "checkinResp.status" -StepName "Check-in"
Write-Success "Check-in successful: $($checkinResp.status)"

# Step 6: Request Presigned Upload URL
Write-Step "Step 6" "Request Presigned Upload URL"
$contentType = "image/jpeg"
$uploadResp = Invoke-Api `
    -Uri "$BACKEND_URL/api/collab/mobile/files/presign-upload" `
    -Method POST `
    -Headers $collabHeaders `
    -Body @{contentType = $contentType} `
    -StepName "Request Presign"
Assert-NotNull -Value $uploadResp.objectKey -Name "objectKey" -StepName "Request Presign"
Assert-NotNull -Value $uploadResp.uploadUrl -Name "uploadUrl" -StepName "Request Presign"

$objectKey = $uploadResp.objectKey
$uploadUrl = $uploadResp.uploadUrl

Write-Success "Presigned URL received:"
Write-Host "    ObjectKey: $objectKey"
Write-Host "    UploadURL: $($uploadUrl.Substring(0, [Math]::Min(120, $uploadUrl.Length)))..."
Write-Host "    ExpiresAt: $($uploadResp.expiresAt)"

# Note: URL uses 'minio:9000' hostname which requires hosts file entry
# If you get DNS errors, run setup_minio_host.ps1 as Administrator
if ($uploadUrl -like "*minio:9000*") {
    Write-Debug-Log "URL uses 'minio:9000' hostname (expected when backend runs in Docker)"
}

# Step 7: Upload File to MinIO
Write-Step "Step 7" "Upload File to MinIO"
Write-Host "  Uploading to MinIO..."
Write-Host "  URL: $($uploadUrl.Substring(0, [Math]::Min(120, $uploadUrl.Length)))..."
Write-Host "  Method: PUT"
Write-Host "  Content-Type: $contentType"
Write-Host "  File size: $($fileInfo.Length) bytes"

$uploadResult = Invoke-MinioUpload -UploadUrl $uploadUrl -FilePath $filePath -ContentType $contentType
Write-Success "File uploaded successfully!"
Write-Host "    Status Code: $($uploadResult.StatusCode)"

# Step 8: Verify File in MinIO
Write-Step "Step 8" "Verify File in MinIO"
try {
    $viewResp = Invoke-Api `
        -Uri "$BACKEND_URL/api/admin/files/presign-view?objectKey=$objectKey" `
        -Method GET `
        -Headers $adminHeaders `
        -StepName "Get View URL"
    Assert-NotNull -Value $viewResp.viewUrl -Name "viewUrl" -StepName "Verify File"
    Write-Success "View URL generated successfully"
    Write-Host "    ViewURL: $($viewResp.viewUrl.Substring(0, [Math]::Min(100, $viewResp.viewUrl.Length)))..."
    Write-Host "    ExpiresAt: $($viewResp.expiresAt)"
    Write-Success "File exists and accessible!"
} catch {
    Write-Warning-Message "Could not generate view URL: $($_.Exception.Message)"
}

# Step 9: Submit Evidence
Write-Step "Step 9" "Submit Evidence"
$evidenceResp = Invoke-Api `
    -Uri "$BACKEND_URL/api/collab/mobile/tasks/$taskId/submit-evidence" `
    -Method POST `
    -Headers $collabHeaders `
    -Body @{photoObjectKey = $objectKey; note = "Evidence photo uploaded successfully - real file"} `
    -StepName "Submit Evidence"
Assert-NotNull -Value $evidenceResp.status -Name "evidenceResp.status" -StepName "Submit Evidence"
Write-Success "Evidence submitted: $($evidenceResp.status)"
Write-Host "    Photo objectKey: $objectKey"

# Step 10: Admin Review
Write-Step "Step 10" "Admin Review"
$reviewResp = Invoke-Api `
    -Uri "$BACKEND_URL/api/admin/verification-tasks/$taskId/review" `
    -Method POST `
    -Headers $adminHeaders `
    -Body @{result = "PASS"; adminNote = "Evidence verified - real file uploaded successfully"} `
    -StepName "Admin Review"
Assert-NotNull -Value $reviewResp.review -Name "reviewResp.review" -StepName "Admin Review"
Write-Success "Review completed: $($reviewResp.review.result)"
Write-Host "    Admin note: $($reviewResp.review.adminNote)"

# Step 11: Get View URLs
Write-Step "Step 11" "Get Presigned View URLs"
$adminViewResp = Invoke-Api `
    -Uri "$BACKEND_URL/api/admin/files/presign-view?objectKey=$objectKey" `
    -Method GET `
    -Headers $adminHeaders `
    -StepName "Admin View URL"
Write-Success "Admin view URL: Generated (expires: $($adminViewResp.expiresAt))"

$collabViewResp = Invoke-Api `
    -Uri "$BACKEND_URL/api/collab/web/files/presign-view?objectKey=$objectKey" `
    -Method GET `
    -Headers $collabHeaders `
    -StepName "Collab View URL"
Write-Success "Collaborator view URL: Generated (expires: $($collabViewResp.expiresAt))"

# Summary
Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Magenta
Write-Success "All steps completed successfully!"
Write-Success "File uploaded to MinIO: $objectKey"
Write-Success "Evidence submitted and reviewed: PASS"
Write-Success "View URLs generated for both Admin and Collaborator"
Write-Success "MinIO integration working correctly!"

Write-Host "`nTo verify manually, open MinIO Console:" -ForegroundColor Yellow
Write-Host "  URL: http://localhost:9001"
Write-Host "  Username: minioadmin"
Write-Host "  Password: minioadmin"
Write-Host "  Bucket: voltgo-evidence"
Write-Host "  Object: $objectKey"

#endregion
