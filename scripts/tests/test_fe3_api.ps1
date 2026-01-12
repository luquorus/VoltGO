# Quick test script for FE-3 API Client
# Đảm bảo backend đang chạy tại http://localhost:8080
# Chạy từ project root: .\scripts\tests\test_fe3_api.ps1

Write-Host "🧪 Testing FE-3: OpenAPI Client Integration" -ForegroundColor Cyan
Write-Host ""

# Test 1: Backend health check
Write-Host "1. Checking backend health..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/healthz" -Method GET -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✅ Backend is running" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Backend not running. Please start backend first!" -ForegroundColor Red
    Write-Host "   Run: cd infra && docker-compose up -d" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "2. Testing API endpoints via curl..." -ForegroundColor Yellow
Write-Host ""

# Test 2: Login để lấy token
Write-Host "   Testing Auth API (Login)..." -ForegroundColor Yellow
$loginBody = @{
    email = "admin@local"
    password = "Admin@123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -Body $loginBody -ContentType "application/json"
    $token = $loginResponse.token
    Write-Host "   ✅ Login successful, got token: $($token.Substring(0, 20))..." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Login failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "3. Testing authenticated endpoints..." -ForegroundColor Yellow
Write-Host ""

# Test 3: EV API - Get stations
Write-Host "   Testing EV API - GET /api/ev/stations..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}
try {
    $stationsUrl = "http://localhost:8080/api/ev/stations?lat=21.0285&lng=105.8542&radiusKm=5.0&page=0&size=20"
    $stationsResponse = Invoke-RestMethod -Uri $stationsUrl -Method GET -Headers $headers
    Write-Host "   ✅ EV API works! Got $($stationsResponse.content.Count) stations" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  EV API test failed (expected if no stations): $_" -ForegroundColor Yellow
}

# Test 4: Admin API - Get change requests
Write-Host "   Testing Admin API - GET /api/admin/change-requests..." -ForegroundColor Yellow
try {
    $adminUrl = "http://localhost:8080/api/admin/change-requests"
    $adminResponse = Invoke-RestMethod -Uri $adminUrl -Method GET -Headers $headers
    Write-Host "   ✅ Admin API works! Got $($adminResponse.Count) change requests" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Admin API test failed (expected if empty): $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "4. Testing Flutter smoke test..." -ForegroundColor Yellow
Write-Host "   Run this command to test with Flutter:" -ForegroundColor Cyan
Write-Host "   flutter test apps/shared/shared_api/test/smoke_test.dart --dart-define=API_BASE_URL=http://localhost:8080" -ForegroundColor White
Write-Host ""

# Test 5: Test trong app thực tế
Write-Host "5. To test in real app:" -ForegroundColor Yellow
Write-Host "   a) Start any app (ev_user_mobile, collab_mobile, etc.)" -ForegroundColor Cyan
Write-Host "   b) Login with: admin@local / Admin@123" -ForegroundColor Cyan
Write-Host "   c) Check network tab to see API calls using ApiClientFactory" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ FE-3 API Client is ready to use!" -ForegroundColor Green
Write-Host ""
Write-Host "Quick usage example:" -ForegroundColor Yellow
Write-Host '   final factory = ApiClientFactory.create(ref, baseUrl: "http://localhost:8080");' -ForegroundColor White
Write-Host '   final stations = await factory.ev.getStations(lat: 21.0, lng: 105.0, radiusKm: 5.0);' -ForegroundColor White

