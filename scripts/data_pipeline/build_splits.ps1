$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path "$PSScriptRoot/../.."
$inFile = Join-Path $repoRoot "data/ai/raw_booking_dataset.csv"
$outDir = Join-Path $repoRoot "data/ai"

if (!(Test-Path $inFile)) {
    throw "Input file not found: $inFile. Run export_ai_dataset.ps1 first."
}

$rows = Import-Csv $inFile | Sort-Object {[datetime]$_.'created_at'}
$count = $rows.Count
if ($count -lt 10) {
    throw "Dataset too small for splitting. Rows: $count"
}

$trainEnd = [int]($count * 0.7)
$valEnd = [int]($count * 0.85)

$train = $rows[0..($trainEnd - 1)]
$val = $rows[$trainEnd..($valEnd - 1)]
$test = $rows[$valEnd..($count - 1)]

$train | Export-Csv (Join-Path $outDir "train.csv") -NoTypeInformation -Encoding UTF8
$val | Export-Csv (Join-Path $outDir "val.csv") -NoTypeInformation -Encoding UTF8
$test | Export-Csv (Join-Path $outDir "test.csv") -NoTypeInformation -Encoding UTF8

Write-Host "Split complete:"
Write-Host "  train: $($train.Count)"
Write-Host "  val:   $($val.Count)"
Write-Host "  test:  $($test.Count)"
