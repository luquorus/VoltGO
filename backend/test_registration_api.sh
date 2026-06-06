#!/bin/bash
# Test script for Collaborator Self-Registration API
# Run this after starting the backend server

BASE_URL="http://localhost:8080"
ADMIN_TOKEN="" # Will be set after admin login

echo "======================================"
echo "Testing Collaborator Registration APIs"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function for API calls
call_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local auth=$4
    
    if [ -n "$auth" ]; then
        curl -s -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $auth" \
            -d "$data"
    else
        curl -s -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi
}

print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ Success${NC}"
    else
        echo -e "${RED}✗ Failed (exit code: $1)${NC}"
    fi
}

echo "----------------------------------------"
echo "1. Testing Submit Registration Request"
echo "----------------------------------------"

REGISTER_DATA='{
    "email": "test.collaborator@example.com",
    "password": "Password123",
    "fullName": "Nguyen Van Test",
    "phone": "0912345678",
    "dateOfBirth": "2000-01-01",
    "address": "123 Nguyen Trai, Ha Noi",
    "idCardNumber": "001234567890",
    "bankAccountNumber": "1234567890",
    "bankName": "Vietcombank",
    "contractAgreedAt": "2026-06-05T00:00:00Z"
}'

echo "Submitting registration request..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/public/registration-requests" \
    -H "Content-Type: application/json" \
    -d "$REGISTER_DATA")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"

if [ "$HTTP_CODE" == "201" ]; then
    REQUEST_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "${GREEN}✓ Registration request created successfully${NC}"
    echo "Request ID: $REQUEST_ID"
else
    echo -e "${RED}✗ Failed to create registration request${NC}"
fi

echo ""
echo "----------------------------------------"
echo "2. Testing Get Registration Request Status (Public)"
echo "----------------------------------------"

if [ -n "$REQUEST_ID" ]; then
    echo "Getting request status for ID: $REQUEST_ID"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/public/registration-requests/$REQUEST_ID")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo "HTTP Status: $HTTP_CODE"
    echo "Response: $BODY"
    print_result $((HTTP_CODE == 200 ? 0 : 1))
else
    echo "Skipped - no REQUEST_ID"
fi

echo ""
echo "----------------------------------------"
echo "3. Testing DOB Validation (Under 18)"
echo "----------------------------------------"

UNDERAGE_DATA='{
    "email": "underage@example.com",
    "password": "Password123",
    "fullName": "Too Young",
    "phone": "0912345678",
    "dateOfBirth": "2015-01-01",
    "address": "123 Test, Ha Noi",
    "idCardNumber": "001234567890",
    "bankAccountNumber": "1234567890",
    "bankName": "Vietcombank",
    "contractAgreedAt": "2026-06-05T00:00:00Z"
}'

echo "Submitting underage registration..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/public/registration-requests" \
    -H "Content-Type: application/json" \
    -d "$UNDERAGE_DATA")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"

if [[ "$BODY" == *"18 years old"* ]] || [[ "$BODY" == *"at least 18"* ]]; then
    echo -e "${GREEN}✓ Age validation working correctly${NC}"
else
    echo -e "${YELLOW}⚠ Age validation response may need checking${NC}"
fi

echo ""
echo "======================================"
echo "Note: Admin endpoints require authentication"
echo "To test admin endpoints:"
echo "1. Login as admin first"
echo "2. Set ADMIN_TOKEN variable"
echo "3. Run admin-specific tests"
echo "======================================"

echo ""
echo "----------------------------------------"
echo "Sample Admin API Tests (after login)"
echo "----------------------------------------"

echo "GET /api/admin/registration-requests?status=PENDING&page=0&size=20"
echo "GET /api/admin/registration-requests/{id}"
echo "POST /api/admin/registration-requests/{id}/approve"
echo "     Body: {\"region\": \"Hanoi\", \"note\": \"Approved by test\"}"
echo "POST /api/admin/registration-requests/{id}/reject"
echo "     Body: {\"reason\": \"Missing documents\"}"
echo "GET /api/admin/registration-requests/pending-count"

echo ""
echo "======================================"
echo "Test completed"
echo "======================================"
