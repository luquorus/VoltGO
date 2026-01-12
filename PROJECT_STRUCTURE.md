# VoltGo Project Structure

Cấu trúc dự án VoltGo đã được tổ chức lại.

## Cấu trúc thư mục

```
VoltGo/
├── apps/                      # Flutter applications
│   ├── admin_web/            # Admin Web Portal
│   ├── collab_mobile/        # Collaborator Mobile App
│   ├── collab_web/           # Collaborator Web App
│   ├── ev_user_mobile/       # EV User Mobile App
│   └── shared/               # Shared packages
│       ├── shared_api/       # OpenAPI client & API factory
│       ├── shared_auth/      # Authentication
│       ├── shared_network/   # Network layer (Dio)
│       └── shared_ui/        # UI components
│
├── backend/                  # Spring Boot Backend
│   ├── src/
│   │   ├── main/java/       # Java source code
│   │   └── main/resources/  # Config & migrations
│   └── QUICK_START.md
│
├── infra/                    # Infrastructure (Docker)
│   ├── docker-compose.yml
│   └── README.md
│
├── shared/                   # Shared resources
│   ├── docs/                # Documentation
│   └── openapi/             # OpenAPI schema
│       └── openapi.yaml
│
├── scripts/                  # Scripts & tools
│   ├── tests/               # Test scripts
│   │   ├── test_fe3_api.ps1
│   │   ├── test_fe3_simple.dart
│   │   ├── test_booking.ps1
│   │   ├── test_payment.ps1
│   │   ├── test_minio_upload.ps1
│   │   ├── test_upload_real_file.ps1
│   │   └── upload_presigned_test.ps1
│   ├── tools/               # Utility scripts
│   │   └── setup_minio_host.ps1
│   ├── openapi/             # OpenAPI generation
│   │   ├── generate_openapi.ps1
│   │   └── generate_openapi.sh
│   └── README.md
│
├── README.md                 # Main documentation
├── QUICK_TEST_MOBILE_WEB.md # Quick test guide
└── PROJECT_STRUCTURE.md      # This file
```

## Cách sử dụng

### Test Scripts
```powershell
# Test FE-3 API Client
.\scripts\tests\test_fe3_api.ps1

# Test khác
.\scripts\tests\test_booking.ps1
.\scripts\tests\test_payment.ps1
```

### Generate OpenAPI Client
```powershell
# Windows
.\scripts\openapi\generate_openapi.ps1

# Linux/Mac
bash scripts/openapi/generate_openapi.sh
```

### Run Apps
```bash
# Backend
cd backend
.\gradlew bootRun

# Frontend
cd apps/ev_user_mobile
flutter run
```

### Infrastructure
```powershell
cd infra
docker-compose up -d
```

## Notes

- Tất cả test scripts đã được gom vào `scripts/tests/`
- OpenAPI generation scripts ở `scripts/openapi/`
- Tool scripts ở `scripts/tools/`
- Flutter widget tests vẫn ở trong từng app (`apps/*/test/`)
- API smoke test ở `apps/shared/shared_api/test/`

