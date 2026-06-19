$ErrorActionPreference = 'Continue'

function Test-Login {
    $body = '{"email":"admin2@local","password":"Admin@456"}'
    $r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri 'http://localhost:8080/auth/login' -Headers @{'Content-Type'='application/json'} -Body $body
    return ($r.Content | ConvertFrom-Json).token
}

function Get-Station-Detail {
    param([string]$Token, [string]$StationId)
    $r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri ('http://localhost:8080/api/admin/battery-swap/stations/' + $StationId) -Headers @{'Authorization'='Bearer ' + $Token}
    return ($r.Content | ConvertFrom-Json)
}

function List-All-Stations {
    param([string]$Token)
    $r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri 'http://localhost:8080/api/admin/battery-swap/stations?page=0&size=50' -Headers @{'Authorization'='Bearer ' + $Token}
    return ($r.Content | ConvertFrom-Json).content
}

$token = Test-Login
Write-Host ('Logged in. Token length: ' + $token.Length) -ForegroundColor Green

$all = List-All-Stations -Token $token
Write-Host ('Total stations: ' + $all.Count) -ForegroundColor Cyan

# Filter only the 10 newly imported ones (by ID prefix in our test set)
$testIds = @(
    'bc704aea-c692-47e6-996e-97bebd28a4f9',
    'ab37dc2b-bebb-409e-a607-ddbf71699b05',
    '912c2387-1641-4d84-a1b3-8f7c04527e82',
    '7afa65d9-5cfb-4509-8f64-ab26fbfe1e37',
    'cc498c68-72dc-44b5-887e-84db44627917',
    '9b2b094c-be21-4b99-984d-d148c351965e',
    '832744fd-4394-455c-ba82-7fc7d6ce5e4e',
    '50672db5-c923-49c6-807c-923227934b93',
    'b34bbf6f-13a0-4d38-9e0e-7a8670455dfb',
    '3afa282b-812f-4267-98fa-7dfe2ed809e2'
)

foreach ($id in $testIds) {
    $d = Get-Station-Detail -Token $token -StationId $id
    Write-Host ('-------------------------------------------------') -ForegroundColor Yellow
    Write-Host ('Station: ' + $d.name)
    Write-Host ('  id: ' + $d.id)
    Write-Host ('  totalBatteries (version): ' + $d.totalBatteries)
    Write-Host ('  avgChargePowerKw: ' + $d.avgChargePowerKw)
    Write-Host ('  totalSlots: ' + $d.totalSlots)
    Write-Host ('  totalPiles: ' + $d.totalPiles)
    Write-Host ('  workflowStatus: ' + $d.workflowStatus)
    Write-Host ('  trustScore: ' + $d.trustScore)
    Write-Host ('  pileTemplates (count=' + $d.pileTemplates.Count + '):')
    foreach ($p in $d.pileTemplates) {
        Write-Host ('    pileIndex=' + $p.pileIndex + ' slotsPerPile=' + $p.slotsPerPile + ' id=' + $p.id)
    }
}
