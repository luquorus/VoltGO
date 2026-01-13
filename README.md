# VoltGo - Hệ thống Quản lý Trạm Sạc Xe Điện

## Tổng quan

VoltGo là hệ thống quản lý trạm sạc xe điện với các tính năng:
- Quản lý trạm sạc với versioning và workflow phê duyệt
- Risk score và Trust score có thể giải thích
- Xác minh thực địa bởi Collaborator (GPS check-in)
- Booking theo slot + payment mô phỏng
- 4 ứng dụng: EV User Mobile, Collaborator Mobile/Web, Admin Web Portal

## Kiến trúc

- **Backend**: Java Spring Boot với Clean/Hexagonal architecture
- **Frontend**: Flutter (Mobile + Web)
- **Database**: PostgreSQL 16 với PostGIS extension
- **Cache**: Redis 7

## Yêu cầu hệ thống

- Docker và Docker Compose
- Java 17+ (cho backend)
- Flutter SDK (cho frontend)

## Cài đặt và Chạy

### Cách 1: Chạy tất cả bằng Docker (Khuyến nghị - Đơn giản nhất)

**Chỉ cần Docker, không cần cài Java/Gradle!**

1. **Cài đặt Docker Desktop** (nếu chưa có):
   - Windows: Tải từ [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop)
   - Đảm bảo Docker Desktop đã chạy

2. **Tạo file `.env`**:
   ```powershell
   cd infra
   copy .env.example .env
   ```

3. **Chạy tất cả services (bao gồm backend)**:
   ```powershell
   cd infra
   docker-compose up -d
   ```

   Lệnh này sẽ tự động:
   - Build backend Spring Boot application
   - Khởi động PostgreSQL 16 với PostGIS (port 5432)
   - Khởi động Redis 7 (port 6379)
   - Khởi động Backend API (port 8080)

4. **Kiểm tra backend đã chạy**:
   - Mở trình duyệt: http://localhost:8080/healthz
   - Swagger UI: http://localhost:8080/swagger-ui.html

**Xong!** Bạn không cần cài Java hay Gradle. Tất cả đã chạy trong Docker.

---

### Cách 2: Chạy riêng (Cho development)

Nếu bạn muốn chạy backend trên máy để dễ debug/hot reload:

1. **Chỉ chạy infrastructure**:
   ```powershell
   cd infra
   docker-compose up -d postgres redis
   ```

2. **Chạy backend trên máy** (cần Java 17+ và Gradle):
   - Xem hướng dẫn chi tiết trong `backend/README.md`

### Kiểm tra các services (Cách 1 - Docker)

#### Kiểm tra PostgreSQL và PostGIS

1. **Kiểm tra container đang chạy**:
   ```bash
   docker ps
   ```

2. **Kết nối vào PostgreSQL**:
   ```bash
   docker exec -it voltgo-postgres psql -U voltgo_user -d voltgo
   ```

3. **Kiểm tra PostGIS extension**:
   ```sql
   -- Kiểm tra extension có sẵn
   SELECT * FROM pg_available_extensions WHERE name LIKE 'postgis%';
   
   -- Tạo extension (khi cần)
   CREATE EXTENSION IF NOT EXISTS postgis;
   
   -- Kiểm tra version
   SELECT PostGIS_version();
   
   -- Thoát
   \q
   ```

#### Kiểm tra Redis

```bash
docker exec -it voltgo-redis redis-cli ping
```

Kết quả mong đợi: `PONG`

### Truy cập Swagger

Sau khi tất cả services đã khởi động, truy cập:

- **Swagger UI**: http://localhost:8080/swagger-ui.html
- **API Docs JSON**: http://localhost:8080/api-docs
- **Health Check**: http://localhost:8080/healthz
- **Actuator Health**: http://localhost:8080/actuator/health

### Dừng services

```bash
cd infra
docker-compose down
```

### Dừng và xóa dữ liệu (volumes)

```bash
cd infra
docker-compose down -v
```

**Cảnh báo**: Lệnh này sẽ xóa tất cả dữ liệu đã lưu trong volumes.

## Cấu trúc dự án

```
VoltGo/
├── infra/              # Docker Compose và cấu hình infrastructure
│   ├── docker-compose.yml
│   └── .env.example
├── backend/            # Spring Boot backend (sẽ tạo)
├── frontend/           # Flutter applications (sẽ tạo)
└── README.md
```

## Thông tin kết nối mặc định

| Service | Host | Port | Credentials |
|---------|------|------|-------------|
| **Backend API** | localhost | 8080 | - |
| PostgreSQL | localhost | 5432 | User: `voltgo_user`, Password: `voltgo_pass`, DB: `voltgo` |
| Redis | localhost | 6379 | - |

## Troubleshooting

### PostgreSQL không khởi động được
- Kiểm tra port 5432 có bị chiếm không: `netstat -ano | findstr :5432`
- Xem logs: `docker logs voltgo-postgres`

### Redis không kết nối được
- Kiểm tra port 6379 có bị chiếm không
- Xem logs: `docker logs voltgo-redis`

### Backend không khởi động được
- Kiểm tra port 8080 có bị chiếm không: `netstat -ano | findstr :8080`
- Xem logs: `docker logs voltgo-backend`
- Kiểm tra backend đã build thành công: `docker-compose build backend`
- Đảm bảo các services khác (postgres, redis) đã healthy trước khi backend start

## Tài liệu tham khảo

- [PostGIS Documentation](https://postgis.net/documentation/)
- [Redis Documentation](https://redis.io/docs/)

