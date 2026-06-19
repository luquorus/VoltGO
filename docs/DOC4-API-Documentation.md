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

### API Client Factory

All typed API clients are defined in `apps/shared/shared_api/lib/src/api_client_factory.dart`:

```
ApiClientFactory
├── auth        → /auth/**
├── ev          → /api/ev/**
├── collabMobile → /api/collab/mobile/**
├── collabWeb   → /api/collab/web/**
├── admin       → /api/admin/**
└── public      → /api/public/**
```

---

## 4.2 Authentication Endpoints

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/auth/login` | Authenticate with email/password, returns JWT | No |
| `POST` | `/auth/register` | Register new EV user account | No |

**`POST /auth/login`**

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

**`POST /auth/register`**

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

## 4.3 Public API Endpoints

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/public/battery-swap/stations` | Get all battery swap stations | No |
| `GET` | `/api/public/battery-swap/stations/{stationId}` | Get swap station detail | No |
| `GET` | `/api/public/battery-swap/stations/{stationId}/piles` | Get station piles | No |
| `GET` | `/api/public/battery-swap/stations/{stationId}/active-code` | Get active swap code | No |
| `POST` | `/api/public/registration-requests` | Submit collaborator registration | No |
| `GET` | `/api/public/registration-requests/{id}` | Get registration status | No |

---

## 4.4 EV User Mobile API — Stations

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/ev/stations` | Get nearby stations by lat/lng/radius | Yes (EV_USER) |
| `GET` | `/api/ev/stations/{stationId}` | Get station detail | Yes (EV_USER) |
| `GET` | `/api/ev/stations/{stationId}/charger-units` | Get charger units | Yes (EV_USER) |
| `GET` | `/api/ev/stations/{stationId}/availability` | Get availability by date | Yes (EV_USER) |
| `GET` | `/api/ev/stations/search/by-name` | Search stations by name | Yes (EV_USER) |
| `POST` | `/api/ev/stations/{stationId}/issues` | Report station issue | Yes (EV_USER) |

**`GET /api/ev/stations?lat=X&lng=Y&radiusKm=Z`**

Query params: `lat`, `lng`, `radiusKm`, `minPowerKw`, `hasAC`, `page`, `size`

Response (200):
```json
{
  "content": [
    {
      "id": "uuid",
      "name": "Trạm sạc A",
      "address": "123 Đường ABC, Quận 1",
      "latitude": 10.7628,
      "longitude": 106.6816,
      "services": ["AC_NORMAL", "DC_FAST"],
      "trustScore": 85.5
    }
  ],
  "totalElements": 100,
  "totalPages": 5
}
```

**`GET /api/ev/stations/{stationId}/availability`**

Query params: `date` (YYYY-MM-DD), `tz`, `slotMinutes`, `powerType`, `minPowerKw`

---

## 4.5 EV User Mobile API — Booking

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/ev/bookings` | Create booking (HOLD state) | Yes (EV_USER) |
| `GET` | `/api/ev/bookings/mine` | Get user's bookings (paginated) | Yes (EV_USER) |
| `GET` | `/api/ev/bookings/{id}` | Get booking detail | Yes (EV_USER) |
| `POST` | `/api/ev/bookings/{id}/cancel` | Cancel booking | Yes (EV_USER) |
| `POST` | `/api/ev/bookings/{id}/payment-intent` | Create payment intent | Yes (EV_USER) |
| `POST` | `/api/ev/payments/{intentId}/simulate-success` | Mock payment success | Yes (EV_USER) |
| `POST` | `/api/ev/payments/{intentId}/simulate-fail` | Mock payment fail | Yes (EV_USER) |

---

## 4.6 EV User Mobile API — Battery Swap

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/ev/battery-swap/stations` | Get nearby swap stations | Yes (EV_USER) |
| `GET` | `/api/ev/battery-swap/stations/{stationId}` | Get swap station detail | Yes (EV_USER) |
| `POST` | `/api/ev/battery-swap/reservations` | Reserve a battery swap | Yes (EV_USER) |
| `POST` | `/api/ev/battery-swap/reservations/{id}/confirm-arrival` | Confirm arrival | Yes (EV_USER) |
| `POST` | `/api/ev/battery-swap/reservations/{id}/start` | Start swap (generates 6-digit code) | Yes (EV_USER) |
| `POST` | `/api/ev/battery-swap/reservations/{id}/confirm` | Confirm swap completion | Yes (EV_USER) |
| `POST` | `/api/ev/battery-swap/reservations/{id}/cancel` | Cancel reservation | Yes (EV_USER) |
| `POST` | `/api/ev/battery-swap/reservations/{id}/pay` | Pay for swap (mock) | Yes (EV_USER) |
| `GET` | `/api/ev/battery-swap/reservations/mine` | Get user's reservations | Yes (EV_USER) |

**`POST /api/ev/battery-swap/reservations`**

Request:
```json
{
  "stationId": "uuid",
  "expectedArrivalAt": "2024-12-20T10:00:00Z",
  "requestedBatteryPercent": 80,
  "batteryCapacityKwh": 50.0,
  "note": "..."
}
```

---

## 4.7 EV User Mobile API — Change Requests & Issues

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/ev/change-requests` | Submit station change request | Yes (EV_USER) |
| `GET` | `/api/ev/change-requests/mine` | Get user's change requests | Yes (EV_USER) |
| `GET` | `/api/ev/change-requests/{id}` | Get CR detail | Yes (EV_USER) |
| `POST` | `/api/ev/change-requests/{id}/submit` | Submit CR for review | Yes (EV_USER) |
| `PUT` | `/api/ev/change-requests/{id}` | Update CR draft | Yes (EV_USER) |
| `POST` | `/api/ev/battery-swap-change-requests` | Submit battery swap CR | Yes (EV_USER) |
| `GET` | `/api/ev/battery-swap-change-requests` | Get battery swap CRs | Yes (EV_USER) |
| `GET` | `/api/ev/battery-swap-change-requests/{id}` | Get battery swap CR detail | Yes (EV_USER) |
| `POST` | `/api/ev/battery-swap-change-requests/{id}/submit` | Submit battery swap CR | Yes (EV_USER) |
| `GET` | `/api/ev/issues/mine` | Get user's reported issues | Yes (EV_USER) |

---

## 4.8 EV User Mobile API — AI Recommendations

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/ev/ai/personalized-recommendations` | Get personalized recommendations | Yes (EV_USER) |
| `POST` | `/api/ev/ai/smart-time-suggestions` | Get smart charging time suggestions | Yes (EV_USER) |

**`POST /api/ev/ai/personalized-recommendations`**

Request:
```json
{
  "latitude": 10.7628,
  "longitude": 106.6816,
  "batteryPercent": 30,
  "targetPercent": 80,
  "batteryCapacityKwh": 50.0
}
```

---

## 4.9 EV User Mobile API — Loyalty

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/ev/loyalty/me` | Get current user's loyalty profile | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/points/history` | Get points transaction history (paginated) | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/ratings/eligible` | Get stations eligible for rating | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/ratings` | Get current user's ratings | Yes (EV_USER) |
| `POST` | `/api/ev/loyalty/ratings` | Submit station rating | Yes (EV_USER) |
| `POST` | `/api/ev/loyalty/ratings/{id}/helpful` | Mark rating as helpful | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/badges` | Get earned badges | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/badges/available` | Get all badges with progress | Yes (EV_USER) |
| `POST` | `/api/ev/loyalty/referral/generate` | Generate referral code | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/public/stations/{stationId}/ratings` | Get public station ratings (paginated) | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/public/stations/{stationId}/summary` | Get station rating summary | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/vouchers` | Get available vouchers | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/vouchers/mine` | Get user's redeemed vouchers (paginated) | Yes (EV_USER) |
| `POST` | `/api/ev/loyalty/vouchers/{definitionId}/redeem` | Redeem voucher | Yes (EV_USER) |
| `GET` | `/api/ev/loyalty/vouchers/redemptions/{redemptionId}` | Get redemption detail | Yes (EV_USER) |
| `POST` | `/api/ev/loyalty/vouchers/redemptions/{redemptionId}/apply-to-booking` | Apply voucher to booking | Yes (EV_USER) |
| `POST` | `/api/ev/loyalty/vouchers/redemptions/{redemptionId}/apply-to-swap` | Apply voucher to swap | Yes (EV_USER) |

---

## 4.10 EV User Mobile API — Notifications

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/ev/notifications` | Get notifications (paginated) | Yes (EV_USER) |
| `GET` | `/api/ev/notifications/unread-count` | Get unread count | Yes (EV_USER) |
| `PATCH` | `/api/ev/notifications/{id}/read` | Mark as read | Yes (EV_USER) |
| `PATCH` | `/api/ev/notifications/read-all` | Mark all as read | Yes (EV_USER) |

---

## 4.11 EV User Mobile API — File Upload

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/ev/files/presign-view` | Get presigned view URL | Yes (EV_USER) |

---

## 4.12 Collaborator Mobile API

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/collab/mobile/tasks` | Get assigned tasks | Yes (COLLABORATOR) |
| `POST` | `/api/collab/mobile/tasks/{id}/check-in` | GPS check-in | Yes (COLLABORATOR) |
| `POST` | `/api/collab/mobile/files/upload` | Proxy file upload | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/files/presign-view` | Get presigned view URL | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/files/view` | Proxy file view (bytes) | Yes (COLLABORATOR) |
| `POST` | `/api/collab/mobile/tasks/{id}/submit-evidence` | Submit verification evidence | Yes (COLLABORATOR) |
| `PUT` | `/api/collab/mobile/me/location` | Update GPS location | Yes (COLLABORATOR) |
| `POST` | `/api/mobile/collab/battery-swap/verification/tasks/{id}/checkin` | Battery swap check-in | Yes (COLLABORATOR) |
| `POST` | `/api/mobile/collab/battery-swap/verification/tasks/{id}/evidence` | Submit swap verification evidence | Yes (COLLABORATOR) |
| `POST` | `/api/collab/mobile/change-requests` | **NEW 2026-06** — Create charging-station CR | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/change-requests/mine` | **NEW 2026-06** — List my charging CRs | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/change-requests/{id}` | **NEW 2026-06** — Get charging CR detail | Yes (COLLABORATOR) |
| `PUT` | `/api/collab/mobile/change-requests/{id}` | **NEW 2026-06** — Update charging CR draft | Yes (COLLABORATOR) |
| `POST` | `/api/collab/mobile/change-requests/{id}/submit` | **NEW 2026-06** — Submit charging CR for review | Yes (COLLABORATOR) |
| `POST` | `/api/collab/mobile/battery-swap-change-requests` | **NEW 2026-06** — Create battery-swap CR | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/battery-swap-change-requests/mine` | **NEW 2026-06** — List my battery-swap CRs | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/battery-swap-change-requests/{id}` | **NEW 2026-06** — Get battery-swap CR detail | Yes (COLLABORATOR) |
| `POST` | `/api/collab/mobile/battery-swap-change-requests/{id}/submit` | **NEW 2026-06** — Submit battery-swap CR for review | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/stations/search/by-name` | **NEW 2026-06-14** — Search published charging stations by name (auto-fill helper) | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/stations/{id}` | **NEW 2026-06-14** — Get full published charging-station detail (auto-fill helper) | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/battery-swap-stations/search/by-name` | **NEW 2026-06-14** — Search published battery-swap stations by name (auto-fill helper) | Yes (COLLABORATOR) |
| `GET` | `/api/collab/mobile/battery-swap-stations/{id}` | **NEW 2026-06-14** — Get full published battery-swap station detail (auto-fill helper) | Yes (COLLABORATOR) |
| `GET` | `/api/collab/notifications` | Get notifications | Yes (COLLABORATOR) |
| `GET` | `/api/collab/notifications/unread-count` | Get unread count | Yes (COLLABORATOR) |
| `PATCH` | `/api/collab/notifications/{id}/read` | Mark as read | Yes (COLLABORATOR) |
| `PATCH` | `/api/collab/notifications/read-all` | Mark all as read | Yes (COLLABORATOR) |
| `POST` | `/api/collab/notifications/push-token` | Register FCM token | Yes (COLLABORATOR) |
| `GET` | `/api/collab/notifications/preferences` | Get preferences | Yes (COLLABORATOR) |
| `PUT` | `/api/collab/notifications/preferences` | Save preferences | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/tasks/kpi` | Get monthly KPI | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/me/contracts` | Get contracts | Yes (COLLABORATOR) |

---

## 4.13 Collaborator Web API

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/collab/web/tasks` | Get tasks (paginated) | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/tasks/history` | Get task history (paginated) | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/tasks/kpi` | Get KPI | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/me/profile` | Get profile | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/me/contracts` | Get contracts | Yes (COLLABORATOR) |
| `PUT` | `/api/collab/web/me/location` | Update GPS location | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/battery-swap/tasks` | Get battery swap tasks (paginated) | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/battery-swap/tasks/{id}` | Get battery swap task detail | Yes (COLLABORATOR) |
| `GET` | `/api/collab/web/battery-swap/kpi` | Get battery swap KPI | Yes (COLLABORATOR) |

---

## 4.14 Admin Web API — Dashboard

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/dashboard/stats` | Overall statistics | Yes (ADMIN) |
| `GET` | `/api/admin/dashboard/trends` | Booking trends | Yes (ADMIN) |
| `GET` | `/api/admin/dashboard/booking-stats` | Booking statistics | Yes (ADMIN) |
| `GET` | `/api/admin/dashboard/issue-stats` | Issue statistics | Yes (ADMIN) |
| `GET` | `/api/admin/dashboard/trust-overview` | Trust overview (paginated) | Yes (ADMIN) |

---

## 4.15 Admin Web API — Station Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/stations` | List stations (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/stations/{id}` | Get station detail | Yes (ADMIN) |
| `POST` | `/api/admin/stations` | Create station | Yes (ADMIN) |
| `PUT` | `/api/admin/stations/{id}` | Update station | Yes (ADMIN) |
| `DELETE` | `/api/admin/stations/{id}` | Delete station | Yes (ADMIN) |
| `POST` | `/api/admin/stations/import-csv` | Bulk import CSV | Yes (ADMIN) |

---

## 4.16 Admin Web API — Trust Score Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/stations/{stationId}/trust` | Get station trust | Yes (ADMIN) |
| `POST` | `/api/admin/stations/{stationId}/trust/recalculate` | Recalculate trust | Yes (ADMIN) |
| `GET` | `/api/admin/stations/trust/summary` | Get trust summary | Yes (ADMIN) |
| `GET` | `/api/v1/battery-swap/trust/{stationId}` | Get battery swap trust (public) | No |
| `GET` | `/api/v1/battery-swap/trust/{stationId}/breakdown` | Get trust breakdown (public) | No |
| `GET` | `/api/v1/battery-swap/trust/{stationId}/level` | Get trust level (public) | No |
| `POST` | `/api/v1/battery-swap/trust/{stationId}/recalculate` | Recalculate swap trust | Yes (ADMIN) |
| `GET` | `/api/v1/battery-swap/trust/summary` | Get swap trust summary (public) | No |

---

## 4.17 Admin Web API — Change Requests

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/change-requests` | List change requests | Yes (ADMIN) |
| `GET` | `/api/admin/change-requests/{id}` | Get CR detail | Yes (ADMIN) |
| `POST` | `/api/admin/change-requests/{id}/approve` | Approve CR | Yes (ADMIN) |
| `POST` | `/api/admin/change-requests/{id}/reject` | Reject CR | Yes (ADMIN) |
| `POST` | `/api/admin/change-requests/{id}/publish` | Publish CR directly | Yes (ADMIN) |
| `GET` | `/api/admin/change-requests/{id}/audit` | Get CR audit log | Yes (ADMIN) |

---

## 4.18 Admin Web API — Battery Swap Station Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/battery-swap/stations` | List swap stations (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/battery-swap/stations/{stationId}` | Get swap station detail | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/stations` | Create swap station | Yes (ADMIN) |
| `PUT` | `/api/admin/battery-swap/stations/{stationId}` | Update swap station | Yes (ADMIN) |
| `DELETE` | `/api/admin/battery-swap/stations/{stationId}` | Delete swap station | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/stations/import-csv` | Bulk import CSV | Yes (ADMIN) |
| `GET` | `/api/admin/battery-swap/change-requests` | List swap CRs | Yes (ADMIN) |
| `GET` | `/api/admin/battery-swap/change-requests/{id}` | Get swap CR detail | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/change-requests/{id}/approve` | Approve swap CR | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/change-requests/{id}/reject` | Reject swap CR | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/change-requests/{id}/publish` | Publish swap CR | Yes (ADMIN) |
| `POST` | `/api/admin/battery-swap/change-requests` | Create swap CR | Yes (ADMIN) |
| `PUT` | `/api/admin/battery-swap/change-requests/{id}` | Update draft swap CR | Yes (ADMIN) |

---

## 4.19 Admin Web API — Collaborator Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/admin/collaborators` | Create collaborator profile | Yes (ADMIN) |
| `POST` | `/api/admin/collaborators/with-account` | Create account + profile | Yes (ADMIN) |
| `DELETE` | `/api/admin/collaborators/{id}` | Delete collaborator | Yes (ADMIN) |
| `GET` | `/api/admin/collaborators` | List collaborators (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/collaborators/{id}` | Get collaborator detail | Yes (ADMIN) |
| `GET` | `/api/admin/collaborators/performance` | Get performance (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/collaborators/{id}/performance` | Get collaborator performance | Yes (ADMIN) |

---

## 4.20 Admin Web API — Contract Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/admin/contracts` | Create contract | Yes (ADMIN) |
| `GET` | `/api/admin/contracts` | Get contracts by collaborator | Yes (ADMIN) |
| `GET` | `/api/admin/contracts/{id}` | Get contract detail | Yes (ADMIN) |
| `PUT` | `/api/admin/contracts/{id}` | Update contract | Yes (ADMIN) |
| `POST` | `/api/admin/contracts/{id}/terminate` | Terminate contract | Yes (ADMIN) |

---

## 4.21 Admin Web API — Verification Tasks

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/admin/verification-tasks` | Create verification task | Yes (ADMIN) |
| `GET` | `/api/admin/verification-tasks` | List tasks (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/verification-tasks/{id}` | Get task detail | Yes (ADMIN) |
| `POST` | `/api/admin/verification-tasks/{id}/assign` | Assign task | Yes (ADMIN) |
| `GET` | `/api/admin/verification-tasks/{id}/collaborator-candidates` | Get candidates (paginated) | Yes (ADMIN) |
| `DELETE` | `/api/admin/verification-tasks/{id}` | Delete task | Yes (ADMIN) |
| `POST` | `/api/admin/verification-tasks/{id}/review` | Submit review | Yes (ADMIN) |

---

## 4.22 Admin Web API — Issues Management

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/issues` | List issues | Yes (ADMIN) |
| `GET` | `/api/admin/issues/{id}` | Get issue detail | Yes (ADMIN) |
| `POST` | `/api/admin/issues/{id}/acknowledge` | Acknowledge issue | Yes (ADMIN) |
| `POST` | `/api/admin/issues/{id}/resolve` | Resolve issue | Yes (ADMIN) |
| `POST` | `/api/admin/issues/{id}/reject` | Reject issue | Yes (ADMIN) |

---

## 4.23 Admin Web API — Audit Logs

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/audit` | Query audit logs (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/stations/{stationId}/audit` | Get station audit logs | Yes (ADMIN) |
| `GET` | `/api/admin/change-requests/{id}/audit` | Get CR audit logs | Yes (ADMIN) |

---

## 4.24 Admin Web API — Registration Requests

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/registration-requests` | List requests (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/registration-requests/{id}` | Get request detail | Yes (ADMIN) |
| `POST` | `/api/admin/registration-requests/{id}/approve` | Approve (creates account) | Yes (ADMIN) |
| `POST` | `/api/admin/registration-requests/{id}/reject` | Reject with reason | Yes (ADMIN) |
| `GET` | `/api/admin/registration-requests/pending-count` | Get pending count | Yes (ADMIN) |

---

## 4.25 Admin Web API — Loyalty Administration

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/loyalty/dashboard` | Get loyalty dashboard stats | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/users` | List loyalty users (paginated) | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/users/{userId}` | Get user loyalty profile | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/users/{userId}/history` | Get point history (paginated) | Yes (ADMIN) |
| `POST` | `/api/admin/loyalty/users/{userId}/adjust` | Adjust points manually | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/badges` | List all badges | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/ratings` | List ratings (paginated) | Yes (ADMIN) |
| `PUT` | `/api/admin/loyalty/ratings/{id}/hide` | Hide rating | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/vouchers` | List voucher definitions | Yes (ADMIN) |
| `POST` | `/api/admin/loyalty/vouchers` | Create voucher definition | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/vouchers/{id}` | Get voucher detail | Yes (ADMIN) |
| `PATCH` | `/api/admin/loyalty/vouchers/{id}/status` | Update voucher status | Yes (ADMIN) |
| `DELETE` | `/api/admin/loyalty/vouchers/{id}` | Delete voucher | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/vouchers/{id}/stats` | Get voucher stats | Yes (ADMIN) |
| `GET` | `/api/admin/loyalty/redemptions` | List redemptions (paginated) | Yes (ADMIN) |

---

## 4.26 Admin Web API — Files

| Method | Path | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/admin/files/presign-view` | Get presigned view URL | Yes (ADMIN) |

---

## 4.27 WebSocket Endpoints

| Endpoint | Protocol | Description | Auth |
|---|---|---|---|
| `/ws/simulator` | WebSocket | Hardware simulator display | `deviceKey` query param |

The hardware simulator connects with `deviceKey` as a query parameter:
```
ws://localhost:8080/ws/simulator?deviceKey=station_device_key_here
```

Server pushes swap codes and slot status updates to connected simulator clients.

---

## 4.28 Error Response Format

All error responses follow this structure:

```json
{
  "timestamp": "2024-12-20T10:00:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Charger unit is not available for the selected time slot",
  "path": "/api/ev/bookings"
}
```

Common HTTP status codes used:

| Code | Meaning |
|---|---|
| 200 | OK |
| 201 | Created |
| 204 | No Content (DELETE success) |
| 400 | Bad Request (validation error) |
| 401 | Unauthorized (missing/invalid token) |
| 403 | Forbidden (insufficient role) |
| 404 | Not Found |
| 409 | Conflict (e.g., double-booking, slot already taken) |
| 500 | Internal Server Error |

---

## 4.29 API Count Summary

| Category | Count |
|---|---|
| Authentication | 2 |
| Public | 6 |
| EV User — Stations | 6 |
| EV User — Booking | 7 |
| EV User — Battery Swap | 9 |
| EV User — Change Requests & Issues | 10 |
| EV User — AI Recommendations | 2 |
| EV User — Loyalty | 17 |
| EV User — Notifications | 4 |
| EV User — Files | 2 |
| Collaborator Mobile | 18 + **8 NEW (CR)** + **4 NEW (search/auto-fill)** = 30 |
| Collaborator Web | 10 |
| Admin — Dashboard | 5 |
| Admin — Stations | 5 + 2 CSV |
| Admin — Trust | 8 |
| Admin — Change Requests | 6 |
| Admin — Battery Swap Stations | 13 |
| Admin — Collaborators | 7 |
| Admin — Contracts | 5 |
| Admin — Verification Tasks | 7 |
| Admin — Issues | 5 |
| Admin — Audit Logs | 3 |
| Admin — Registration Requests | 5 |
| Admin — Loyalty | 14 |
| Admin — Files | 1 |
| **Total REST Endpoints** | **~162** |

*Note: Some endpoints share the same path with different HTTP methods, so the total unique route paths is lower than the endpoint count.*
