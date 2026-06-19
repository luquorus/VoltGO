$ErrorActionPreference = 'Continue'

# Login
$body = '{"email":"admin2@local","password":"Admin@456"}'
$r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri 'http://localhost:8080/auth/login' -Headers @{'Content-Type'='application/json'} -Body $body
$token = ($r.Content | ConvertFrom-Json).token

# Delete the 10 stations from previous import
$deleteIds = @(
    'ac0ccb77-76e0-4ff2-85ca-cc06df629622',
    'a107cdd0-3e4b-44ad-bb6a-92f3f30e4191',
    '4d834f56-b78d-4659-9325-8a7b7b4f7922',
    '756b9dde-304a-4359-9df4-69e00fd57e9c',
    '6dd122aa-3b2d-4e10-a2ed-1c0cc2cff36d',
    '4cfc65e0-98b7-4445-8632-aa4b7f96a53a',
    '72768c5d-06bb-4694-920b-6112010145c6',
    '917ee2de-6fff-4b16-80ca-f4dcc143eaef',
    'ba27fcd4-5e72-40c6-946a-6bce95965322',
    '2deecb99-bd56-48de-aa08-eb6d71c93eb3'
)
foreach ($id in $deleteIds) {
    try {
        $d = Invoke-WebRequest -UseBasicParsing -Method DELETE -Uri ('http://localhost:8080/api/admin/battery-swap/stations/' + $id) -Headers @{'Authorization'='Bearer ' + $token}
        Write-Host ('DELETED ' + $id.Substring(0,8))
    } catch {
        Write-Host ('FAIL DELETE ' + $id.Substring(0,8) + ' : ' + $_.Exception.Message)
    }
}
Write-Host 'Done cleanup'
