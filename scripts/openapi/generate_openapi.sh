#!/bin/bash
# Generate OpenAPI Dart client from openapi.yaml
# Requirements: openapi-generator-cli installed (npm install -g @openapitools/openapi-generator-cli)
# Chạy từ project root: bash scripts/openapi/generate_openapi.sh

# Get script directory và project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

OPENAPI_YAML="$PROJECT_ROOT/shared/openapi/openapi.yaml"
OUTPUT_DIR="$PROJECT_ROOT/apps/shared/shared_api/lib/generated"

if [ ! -f "$OPENAPI_YAML" ]; then
    echo "Error: $OPENAPI_YAML not found"
    exit 1
fi

echo "Generating OpenAPI Dart client..."
echo "Input: $OPENAPI_YAML"
echo "Output: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate client
npx -y @openapitools/openapi-generator-cli generate \
    -i "$OPENAPI_YAML" \
    -g dart \
    -o "$OUTPUT_DIR" \
    --additional-properties=pubName=shared_api_generated,pubVersion=1.0.0,dateLibrary=core,serializationLibrary=json_serializable,enumUnknownDefaultCase=true

if [ $? -ne 0 ]; then
    echo "Generation failed!"
    exit 1
fi

echo ""
echo "OpenAPI client generated successfully!"
echo "Files: $OUTPUT_DIR"

