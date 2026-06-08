# Insert test notifications for test@1 user (EV_USER)
# Covers all notification types and categories

$USER_ID = "27873fe9-7e89-4309-9188-257a9bb2e26c"
$BASE_URL = "http://localhost:8080"

function Invoke-Psql {
    param([string]$Query)
    $result = docker exec voltgo-postgres psql -U voltgo_user -d voltgo -c $Query 2>&1
    return $result
}

# ============================================================
# LOGIN
# ============================================================
Write-Host "=== [1] LOGGING IN AS test@1 ===" -ForegroundColor Cyan

$loginBody = @{ email = "test@1"; password = "Admin@123" } | ConvertTo-Json
$loginResp = Invoke-RestMethod -Uri "$BASE_URL/auth/login" -Method POST -ContentType "application/json" -Body $loginBody -ErrorAction Stop

$token = $loginResp.token
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}
Write-Host "SUCCESS" -ForegroundColor Green

# ============================================================
# TRY CREATING BOOKINGS (for reference IDs)
# ============================================================
Write-Host "`n=== [2] CREATING BOOKINGS ===" -ForegroundColor Cyan

$bookingStart1 = (Get-Date).AddHours(2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$bookingEnd1 = (Get-Date).AddHours(4).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$booking1Id = "00000000-0000-0000-0000-000000000001"
$booking2Id = "00000000-0000-0000-0000-000000000002"

try {
    $body = @{
        stationId = "8d869123-1b11-4ea6-b308-e5a5112726c4"
        chargerUnitId = "e62df9b3-63f5-4398-bd19-ce8921e83122"
        startTime = $bookingStart1
        endTime = $bookingEnd1
    } | ConvertTo-Json
    $r = Invoke-RestMethod -Uri "$BASE_URL/api/ev/bookings" -Method POST -Headers $headers -Body $body
    $booking1Id = $r.id
    Write-Host "Booking 1: $booking1Id ($($r.status))" -ForegroundColor Green
} catch {
    Write-Host "Booking 1 failed ($($_.Exception.Response.StatusCode.value__)) - using fallback ID" -ForegroundColor Yellow
}

Start-Sleep -Seconds 1

$bookingStart2 = (Get-Date).AddHours(6).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$bookingEnd2 = (Get-Date).AddHours(8).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
try {
    $body = @{
        stationId = "8d869123-1b11-4ea6-b308-e5a5112726c4"
        chargerUnitId = "aed1a997-0e6d-4518-b363-7c183c0cb10f"
        startTime = $bookingStart2
        endTime = $bookingEnd2
    } | ConvertTo-Json
    $r = Invoke-RestMethod -Uri "$BASE_URL/api/ev/bookings" -Method POST -Headers $headers -Body $body
    $booking2Id = $r.id
    Write-Host "Booking 2: $booking2Id ($($r.status))" -ForegroundColor Green
} catch {
    Write-Host "Booking 2 failed - using fallback ID" -ForegroundColor Yellow
}

# ============================================================
# TRY BATTERY SWAP RESERVATION
# ============================================================
Write-Host "`n=== [3] CREATING BATTERY SWAP RESERVATION ===" -ForegroundColor Cyan

$resId = "00000000-0000-0000-0000-000000000003"
$arrivalTime = (Get-Date).AddHours(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
try {
    $body = @{
        stationId = "f1000000-0000-0000-0000-000000000017"
        expectedArrivalAt = $arrivalTime
        requestedBatteryPercent = 80
        batteryCapacityKwh = 50
    } | ConvertTo-Json
    $r = Invoke-RestMethod -Uri "$BASE_URL/api/ev/battery-swap/reservations" -Method POST -Headers $headers -Body $body
    $resId = $r.id
    Write-Host "Reservation: $resId ($($r.status))" -ForegroundColor Green
} catch {
    Write-Host "Reservation failed ($($_.Exception.Response.StatusCode.value__)) - using fallback ID" -ForegroundColor Yellow
}

# ============================================================
# INSERT ALL NOTIFICATION TYPES
# ============================================================
Write-Host "`n=== [4] INSERTING NOTIFICATIONS INTO DATABASE ===" -ForegroundColor Cyan

$uid = $USER_ID

# --- BOOKING category ---
Write-Host "Inserting BOOKING category..." -ForegroundColor Gray

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'BOOKING_CONFIRMED', 'BOOKING', 'Booking Confirmed',
'Your charging session has been confirmed. Please arrive on time.',
'{\"stationName\": \"EV Hub 1\", \"startTime\": \"2026-06-06T14:00:00Z\"}',
true, '$booking1Id'::uuid, 'BOOKING', NOW() - INTERVAL '2 days');
"@ | Out-Null
Write-Host "  BOOKING_CONFIRMED (read)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'BOOKING_REMINDER', 'BOOKING', 'Booking in 30 Minutes',
'Your charging session starts in 30 minutes. Please head to the station now.',
'{\"stationName\": \"EV Hub 1\", \"startTime\": \"2026-06-06T14:00:00Z\"}',
false, '$booking1Id'::uuid, 'BOOKING', NOW() - INTERVAL '1 hour');
"@ | Out-Null
Write-Host "  BOOKING_REMINDER (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'BOOKING_CANCELLED', 'BOOKING', 'Booking Cancelled',
'Your booking has been cancelled. Refund has been processed.',
'{\"reason\": \"User requested cancellation\"}',
false, '$booking1Id'::uuid, 'BOOKING', NOW() - INTERVAL '30 minutes');
"@ | Out-Null
Write-Host "  BOOKING_CANCELLED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'PAYMENT_SUCCESS', 'BOOKING', 'Payment Successful',
'Payment of 60,000 VND processed successfully. Charging session complete.',
'{\"amount\": 60000, \"currency\": \"VND\"}',
false, '$booking1Id'::uuid, 'BOOKING', NOW() - INTERVAL '15 minutes');
"@ | Out-Null
Write-Host "  PAYMENT_SUCCESS (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'PAYMENT_FAILED', 'BOOKING', 'Payment Failed',
'Payment could not be processed. Please check your payment method and try again.',
'{\"amount\": 60000, \"failureReason\": \"Insufficient funds\"}',
false, '$booking1Id'::uuid, 'BOOKING', NOW() - INTERVAL '8 minutes');
"@ | Out-Null
Write-Host "  PAYMENT_FAILED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'BOOKING_EXPIRED', 'BOOKING', 'Booking Expired',
'Your booking has expired because you did not confirm within the hold period.',
'{\"reason\": \"Hold period expired\"}',
false, '$booking1Id'::uuid, 'BOOKING', NOW() - INTERVAL '5 minutes');
"@ | Out-Null
Write-Host "  BOOKING_EXPIRED (unread)" -ForegroundColor Green

# --- BATTERY_SWAP category ---
Write-Host "Inserting BATTERY_SWAP category..." -ForegroundColor Gray

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SWAP_RESERVED', 'BATTERY_SWAP', 'Swap Reserved',
'Your battery swap reservation is confirmed. Please arrive by scheduled time.',
'{\"stationId\": \"f1000000-0000-0000-0000-000000000017\"}',
true, '$resId'::uuid, 'BATTERY_SWAP_RESERVATION', NOW() - INTERVAL '3 hours');
"@ | Out-Null
Write-Host "  SWAP_RESERVED (read)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SWAP_ARRIVED', 'BATTERY_SWAP', 'Arrival Confirmed',
'Your arrival has been confirmed. Please wait at the designated area. Swap will begin shortly.',
'{\"stationId\": \"f1000000-0000-0000-0000-000000000017\"}',
false, '$resId'::uuid, 'BATTERY_SWAP_RESERVATION', NOW() - INTERVAL '1 hour');
"@ | Out-Null
Write-Host "  SWAP_ARRIVED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SWAP_CODE_GENERATED', 'BATTERY_SWAP', 'Swap Code Generated',
'Your swap code is: 123456. Show this to station staff to begin battery swap.',
'{\"swapCode\": \"123456\"}',
false, '$resId'::uuid, 'BATTERY_SWAP_RESERVATION', NOW() - INTERVAL '30 minutes');
"@ | Out-Null
Write-Host "  SWAP_CODE_GENERATED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SWAP_COMPLETED', 'BATTERY_SWAP', 'Swap Complete',
'Battery swap completed successfully. Your new battery is at 95%. Have a safe trip!',
'{\"newBatteryPercent\": 95, \"swapDuration\": 300}',
false, '$resId'::uuid, 'BATTERY_SWAP_RESERVATION', NOW() - INTERVAL '10 minutes');
"@ | Out-Null
Write-Host "  SWAP_COMPLETED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SWAP_REMINDER', 'BATTERY_SWAP', 'Swap Reminder - 30 Min',
'Battery swap reservation in 30 minutes. Please head to the station now.',
'{\"stationId\": \"f1000000-0000-0000-0000-000000000017\"}',
false, '$resId'::uuid, 'BATTERY_SWAP_RESERVATION', NOW() - INTERVAL '25 minutes');
"@ | Out-Null
Write-Host "  SWAP_REMINDER (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SWAP_EXPIRED', 'BATTERY_SWAP', 'Swap Reservation Expired',
'Your battery swap reservation has expired. Please book again.',
'{\"reason\": \"No arrival within grace period\"}',
false, '$resId'::uuid, 'BATTERY_SWAP_RESERVATION', NOW() - INTERVAL '5 minutes');
"@ | Out-Null
Write-Host "  SWAP_EXPIRED (unread)" -ForegroundColor Green

# --- STATION category ---
Write-Host "Inserting STATION category..." -ForegroundColor Gray

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'ISSUE_REPORTED', 'STATION', 'Issue Report Received',
'We received your issue report. Our team is reviewing it.',
'{\"issueType\": \"BROKEN_CHARGER\"}',
true, '8d869123-1b11-4ea6-b308-e5a5112726c4'::uuid, 'STATION', NOW() - INTERVAL '1 day');
"@ | Out-Null
Write-Host "  ISSUE_REPORTED (read)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'ISSUE_ACKNOWLEDGED', 'STATION', 'Issue Being Addressed',
'Your issue report has been acknowledged. A technician has been assigned.',
'{\"estimatedFixTime\": \"2 hours\"}',
false, '8d869123-1b11-4ea6-b308-e5a5112726c4'::uuid, 'STATION', NOW() - INTERVAL '3 hours');
"@ | Out-Null
Write-Host "  ISSUE_ACKNOWLEDGED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'ISSUE_RESOLVED', 'STATION', 'Issue Resolved',
'The issue you reported has been fixed. The charger is now operational.',
'{}',
false, '8d869123-1b11-4ea6-b308-e5a5112726c4'::uuid, 'STATION', NOW() - INTERVAL '1 hour');
"@ | Out-Null
Write-Host "  ISSUE_RESOLVED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'CR_SUBMITTED', 'STATION', 'Change Request Submitted',
'Your change request has been submitted for review. You will be notified once processed.',
'{\"changeRequestType\": \"CREATE_STATION\"}',
false, '00000000-0000-0000-0000-000000000010'::uuid, 'CHANGE_REQUEST', NOW() - INTERVAL '2 hours');
"@ | Out-Null
Write-Host "  CR_SUBMITTED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'CR_APPROVED', 'STATION', 'Change Request Approved',
'Your change request has been approved. It will be published soon.',
'{\"changeRequestType\": \"UPDATE_STATION\"}',
false, '00000000-0000-0000-0000-000000000011'::uuid, 'CHANGE_REQUEST', NOW() - INTERVAL '45 minutes');
"@ | Out-Null
Write-Host "  CR_APPROVED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'CR_REJECTED', 'STATION', 'Change Request Rejected',
'Your change request has been rejected. Reason: Missing required safety documentation.',
'{\"rejectionReason\": \"Missing safety documentation\"}',
false, '00000000-0000-0000-0000-000000000012'::uuid, 'CHANGE_REQUEST', NOW() - INTERVAL '20 minutes');
"@ | Out-Null
Write-Host "  CR_REJECTED (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'CR_PUBLISHED', 'STATION', 'Station Now Live!',
'Your station has been published and is now visible to all EV users. Welcome to VoltGo!',
'{\"stationName\": \"My New Station\"}',
false, '00000000-0000-0000-0000-000000000013'::uuid, 'STATION', NOW() - INTERVAL '10 minutes');
"@ | Out-Null
Write-Host "  CR_PUBLISHED (unread)" -ForegroundColor Green

# --- SYSTEM category ---
Write-Host "Inserting SYSTEM category..." -ForegroundColor Gray

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SYSTEM_ANNOUNCEMENT', 'SYSTEM', 'VoltGo Update v2.1 Available',
'New VoltGo version available with improved battery swap tracking and faster payments.',
'{\"version\": \"2.1.0\", \"releaseNotes\": \"Improved tracking\"}',
false, NULL, NULL, NOW() - INTERVAL '1 day');
"@ | Out-Null
Write-Host "  SYSTEM_ANNOUNCEMENT v2.1 (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SYSTEM_ANNOUNCEMENT', 'SYSTEM', 'Scheduled Maintenance - June 10',
'VoltGo will undergo maintenance on June 10 from 02:00-04:00 ICT.',
'{\"maintenanceWindow\": \"2026-06-10T02:00:00Z\"}',
false, NULL, NULL, NOW() - INTERVAL '3 hours');
"@ | Out-Null
Write-Host "  SYSTEM_ANNOUNCEMENT maintenance (unread)" -ForegroundColor Green

Invoke-Psql @"
INSERT INTO ev_user_notification (id, recipient_id, type, category, title, body, data_json, is_read, reference_id, reference_type, created_at)
VALUES (gen_random_uuid(), '$uid'::uuid, 'SYSTEM_ANNOUNCEMENT', 'SYSTEM', 'New Station Near You',
'3 new charging stations have been added near your location in Hanoi.',
'{\"newStationCount\": 3, \"area\": \"Hanoi\"}',
false, NULL, NULL, NOW() - INTERVAL '6 hours');
"@ | Out-Null
Write-Host "  SYSTEM_ANNOUNCEMENT new stations (unread)" -ForegroundColor Green

# ============================================================
# VERIFY via API
# ============================================================
Write-Host "`n=== [5] VERIFYING VIA API ===" -ForegroundColor Cyan

Start-Sleep -Seconds 1

try {
    $all = Invoke-RestMethod -Uri "$BASE_URL/api/ev/notifications?page=0&size=50" -Method GET -Headers $headers
    $unreadCount = Invoke-RestMethod -Uri "$BASE_URL/api/ev/notifications/unread-count" -Method GET -Headers $headers

    Write-Host "`nTotal: $($all.totalElements) | Unread: $unreadCount" -ForegroundColor Cyan

    Write-Host "`n[UNREAD]:" -ForegroundColor Yellow
    $unread = Invoke-RestMethod -Uri "$BASE_URL/api/ev/notifications?page=0&size=50&isRead=false" -Method GET -Headers $headers
    $unread.notifications | ForEach-Object { Write-Host "  [$($_.category)] [$($_.type)] $($_.title)" }

    Write-Host "`n[READ]:" -ForegroundColor Gray
    $read = Invoke-RestMethod -Uri "$BASE_URL/api/ev/notifications?page=0&size=50&isRead=true" -Method GET -Headers $headers
    $read.notifications | ForEach-Object { Write-Host "  [$($_.category)] [$($_.type)] $($_.title)" }

    # Test filter by category
    Write-Host "`n[BOOKING category only:]" -ForegroundColor Magenta
    $booking = Invoke-RestMethod -Uri "$BASE_URL/api/ev/notifications?page=0&size=50&category=BOOKING" -Method GET -Headers $headers
    Write-Host "  Total: $($booking.totalElements)" -ForegroundColor Magenta

    Write-Host "`n[BATTERY_SWAP category only:]" -ForegroundColor Magenta
    $bs = Invoke-RestMethod -Uri "$BASE_URL/api/ev/notifications?page=0&size=50&category=BATTERY_SWAP" -Method GET -Headers $headers
    Write-Host "  Total: $($bs.totalElements)" -ForegroundColor Magenta

    Write-Host "`n[STATION category only:]" -ForegroundColor Magenta
    $station = Invoke-RestMethod -Uri "$BASE_URL/api/ev/notifications?page=0&size=50&category=STATION" -Method GET -Headers $headers
    Write-Host "  Total: $($station.totalElements)" -ForegroundColor Magenta

    Write-Host "`n[SYSTEM category only:]" -ForegroundColor Magenta
    $sys = Invoke-RestMethod -Uri "$BASE_URL/api/ev/notifications?page=0&size=50&category=SYSTEM" -Method GET -Headers $headers
    Write-Host "  Total: $($sys.totalElements)" -ForegroundColor Magenta

} catch {
    Write-Host "Verification failed: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "$($_.ErrorDetails.Message)" -ForegroundColor Red
}

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
