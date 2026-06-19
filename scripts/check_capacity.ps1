$ErrorActionPreference = 'Continue'

function Test-Login {
    $body = '{"email":"admin2@local","password":"Admin@456"}'
    $r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri 'http://localhost:8080/auth/login' -Headers @{'Content-Type'='application/json'} -Body $body
    return ($r.Content | ConvertFrom-Json).token
}

function Get-Slot-Capacity {
    param([string]$Token, [string]$StationId)
    $uri = 'http://localhost:8080/api/admin/battery-swap/stations/' + $StationId
    $r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $uri -Headers @{'Authorization'='Bearer ' + $Token}
    $json = $r.Content | ConvertFrom-Json
    return $json
}

$token = Test-Login

# Pick 3 stations with different expected capacities
$tests = @(
    @{ id='912c2387-1641-4d84-a1b3-8f7c04527e82'; name='Gia Lam (expect 40 kWh)'; expect=40 },
    @{ id='7afa65d9-5cfb-4509-8f64-ab26fbfe1e37'; name='Bac Tu Liem (expect 80 kWh)'; expect=80 },
    @{ id='50672db5-c923-49c6-807c-923227934b93'; name='Nam Tu Liem (expect 80 kWh)'; expect=80 },
    @{ id='bc704aea-c692-47e6-996e-97bebd28a4f9'; name='Long Bien (expect 60 kWh default)'; expect=60 }
)

foreach ($t in $tests) {
    $d = Get-Slot-Capacity -Token $token -StationId $t.id
    Write-Host ('--- ' + $t.name + ' ---')
    Write-Host ('  pileTemplates: ' + $d.pileTemplates.Count)
    # API doesn't expose per-slot kWh in detail DTO directly, but
    # the avgChargePowerKw returned can hint. Let's also fetch raw pile template via DB? No.
    # We can only check avgChargePowerKw + totalBatteries + pile count.
    Write-Host ('  totalBatteries: ' + $d.totalBatteries)
    Write-Host ('  avgChargePowerKw: ' + $d.avgChargePowerKw)
}
