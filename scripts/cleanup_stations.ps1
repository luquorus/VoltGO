$ErrorActionPreference = 'Continue'

# Step 1: Login
$body = '{"email":"admin2@local","password":"Admin@456"}'
$r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri 'http://localhost:8080/auth/login' -Headers @{'Content-Type'='application/json'} -Body $body
$token = ($r.Content | ConvertFrom-Json).token
Write-Host ('Token: ' + $token.Substring(0, 30) + '...') -ForegroundColor Green

# Step 2: List all stations
$r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri 'http://localhost:8080/api/admin/battery-swap/stations?page=0&size=100' -Headers @{'Authorization'='Bearer ' + $token}
$json = $r.Content | ConvertFrom-Json
Write-Host ('Current total: ' + $json.totalElements) -ForegroundColor Cyan

# Step 3: Delete the 10 stations we created earlier (id list from previous test)
$deleteIds = @(
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
foreach ($id in $deleteIds) {
    try {
        $d = Invoke-WebRequest -UseBasicParsing -Method DELETE -Uri ('http://localhost:8080/api/admin/battery-swap/stations/' + $id) -Headers @{'Authorization'='Bearer ' + $token}
        Write-Host ('DELETED ' + $id.Substring(0,8) + ' HTTP ' + $d.StatusCode)
    } catch {
        Write-Host ('FAIL DELETE ' + $id.Substring(0,8) + ' : ' + $_.Exception.Message)
    }
}

# Step 4: List again
$r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri 'http://localhost:8080/api/admin/battery-swap/stations?page=0&size=100' -Headers @{'Authorization'='Bearer ' + $token}
$json = $r.Content | ConvertFrom-Json
Write-Host ('After delete: ' + $json.totalElements) -ForegroundColor Cyan
