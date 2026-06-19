$ErrorActionFailureAction = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

# Login
$body = '{"email":"admin2@local","password":"Admin@456"}'
$r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri 'http://localhost:8080/auth/login' -Headers @{'Content-Type'='application/json'} -Body $body
$token = ($r.Content | ConvertFrom-Json).token
Write-Host ('Token OK') -ForegroundColor Green

# List current stations
$r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri 'http://localhost:8080/api/admin/battery-swap/stations?page=0&size=100' -Headers @{'Authorization'='Bearer ' + $token}
$json = $r.Content | ConvertFrom-Json
Write-Host ('Current total: ' + $json.totalElements) -ForegroundColor Cyan

# Delete the 10 stations from previous (broken) import
$deleteIds = @(
    'baa4a686-cae6-4de4-bc7e-b56bcd104776',
    'a58d73f7-8937-4175-ace7-d59c04fdcadc',
    'c4880773-6c47-4d3a-adba-7cad02c27ee0',
    '49be02c4-c343-4b9d-ace5-6bb1d2052702',
    'c0f902fc-038b-453f-9fb5-25594e96e892',
    '2008a86d-4cd1-4a8a-8844-1c8f4504802a',
    'ca353c09-1b9f-4cac-b67e-36be4f219fb8',
    '8330dd02-0ece-4487-a1e4-c9b0517d0c0c',
    '08dddbbf-33f9-47e5-979e-a8644f78f7af',
    '1678e60b-5be0-4bd2-a225-da0621495df3'
)
foreach ($id in $deleteIds) {
    try {
        $d = Invoke-WebRequest -UseBasicParsing -Method DELETE -Uri ('http://localhost:8080/api/admin/battery-swap/stations/' + $id) -Headers @{'Authorization'='Bearer ' + $token}
        Write-Host ('DELETED ' + $id.Substring(0,8) + ' HTTP ' + $d.StatusCode)
    } catch {
        Write-Host ('FAIL DELETE ' + $id.Substring(0,8) + ' : ' + $_.Exception.Message)
    }
}

# Re-list
$r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri 'http://localhost:8080/api/admin/battery-swap/stations?page=0&size=100' -Headers @{'Authorization'='Bearer ' + $token}
$json = $r.Content | ConvertFrom-Json
Write-Host ('After delete: ' + $json.totalElements) -ForegroundColor Cyan
