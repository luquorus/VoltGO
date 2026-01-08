# Quick Start Guide - Backend

## Bước 1: Cài đặt Java 17

Kiểm tra Java:
```powershell
java -version
```

Nếu chưa có, tải từ: https://adoptium.net/

## Bước 2: Khởi động Infrastructure

```powershell
cd infra
docker-compose up -d
```

Admin account: 
Email: admin@local
Password: Admin@123

## Bước 3: Tạo Gradle Wrapper (nếu chưa có)

```powershell
cd backend
gradle wrapper --gradle-version 8.5
```

## Bước 4: Build và Chạy

```powershell
cd backend
.\gradlew clean build
.\gradlew bootRun
```

## Bước 5: Test nhanh

1. **Health Check**: http://localhost:8080/healthz
2. **Swagger UI**: http://localhost:8080/swagger-ui.html
3. **API Docs**: http://localhost:8080/api-docs
4. **Actuator**: http://localhost:8080/actuator/health

Xem `README.md` để biết chi tiết các test cases.

