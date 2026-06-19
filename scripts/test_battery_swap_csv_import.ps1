$ErrorActionPreference = 'Continue'

function Test-Login {
    Write-Host '=== TEST 1: Login admin2@local ===' -ForegroundColor Cyan
    try {
        $body = '{"email":"admin2@local","password":"Admin@456"}'
        $r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri 'http://localhost:8080/auth/login' -Headers @{'Content-Type'='application/json'} -Body $body
        Write-Host ('HTTP ' + $r.StatusCode)
        $json = $r.Content | ConvertFrom-Json
        Write-Host ('token length: ' + $json.token.Length)
        Write-Host ('userId: ' + $json.userId)
        Write-Host ('role: ' + $json.role)
        return $json.token
    } catch {
        Write-Host ('ERROR: ' + $_.Exception.Message)
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            Write-Host ('Body: ' + $reader.ReadToEnd())
        }
        return $null
    }
}

function Test-ListStations {
    param([string]$Token)
    Write-Host ''
    Write-Host '=== TEST 2: List existing battery swap stations ===' -ForegroundColor Cyan
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri 'http://localhost:8080/api/admin/battery-swap/stations?page=0&size=20' -Headers @{'Authorization'='Bearer ' + $Token}
        Write-Host ('HTTP ' + $r.StatusCode)
        $json = $r.Content | ConvertFrom-Json
        Write-Host ('totalElements: ' + $json.totalElements)
        foreach ($s in $json.content) {
            Write-Host (' - ' + $s.id.Substring(0,8) + ' ' + $s.name + ' | batteries=' + $s.totalBatteries + ' | trustScore=' + $s.trustScore)
        }
    } catch {
        Write-Host ('ERROR: ' + $_.Exception.Message)
    }
}

function Test-ImportCsv {
    param([string]$Token, [string]$CsvPath)
    Write-Host ''
    Write-Host ('=== TEST 3: Import CSV from ' + $CsvPath + ' ===') -ForegroundColor Cyan
    try {
        $fullPath = (Resolve-Path $CsvPath).Path
        $boundary = '----FormBoundary' + [Guid]::NewGuid().ToString('N')
        $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
        $fileName = Split-Path $fullPath -Leaf

        $headerLines = @()
        $headerLines += "--$boundary"
        $headerLines += "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`""
        $headerLines += "Content-Type: text/csv"
        $headerLines += ""
        $headerText = ($headerLines -join "`r`n") + "`r`n"

        $footer = "`r`n--$boundary--`r`n"

        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headerText)
        $footerBytes = [System.Text.Encoding]::UTF8.GetBytes($footer)

        $memStream = New-Object System.IO.MemoryStream
        $memStream.Write($headerBytes, 0, $headerBytes.Length)
        $memStream.Write($fileBytes, 0, $fileBytes.Length)
        $memStream.Write($footerBytes, 0, $footerBytes.Length)

        $contentType = 'multipart/form-data; boundary=' + $boundary
        $r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri 'http://localhost:8080/api/admin/battery-swap/stations/import-csv' -Headers @{'Authorization'='Bearer ' + $Token; 'Content-Type'=$contentType} -Body $memStream.ToArray()
        Write-Host ('HTTP ' + $r.StatusCode)
        $json = $r.Content | ConvertFrom-Json
        Write-Host ('totalRows: ' + $json.totalRows + ' | success: ' + $json.successCount + ' | failure: ' + $json.failureCount)
        foreach ($rr in $json.results) {
            if ($rr.success) {
                Write-Host (' [OK]   row ' + $rr.rowNumber + ' ' + $rr.stationName + ' -> ' + $rr.stationId)
            } else {
                Write-Host (' [FAIL] row ' + $rr.rowNumber + ' ' + $rr.stationName + ' | ' + $rr.errorMessage) -ForegroundColor Red
            }
        }
    } catch {
        Write-Host ('ERROR: ' + $_.Exception.Message)
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            Write-Host ('Body: ' + $reader.ReadToEnd())
        }
    }
}

function Test-GetStation {
    param([string]$Token, [string]$StationId)
    Write-Host ('=== Detail: ' + $StationId + ' ===') -ForegroundColor Cyan
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri ('http://localhost:8080/api/admin/battery-swap/stations/' + $StationId) -Headers @{'Authorization'='Bearer ' + $Token}
        Write-Host ('HTTP ' + $r.StatusCode)
        $json = $r.Content | ConvertFrom-Json
        Write-Host ('name: ' + $json.name)
        Write-Host ('totalBatteries: ' + $json.totalBatteries)
        Write-Host ('avgChargePowerKw: ' + $json.avgChargePowerKw)
        Write-Host ('totalSlots: ' + $json.totalSlots)
        Write-Host ('pileTemplates count: ' + $json.pileTemplates.Count)
        foreach ($p in $json.pileTemplates) {
            Write-Host ('   pileIndex=' + $p.pileIndex + ' slotsPerPile=' + $p.slotsPerPile + ' id=' + $p.id.Substring(0,8))
        }
    } catch {
        Write-Host ('ERROR: ' + $_.Exception.Message)
    }
}

# ====== MAIN ======
$token = Test-Login
if ($token) {
    Test-ListStations -Token $token
    $csvPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\data\battery_swap_stations_v2.csv'))
    Test-ImportCsv -Token $token -CsvPath $csvPath
    Test-ListStations -Token $token
}
