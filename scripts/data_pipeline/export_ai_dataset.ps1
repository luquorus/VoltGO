$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path "$PSScriptRoot/../.."
$outDir = Join-Path $repoRoot "data/ai"
$queryFile = Join-Path $PSScriptRoot "extract_ai_dataset.sql"
$outFile = Join-Path $outDir "raw_booking_dataset.csv"

if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$sql = Get-Content $queryFile -Raw
$escaped = $sql.Replace('"', '""')

$command = @"
\copy (
$escaped
) TO STDOUT WITH CSV HEADER
"@

docker exec -i voltgo-postgres psql -U voltgo_user -d voltgo -c $command | Out-File -FilePath $outFile -Encoding utf8

Write-Host "Exported AI dataset to $outFile"
