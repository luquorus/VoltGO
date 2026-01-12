# Scripts Directory

Các script tiện ích và test cho VoltGo project.

## Cấu trúc

```
scripts/
├── tests/          # Test scripts
├── tools/          # Utility scripts
└── openapi/        # OpenAPI generation scripts
```

## Test Scripts (`tests/`)

### `test_fe3_api.ps1`
Test FE-3 API Client integration.
```powershell
.\scripts\tests\test_fe3_api.ps1
```

### `test_fe3_simple.dart`
Simple Dart test cho API connectivity.
```bash
dart run scripts\tests\test_fe3_simple.dart
```

### `test_booking.ps1`
Test booking API endpoints.

### `test_payment.ps1`
Test payment API endpoints.

### `test_minio_upload.ps1`
Test MinIO file upload.

### `test_upload_real_file.ps1`
Test file upload với real files.

### `upload_presigned_test.ps1`
Test presigned URL upload.

### `test_frontend_edge.ps1`
Test frontend apps trên Edge browser (mở tự động).
```powershell
.\scripts\tests\test_frontend_edge.ps1
```

## Tools (`tools/`)

### `open_frontend_apps.ps1`
Mở tất cả frontend apps trong Edge browser.
```powershell
.\scripts\tools\open_frontend_apps.ps1
```

### `dev_mode.ps1`
Start development mode với hot reload.
```powershell
.\scripts\tools\dev_mode.ps1
```

### `reload_frontend.ps1`
Reload frontend apps sau khi sửa code (rebuild Docker).
```powershell
# Reload tất cả apps
.\scripts\tools\reload_frontend.ps1

# Reload 1 app cụ thể
.\scripts\tools\reload_frontend.ps1 ev_user_mobile
.\scripts\tools\reload_frontend.ps1 admin_web
```

### `setup_minio_host.ps1`
Setup MinIO host configuration.

## OpenAPI (`openapi/`)

### `generate_openapi.ps1` (Windows)
Generate OpenAPI Dart client từ openapi.yaml.
```powershell
.\scripts\openapi\generate_openapi.ps1
```

### `generate_openapi.sh` (Linux/Mac)
```bash
bash scripts/openapi/generate_openapi.sh
```

## Usage

Tất cả scripts nên chạy từ project root:
```powershell
cd C:\Users\luquo\2025.1\GR2\ver1\VoltGo
.\scripts\tests\test_fe3_api.ps1
```

