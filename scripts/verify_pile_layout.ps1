$ErrorActionPreference = 'Continue'

function Test-Login {
    $body = '{"email":"admin2@local","password":"Admin@456"}'
    $r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri 'http://localhost:8080/auth/login' -Headers @{'Content-Type'='application/json'} -Body $body
    return ($r.Content | ConvertFrom-Json).token
}

function Get-Detail {
    param([string]$Token, [string]$StationId)
    $r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri ('http://localhost:8080/api/admin/battery-swap/stations/' + $StationId) -Headers @{'Authorization'='Bearer ' + $Token}
    return ($r.Content | ConvertFrom-Json)
}

$token = Test-Login
Write-Host ('Token OK') -ForegroundColor Green

$tests = @(
    @{ id='baa4a686-cae6-4de4-bc7e-b56bcd104776'; name='Long Bien'; csvPiles='5:6'; expectTotal=30 },
    @{ id='a58d73f7-8937-4175-ace7-d59c04fdcadc'; name='Thanh Xuan'; csvPiles='4:6'; expectTotal=24 },
    @{ id='c4880773-6c47-4d3a-adba-7cad02c27ee0'; name='Gia Lam'; csvPiles='2:8'; expectTotal=16 },
    @{ id='49be02c4-c343-4b9d-ace5-6bb1d2052702'; name='Bac Tu Liem'; csvPiles='6:5'; expectTotal=30 },
    @{ id='c0f902fc-038b-453f-9fb5-25594e96e892'; name='Dong Anh'; csvPiles='5:6'; expectTotal=30 },
    @{ id='2008a86d-4cd1-4a8a-8844-1c8f4504802a'; name='Soc Son'; csvPiles=''; expectTotal=20 },
    @{ id='ca353c09-1b9f-4cac-b67e-36be4f219fb8'; name='Ha Dong'; csvPiles='3:8'; expectTotal=24 },
    @{ id='8330dd02-0ece-4487-a1e4-c9b0517d0c0c'; name='Nam Tu Liem'; csvPiles='5:8'; expectTotal=40 },
    @{ id='08dddbbf-33f9-47e5-979e-a8644f78f7af'; name='Cau Giay'; csvPiles='2:6'; expectTotal=12 },
    @{ id='1678e60b-5be0-4bd2-a225-da0621495df3'; name='Tay Ho'; csvPiles='3:6'; expectTotal=18 }
)

foreach ($t in $tests) {
    $d = Get-Detail -Token $token -StationId $t.id
    $pileCount = $d.pileTemplates.Count
    $slotsSum = ($d.pileTemplates | Measure-Object -Property slotsPerPile -Sum).Sum
    $okPiles = if ($t.csvPiles -eq '') {
        # default: ceil(total/6)
        $defaultPiles = [math]::Ceiling($t.expectTotal / 6)
        $pileCount -ge [math]::Floor($t.expectTotal / 6)
    } else {
        $parts = $t.csvPiles.Split(':')
        $expected = [int]$parts[0] * [int]$parts[1]
        $slotsSum -eq $expected
    }
    Write-Host ('--- ' + $t.name + ' (expect ' + $t.csvPiles + ' total=' + $t.expectTotal + ') ---') -ForegroundColor Yellow
    Write-Host ('   totalBatteries=' + $d.totalBatteries + ' totalSlots=' + $d.totalSlots + ' totalPiles=' + $d.totalPiles)
    Write-Host ('   avgChargePowerKw=' + $d.avgChargePowerKw + ' workflowStatus=' + $d.workflowStatus)
    Write-Host ('   pileTemplates count=' + $pileCount + ' | slots sum=' + $slotsSum + ' | ' + ($(if($okPiles){'OK'}else{'FAIL MISMATCH'})))
    foreach ($p in $d.pileTemplates) {
        Write-Host ('     pileIndex=' + $p.pileIndex + ' slotsPerPile=' + $p.slotsPerPile)
    }
}
