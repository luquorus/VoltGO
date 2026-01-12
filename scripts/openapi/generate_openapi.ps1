# Generate OpenAPI Dart client from openapi.yaml
# Requirements: openapi-generator-cli installed (npm install -g @openapitools/openapi-generator-cli)
# Chạy từ project root: .\scripts\openapi\generate_openapi.ps1

# Get script directory và project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

$OPENAPI_YAML = Join-Path $ProjectRoot "shared\openapi\openapi.yaml"
$OUTPUT_DIR = Join-Path $ProjectRoot "apps\shared\shared_api\lib\generated"

if (-not (Test-Path $OPENAPI_YAML)) {
    Write-Host "Error: $OPENAPI_YAML not found" -ForegroundColor Red
    exit 1
}

Write-Host "Generating OpenAPI Dart client..." -ForegroundColor Green
Write-Host "Input: $OPENAPI_YAML" -ForegroundColor Cyan
Write-Host "Output: $OUTPUT_DIR" -ForegroundColor Cyan

# Create output directory
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null

# Generate client
npx -y @openapitools/openapi-generator-cli generate `
    -i $OPENAPI_YAML `
    -g dart `
    -o $OUTPUT_DIR `
    --additional-properties=pubName=shared_api_generated,pubVersion=1.0.0,dateLibrary=core,serializationLibrary=json_serializable,enumUnknownDefaultCase=true

if ($LASTEXITCODE -ne 0) {
    Write-Host "Generation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`nOpenAPI client generated successfully!" -ForegroundColor Green
Write-Host "Files: $OUTPUT_DIR" -ForegroundColor Cyan

