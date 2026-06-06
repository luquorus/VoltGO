@echo off
echo === Test 1: Admin Login ===
curl.exe -s -X POST http://localhost:8080/auth/login -H "Content-Type: application/json" -d "{\"email\":\"admin@local\",\"password\":\"admin123\"}"
echo.
echo === Test 2: Submit Registration Request ===
curl.exe -s -X POST http://localhost:8080/auth/register -H "Content-Type: application/json" -d "{\"email\":\"test123@test.com\",\"password\":\"password123\",\"role\":\"COLLABORATOR\"}"
echo.
