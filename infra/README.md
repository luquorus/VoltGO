# Infrastructure - Docker Compose

Docker Compose configuration cho VoltGo project.

## Services

### Backend Services
- **postgres**: PostgreSQL 16 với PostGIS (port 5432)
- **redis**: Redis 7 (port 6379)
- **minio**: MinIO Object Storage (ports 9000, 9001)
- **backend**: Spring Boot API (port 8080)

### Frontend Services
- **frontend-ev-user**: EV User Mobile Web App (port 3001)
- **frontend-admin**: Admin Web Portal (port 3002)
- **frontend-collab-web**: Collaborator Web App (port 3003)
- **frontend-collab-mobile**: Collaborator Mobile Web App (port 3004)

## Quick Start

1. **Start all services:**
   ```powershell
   cd infra
   docker-compose up -d
   ```

2. **Access applications:**
   
   **Frontend Apps:**
   - EV User Mobile: http://localhost:3001
   - Admin Web Portal: http://localhost:3002
   - Collaborator Web: http://localhost:3003
   - Collaborator Mobile: http://localhost:3004
   
   **Backend:**
   - API: http://localhost:8080
   - Swagger UI: http://localhost:8080/swagger-ui.html
   
   **Quick open all apps in Edge:**
   ```powershell
   .\scripts\tools\open_frontend_apps.ps1
   ```

3. **View logs:**
   ```powershell
   docker-compose logs -f [service-name]
   ```

4. **Stop all services:**
   ```powershell
   docker-compose down
   ```

## Development Mode (Hot Reload)

Để có hot reload khi sửa code:

```powershell
# Chạy với development mode
cd infra
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

**Lưu ý:**
- Development mode mount source code vào container
- Sửa code → tự động reload (hot reload)
- Chậm hơn production build
- Chỉ dùng khi đang develop

## Production Mode (Không có Hot Reload)

```powershell
# Production build (hiện tại)
cd infra
docker-compose up -d
```

**Lưu ý:**
- Build production, không có hot reload
- Nhanh hơn, tối ưu hơn
- Cần rebuild khi sửa code: `docker-compose build frontend-admin && docker-compose up -d frontend-admin`

## Testing với Edge Browser

Các frontend apps đã được build và serve qua nginx. Bạn có thể:

1. **Mở Edge browser** và truy cập:
   - http://localhost:3001 (EV User)
   - http://localhost:3002 (Admin)
   - http://localhost:3003 (Collaborator Web)
   - http://localhost:3004 (Collaborator Mobile)

2. **Hoặc dùng script tự động:**
   ```powershell
   .\scripts\tools\open_frontend_apps.ps1
   ```

## Rebuild Frontend

Nếu code thay đổi, rebuild frontend:
```powershell
docker-compose build frontend-ev-user
docker-compose up -d frontend-ev-user
```

Hoặc rebuild tất cả:
```powershell
docker-compose build
docker-compose up -d
```

## Environment Variables

Tạo file `.env` từ `.env.example`:
```powershell
copy .env.example .env
```

Các biến môi trường chính:
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`
- `MINIO_BUCKET`
