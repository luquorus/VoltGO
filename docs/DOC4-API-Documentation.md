# DOC 4 — API Documentation

---

## 4.1 API Overview

| Property | Value |
|---|---|
| **Base URL (local dev)** | `http://localhost:8080/api` |
| **Base URL (docker)** | `http://localhost:8080/api` |
| **API Documentation** | `http://localhost:8080/swagger-ui/index.html` (SpringDoc OpenAPI) |
| **Content-Type** | `application/json` |
| **Authentication** | JWT Bearer token (`Authorization: Bearer <token>`) |
| **Token Expiry** | 24 hours |
| **Public endpoints** | Auth, public station listing, public swap station info, file downloads |
| **Rate limiting** | Not implemented in current build |

---

## 4.2 Authentication Endpoints

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/auth/login` | Authenticate with email/password, returns JWT | No |
| `POST` | `/api/auth/register` | Register new EV user account | No |
| `POST` | `/api/auth/refresh` | Refresh JWT token | Yes (refresh token) |

**`POST /api/auth/login`**

Request:
```json
{
  "email": "user@example.com",
  "password": "plaintext_password"
}
```

Response (200):
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "userId": "uuid",
  "email": "user@example.com",
  "role": "EV_USER"
}
```

**`POST /api/auth/register`**

Request:
```json
{
  "email": "user@example.com",
  "password": "plaintext_password",
  "name": "Nguyen Van A",
  "phone": "0912345678"
}
```

---

## 4.3 EV User Mobile API — Station & Search

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/stations/nearby` | Get nearby stations by lat/lng/radius | Yes (EV_USER) |
| `GET` | `/api/stations/{id}` | Get station detail by ID | Yes (EV_USER) |
| `GET` | `/api/stations/{id}/availability` | Get charger unit availability | Yes (EV_USER) |
| `GET` | `/api/stations/search` | Search stations by name | Yes (EV_USER) |

**`GET /api/stations/nearby?latitude=X&longitude=Y&radius=Z`**

Response (200):
```json
[
  {
    "id": "uuid",
    "name": "Trạm sạc A",
    "address": "123 Đường ABC, Quận 1",
    "latitude": 10.7628,
    "longitude": 106.6816,
    "distanceMeters": 450,
    "services": ["AC_NORMAL", "DC_FAST"],
    "minPricePerKwh": 2500,
    "trustScore": 85.5,
    "rating": 4.2
  }
]
```

**`GET /api/stations/{id}/availability`**

Response (200):
```json
{
  "stationId": "uuid",
  "date": "2024-12-20",
  "chargerUnits": [
    {
      "unitId": "uuid",
      "name": "Unit 1",
      "powerKw": 22.0,
      "pricePerSlot": 15000,
      "slots": [
        { "startTime": "08:00", "endTime": "08:30", "status": "AVAILABLE" },
        { "startTime": "08:30", "endTime": "09:00", "status": "OCCUPIED" }
      ]
    }
  ]
}
```

---

## 4.4 EV User Mobile API — Booking

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/bookings` | Create a new booking (HOLD state, 15-min expiry) | Yes (EV_USER) |
| `POST` | `/api/bookings/{id}/confirm` | Confirm a HOLD booking (triggers payment) | Yes (EV_USER) |
| `POST` | `/api/bookings/{id}/cancel` | Cancel a booking | Yes (EV_USER) |
| `GET` | `/api/bookings/{id}` | Get booking detail | Yes (EV_USER) |
| `GET` | `/api/bookings/my` | Get current user's bookings (paginated) | Yes (EV_USER) |

**`POST /api/bookings`**

Request:
```json
{
  "stationId": "uuid",
  "chargerUnitId": "uuid",
  "startTime": "2024-12-20T10:00:00Z",
  "endTime": "2024-12-20T11:00:00Z",
  "voucherCode": "SUMMER20"
}
```

Response (201):
```json
{
  "id": "uuid",
  "status": "HOLD",
  "holdExpiresAt": "2024-12-20T09:15:00Z",
  "price": 30000,
  "stationName": "Trạm sạc A",
  "startTime": "2024-12-20T10:00:00Z",
  "endTime": "2024-12-20T11:00:00Z"
}
```

---

## 4.5 EV User Mobile API — Battery Swap

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/battery-swap/stations/nearby` | Get nearby swap stations | Yes (EV_USER) |
| `POST` | `/api/battery-swap/reservations` | Reserve a battery swap | Yes (EV_USER) |
| `POST` | `/api/battery-swap/reservations/{id}/confirm-arrival` | Confirm arrival at station | Yes (EV_USER) |
| `POST` | `/api/battery-swap/reservations/{id}/start` | Start swap (generates 6-digit code) | Yes (EV_USER) |
| `POST` | `/api/battery-swap/reservations/{id}/pay` | Pay for swap (mock) | Yes (EV_USER) |
| `POST` | `/api/battery-swap/reservations/{id}/cancel` | Cancel reservation | Yes (EV_USER) |
| `GET` | `/api/battery-swap/reservations/{id}` | Get reservation detail | Yes (EV_USER) |
| `GET` | `/api/battery-swap/reservations/my` | Get user's reservations | Yes (EV_USER) |

**`POST /api/battery-swap/reservations`**

Request:
```json
{
  "stationId": "uuid"
}
```

Response (201):
```json
{
  "id": "uuid",
  "status": "RESERVED",
  "stationName": "Trạm đổi pin B",
  "slotId": "uuid",
  "basePriceVnd": 5000,
  "expiresAt": "2024-12-20T09:30:00Z"
}
```

**`POST /api/battery-swap/reservations/{id}/start`**

Response (200):
```json
{
  "swapCode": "123456",
  "expiresAt": "2024-12-20T10:00:00Z",
  "message": "Show this code to the hardware display"
}
```

---

## 4.6 EV User Mobile API — Change Request & Issues

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/change-requests` | Submit a station change request | Yes (EV_USER) |
| `GET` | `/api/change-requests/my` | Get user's change requests | Yes (EV_USER) |
| `POST` | `/api/issues` | Report a station issue | Yes (EV_USER) |
| `GET` | `/api/issues/my` | Get user's reported issues | Yes (EV_USER) |

**`POST /api/change-requests`**

Request:
```json
{
  "stationId": "uuid",
  "changeType": "UPDATE_STATION",
  "proposedData": {
    "name": "Trạm sạc A (updated)",
    "operatingHours": "06:00-23:00"
  }
}
```

**`POST /api/issues`**

Request:
```json
{
  "stationId": "uuid",
  "category": "BROKEN_CHARGER",
  "description": "Charger unit 2 is not working"
}
```

---

## 4.7 EV User Mobile API — Loyalty

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/loyalty/profile` | Get current user's loyalty profile (points, tier) | Yes (EV_USER) |
| `GET` | `/api/loyalty/points/history` | Get points transaction history | Yes (EV_USER) |
| `GET` | `/api/loyalty/badges` | Get all badges with progress | Yes (EV_USER) |
| `GET` | `/api/loyalty/vouchers` | Get available vouchers | Yes (EV_USER) |
| `POST` | `/api/loyalty/vouchers/{id}/redeem` | Redeem points for a voucher | Yes (EV_USER) |
| `POST` | `/api/loyalty/referrals` | Create a referral link | Yes (EV_USER) |
| `POST` | `/api/loyalty/referrals/apply` | Apply referral code on registration | Yes (EV_USER) |

---

## 4.8 EV User Mobile API — AI Recommendations

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/ai/recommendations` | Get personalized recommendations | Yes (EV_USER) |
| `GET` | `/api/ai/smart-time` | Get smart charging time suggestions | Yes (EV_USER) |

**`GET /api/ai/recommendations?latitude=X&longitude=Y&batteryLevel=Z&targetLevel=W`**

Response (200):
```json
{
  "recommendations": [
    {
      "stationId": "uuid",
      "stationName": "Trạm sạc A",
      "distanceMeters": 500,
      "estimatedChargeMinutes": 45,
      "estimatedTotalMinutes": 65,
      "trustScore": 88.5,
      "matchScore": 92.0,
      "preferredSlotStart": "2024-12-20T14:00:00Z"
    }
  ]
}
```

---

## 4.9 EV User Mobile API — Profile & Misc

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/users/me` | Get current user profile | Yes (EV_USER) |
| `PUT` | `/api/users/me` | Update current user profile | Yes (EV_USER) |
| `PUT` | `/api/users/me/password` | Change password | Yes (EV_USER) |
| `PUT` | `/api/users/me/fcm-token` | Update FCM push token | Yes (EV_USER) |
| `GET` | `/api/notifications` | Get user notifications | Yes (EV_USER) |
| `PUT` | `/api/notifications/{id}/read` | Mark notification as read | Yes (EV_USER) |
| `GET` | `/api/stations/{id}/rate` | Check if user can rate a station | Yes (EV_USER) |
| `POST` | `/api/stations/{id}/rate` | Submit a station rating | Yes (EV_USER) |

---

## 4.10 Collaborator Mobile API

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/collaborator/tasks` | Get assigned verification tasks | Yes (COLLABORATOR) |
| `POST` | `/api/collaborator/tasks/{id}/checkin` | GPS check-in for a task | Yes (COLLABORATOR) |
| `POST` | `/api/collaborator/tasks/{id}/evidence` | Upload verification photo evidence | Yes (COLLABORATOR) |
| `POST` | `/api/collaborator/tasks/{id}/submit` | Submit verification review | Yes (COLLABORATOR) |
| `GET` | `/api/collaborator/contracts` | Get collaborator contracts | Yes (COLLABORATOR) |
| `GET` | `/api/collaborator/notifications` | Get collaborator notifications | Yes (COLLABORATOR) |

**`POST /api/collaborator/tasks/{id}/checkin`**

Request:
```json
{
  "latitude": 10.7628,
  "longitude": 106.6816
}
```

Response (200):
```json
{
  "checkinId": "uuid",
  "distanceMeters": 8.5,
  "withinRange": true,
  "message": "Check-in successful"
}
```

---

## 4.11 Collaborator Web API

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/collab-web/profile` | Get collaborator profile | Yes (COLLABORATOR) |
| `PUT` | `/api/collab-web/profile` | Update collaborator profile | Yes (COLLABORATOR) |
| `POST` | `/api/collab-web/contracts` | Create new contract | Yes (COLLABORATOR) |
| `GET` | `/api/collab-web/notifications` | Get notifications | Yes (COLLABORATOR) |

---

## 4.12 Admin Web API — Dashboard

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/dashboard/stats` | Overall dashboard statistics | Yes (ADMIN) |
| `GET` | `/api/admin/dashboard/booking-trends` | Booking trends over time | Yes (ADMIN) |
| `GET` | `/api/admin/dashboard/issue-stats` | Issue breakdown by category | Yes (ADMIN) |
| `GET` | `/api/admin/dashboard/collaborator-performance` | Collaborator performance summary | Yes (ADMIN) |

**`GET /api/admin/dashboard/stats`**

Response (200):
```json
{
  "totalStations": 120,
  "activeStations": 98,
  "pendingStations": 22,
  "totalBookings": 4521,
  "activeBookings": 38,
  "totalUsers": 2340,
  "newUsersThisMonth": 145,
  "totalIssues": 67,
  "openIssues": 12,
  "averageTrustScore": 78.5
}
```

---

## 4.13 Admin Web API — Station Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/stations` | List all stations (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/stations/{id}` | Get station detail | Yes (ADMIN) |
| `POST` | `/api/admin/stations` | Create a new station | Yes (ADMIN) |
| `PUT` | `/api/admin/stations/{id}` | Update station | Yes (ADMIN) |
| `DELETE` | `/api/admin/stations/{id}` | Delete station | Yes (ADMIN) |
| `GET` | `/api/admin/stations/{id}/audit-log` | Get station audit log | Yes (ADMIN) |
| `POST` | `/api/admin/stations/import` | Bulk import stations from CSV | Yes (ADMIN) |

---

## 4.14 Admin Web API — Change Requests

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/change-requests` | List all change requests | Yes (ADMIN) |
| `GET` | `/api/admin/change-requests/{id}` | Get CR detail with station snapshot | Yes (ADMIN) |
| `POST` | `/api/admin/change-requests/{id}/approve` | Approve and publish CR | Yes (ADMIN) |
| `POST` | `/api/admin/change-requests/{id}/reject` | Reject CR with reason | Yes (ADMIN) |
| `POST` | `/api/admin/change-requests/{id}/publish-direct` | Publish changes directly | Yes (ADMIN) |

**`GET /api/admin/change-requests/{id}`**

Response (200):
```json
{
  "id": "uuid",
  "stationId": "uuid",
  "changeType": "UPDATE_STATION",
  "submittedBy": "uuid",
  "status": "PENDING",
  "riskScore": 45,
  "riskLevel": "MEDIUM",
  "stationData": {
    "name": "Trạm sạc A",
    "currentPorts": [...],
    "proposedPorts": [...]
  },
  "auditLog": [
    { "action": "SUBMITTED", "timestamp": "...", "actor": "..." }
  ]
}
```

---

## 4.15 Admin Web API — Collaborator Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/collaborators` | List collaborators (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/collaborators/{id}` | Get collaborator detail | Yes (ADMIN) |
| `GET` | `/api/admin/collaborators/{id}/performance` | Get performance metrics | Yes (ADMIN) |
| `GET` | `/api/admin/collaborators/{id}/location` | Get collaborator GPS location | Yes (ADMIN) |
| `GET` | `/api/admin/collaborators/{id}/contracts` | Get collaborator contracts | Yes (ADMIN) |
| `POST` | `/api/admin/collaborators/{id}/contracts` | Create contract | Yes (ADMIN) |

---

## 4.16 Admin Web API — Verification Tasks

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/verification/tasks` | List verification tasks | Yes (ADMIN) |
| `POST` | `/api/admin/verification/tasks` | Create verification task | Yes (ADMIN) |
| `GET` | `/api/admin/verification/tasks/{id}` | Get task detail | Yes (ADMIN) |
| `POST` | `/api/admin/verification/tasks/{id}/assign` | Assign task to collaborator | Yes (ADMIN) |
| `POST` | `/api/admin/verification/tasks/{id}/review` | Submit review result | Yes (ADMIN) |

---

## 4.17 Admin Web API — Trust Score Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/trust/overview` | Get trust score overview (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/trust/stations/{id}` | Get station trust breakdown | Yes (ADMIN) |
| `POST` | `/api/admin/trust/stations/{id}/recalculate` | Manually recalculate trust | Yes (ADMIN) |
| `GET` | `/api/admin/trust/battery-swap/overview` | Get battery swap trust overview | Yes (ADMIN) |
| `GET` | `/api/admin/trust/battery-swap/stations/{id}` | Get battery swap trust breakdown | Yes (ADMIN) |

**`GET /api/admin/trust/stations/{id}`**

Response (200):
```json
{
  "stationId": "uuid",
  "stationName": "Trạm sạc A",
  "overallScore": 85.5,
  "factors": {
    "accuracyFactor": 20.0,
    "uptimeFactor": 18.5,
    "issueFactor": 17.0,
    "ratingFactor": 15.0,
    "verificationFactor": 15.0
  },
  "lastCalculatedAt": "2024-12-20T08:00:00Z"
}
```

---

## 4.18 Admin Web API — Loyalty Administration

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/loyalty/badges` | List all badge definitions | Yes (ADMIN) |
| `POST` | `/api/admin/loyalty/badges` | Create new badge | Yes (ADMIN) |
| `PUT` | `/api/admin/loyalty/badges/{id}` | Update badge | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/vouchers` | List voucher definitions | Yes (ADMIN) |
| `POST` | `/api/admin/loyalty/vouchers` | Create voucher definition | Yes (ADMIN) |
| `PUT` | `/api/admin/loyalty/vouchers/{id}` | Update voucher | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/ratings` | List ratings for moderation | Yes (ADMIN) |
| `POST` | `/api/admin/loyalty/ratings/{id}/moderate` | Approve/reject rating | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/leaderboard` | Points leaderboard | Yes (ADMIN) |

---

## 4.19 Admin Web API — Registration Requests

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/registration-requests` | List collaborator registration requests | Yes (ADMIN) |
| `GET` | `/api/admin/registration-requests/{id}` | Get registration request detail | Yes (ADMIN) |
| `POST` | `/api/admin/registration-requests/{id}/approve` | Approve and create account | Yes (ADMIN) |
| `POST` | `/api/admin/registration-requests/{id}/reject` | Reject with reason | Yes (ADMIN) |

---

## 4.20 Admin Web API — Issue Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/issues` | List all issues | Yes (ADMIN) |
| `GET` | `/api/admin/issues/{id}` | Get issue detail | Yes (ADMIN) |
| `POST` | `/api/admin/issues/{id}/respond` | Add admin response to issue | Yes (ADMIN) |
| `POST` | `/api/admin/issues/{id}/resolve` | Mark issue as resolved | Yes (ADMIN) |

---

## 4.21 Admin Web API — Battery Swap Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/battery-swap/stations` | List swap stations | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/stations` | Create swap station | Yes (ADMIN) |
| `PUT` | `/api/admin/battery-swap/stations/{id}` | Update swap station | Yes (ADMIN) |
| `DELETE` | `/api/admin/battery-swap/stations/{id}` | Delete swap station | Yes (ADMIN) |
| `GET` | `/api/admin/battery-swap/change-requests` | List swap CRs | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/change-requests/{id}/approve` | Approve swap CR | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/change-requests/{id}/reject` | Reject swap CR | Yes (ADMIN) |

---

## 4.22 File Upload API (Common)

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/files/presign-upload` | Get presigned upload URL | Yes |
| `GET` | `/api/files/{key}` | Download file (presigned view URL) | Yes |

**`POST /api/files/presign-upload`**

Request:
```json
{
  "filename": "verification_photo.jpg",
  "contentType": "image/jpeg",
  "folder": "verification"
}
```

Response (200):
```json
{
  "uploadUrl": "https://minio:9000/voltgo/verification/uuid.jpg?X-Amz-Signature=...",
  "fileKey": "verification/uuid.jpg"
}
```

---

## 4.23 WebSocket Endpoints

| Endpoint | Protocol | Description | Auth |
|---|---|---|---|
| `/ws/simulator` | WebSocket | Hardware simulator display | `deviceKey` query param |

The hardware simulator connects with `deviceKey` as a query parameter:
```
ws://localhost:8080/ws/simulator?deviceKey=station_device_key_here
```

Server pushes swap codes and slot status updates to connected simulator clients.

---

## 4.24 Error Response Format

All error responses follow this structure:

```json
{
  "timestamp": "2024-12-20T10:00:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Charger unit is not available for the selected time slot",
  "path": "/api/bookings"
}
```

Common HTTP status codes used:

| Code | Meaning |
|---|---|
| 200 | OK |
| 201 | Created |
| 400 | Bad Request (validation error) |
| 401 | Unauthorized (missing/invalid token) |
| 403 | Forbidden (insufficient role) |
| 404 | Not Found |
| 409 | Conflict (e.g., double-booking, slot already taken) |
| 500 | Internal Server Error |
