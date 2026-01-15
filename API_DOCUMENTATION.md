# VoltGo API Documentation

## Table of Contents
1. [Overview](#overview)
2. [Base URL](#base-url)
3. [Authentication](#authentication)
4. [Common Response Formats](#common-response-formats)
5. [Public APIs](#public-apis)
6. [Admin Web APIs](#admin-web-apis)
7. [EV User Mobile APIs](#ev-user-mobile-apis)
8. [Collaborator APIs](#collaborator-apis)
9. [Error Codes](#error-codes)

---

## Overview

VoltGo is an EV charging station management platform with the following user roles:
- **ADMIN**: System administrators with full access
- **EV_USER**: End users who search and book charging stations
- **PROVIDER**: Station providers who can create change requests
- **COLLABORATOR**: Field collaborators who verify stations

---

## Base URL

```
http://localhost:8080
```

---

## Authentication

All protected endpoints require JWT authentication via Bearer token in the Authorization header:

```
Authorization: Bearer <jwt_token>
```

### Get JWT Token

Use the `/auth/login` endpoint to obtain a JWT token.

---

## Common Response Formats

### Pagination Response

```json
{
  "content": [...],
  "page": 0,
  "size": 20,
  "totalElements": 100,
  "totalPages": 5,
  "first": true,
  "last": false
}
```

### Error Response

```json
{
  "error": "Error code",
  "message": "Error message",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

---

## Public APIs

### Authentication

#### Register User
- **Method**: `POST`
- **Path**: `/auth/register`
- **Auth**: None (Public)
- **Description**: Register a new user (EV_USER, PROVIDER, or COLLABORATOR)
- **Request Body**:
```json
{
  "email": "user@example.com",
  "name": "User Name",
  "password": "Password123",
  "role": "EV_USER"
}
```
- **Response**: `201 Created`
```json
{
  "token": "jwt_token_here",
  "userId": "uuid",
  "email": "user@example.com",
  "name": "User Name",
  "role": "EV_USER"
}
```

#### Login
- **Method**: `POST`
- **Path**: `/auth/login`
- **Auth**: None (Public)
- **Description**: Login and get JWT token
- **Request Body**:
```json
{
  "email": "user@example.com",
  "password": "Password123"
}
```
- **Response**: `200 OK`
```json
{
  "token": "jwt_token_here",
  "userId": "uuid",
  "email": "user@example.com",
  "name": "User Name",
  "role": "EV_USER"
}
```

### Health Check

#### Health Check
- **Method**: `GET`
- **Path**: `/healthz`
- **Auth**: None (Public)
- **Description**: Check if the service is running
- **Response**: `200 OK`
```json
{
  "status": "UP"
}
```

---

## Admin Web APIs

**Base Path**: `/api/admin`  
**Required Role**: `ADMIN`

### Admin Web

#### Test Endpoint
- **Method**: `GET`
- **Path**: `/api/admin/test`
- **Description**: Test endpoint for Admin Web API
- **Response**: `200 OK`
```json
{
  "message": "Admin Web API is accessible"
}
```

### Stations Management

#### List All Stations
- **Method**: `GET`
- **Path**: `/api/admin/stations`
- **Description**: Get paginated list of all stations (admin only)
- **Query Parameters**:
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`
```json
{
  "content": [
    {
      "stationId": "uuid",
      "name": "Station Name",
      "address": "Station Address",
      "latitude": 21.0285,
      "longitude": 105.8542,
      "status": "active",
      "trustScore": 85.5,
      "versionCount": 3,
      "bookingCount": 10
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 100,
  "totalPages": 5
}
```

#### Get Station Detail
- **Method**: `GET`
- **Path**: `/api/admin/stations/{stationId}`
- **Description**: Get full details of a station including all versions (admin only)
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Response**: `200 OK`
```json
{
  "stationId": "uuid",
  "name": "Station Name",
  "address": "Station Address",
  "latitude": 21.0285,
  "longitude": 105.8542,
  "services": [...],
  "chargingPorts": [...],
  "versions": [...]
}
```

#### Create Station
- **Method**: `POST`
- **Path**: `/api/admin/stations`
- **Description**: Create a new station directly (bypass change request workflow). Admin only.
- **Request Body**:
```json
{
  "stationData": {
    "name": "Station Name",
    "address": "Station Address",
    "latitude": 21.0285,
    "longitude": 105.8542,
    "operatingHours": "24/7",
    "parking": "Paid",
    "stationType": "Public",
    "services": [...],
    "chargingPorts": [...]
  },
  "publishImmediately": true
}
```
- **Response**: `201 Created`

#### Update Station
- **Method**: `PUT`
- **Path**: `/api/admin/stations/{stationId}`
- **Description**: Update a station by creating a new version. Admin only.
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Request Body**: Same as Create Station
- **Response**: `200 OK`

#### Delete Station
- **Method**: `DELETE`
- **Path**: `/api/admin/stations/{stationId}`
- **Description**: Permanently delete a station from database. All related data will be automatically deleted due to CASCADE constraints. Cannot delete if there are active bookings.
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Response**: `204 No Content`

#### Get Station Trust Score
- **Method**: `GET`
- **Path**: `/api/admin/stations/{stationId}/trust`
- **Description**: Get full trust score with detailed breakdown for a station (admin only)
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Response**: `200 OK`
```json
{
  "stationId": "uuid",
  "score": 85.5,
  "breakdown": {
    "verificationScore": 90.0,
    "issueScore": 80.0,
    "bookingScore": 85.0
  },
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

#### Recalculate Trust Score
- **Method**: `POST`
- **Path**: `/api/admin/stations/{stationId}/trust/recalculate`
- **Description**: Force recalculation of trust score for a station
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Response**: `200 OK`

#### Import Stations from CSV
- **Method**: `POST`
- **Path**: `/api/admin/stations/import-csv`
- **Content-Type**: `multipart/form-data`
- **Description**: Import multiple stations from CSV file. Format: name,address,latitude,longitude,ports_250kw,ports_180kw,ports_150kw,ports_120kw,ports_80kw,ports_60kw,ports_40kw,ports_ac,operatingHours,parking,stationType,status
- **Request**: Form data with `file` field containing CSV file
- **Response**: `200 OK`
```json
{
  "totalRows": 10,
  "successCount": 8,
  "failureCount": 2,
  "results": [
    {
      "row": 1,
      "success": true,
      "stationId": "uuid",
      "message": "Station created successfully"
    },
    {
      "row": 2,
      "success": false,
      "message": "Validation error: Invalid latitude"
    }
  ]
}
```

### Change Requests Management

#### List Change Requests
- **Method**: `GET`
- **Path**: `/api/admin/change-requests`
- **Description**: Get all change requests with optional status filter
- **Query Parameters**:
  - `status` (optional): Filter by status (PENDING, APPROVED, REJECTED, PUBLISHED, DRAFT)
- **Response**: `200 OK`
```json
[
  {
    "id": "uuid",
    "type": "CREATE_STATION",
    "status": "PENDING",
    "submittedBy": "uuid",
    "createdAt": "2024-01-01T00:00:00Z"
  }
]
```

#### Get Change Request Detail
- **Method**: `GET`
- **Path**: `/api/admin/change-requests/{id}`
- **Description**: Get full details of a specific change request including audit logs
- **Path Parameters**:
  - `id` (required): Change request UUID
- **Response**: `200 OK`

#### Approve Change Request
- **Method**: `POST`
- **Path**: `/api/admin/change-requests/{id}/approve`
- **Description**: Approve a PENDING change request. Status changes to APPROVED.
- **Path Parameters**:
  - `id` (required): Change request UUID
- **Request Body** (optional):
```json
{
  "note": "Approved with minor modifications"
}
```
- **Response**: `200 OK`

#### Reject Change Request
- **Method**: `POST`
- **Path**: `/api/admin/change-requests/{id}/reject`
- **Description**: Reject a PENDING change request. Reason is required.
- **Path Parameters**:
  - `id` (required): Change request UUID
- **Request Body**:
```json
{
  "reason": "Location data is incorrect"
}
```
- **Response**: `200 OK`

#### Publish Change Request
- **Method**: `POST`
- **Path**: `/api/admin/change-requests/{id}/publish`
- **Description**: Publish an APPROVED change request. This makes the station version publicly visible.
- **Path Parameters**:
  - `id` (required): Change request UUID
- **Response**: `200 OK`

### Issues Management

#### List Issues
- **Method**: `GET`
- **Path**: `/api/admin/issues`
- **Description**: Get all issues with optional status filter
- **Query Parameters**:
  - `status` (optional): Filter by status (OPEN, ACKNOWLEDGED, RESOLVED, REJECTED)
- **Response**: `200 OK`
```json
[
  {
    "id": "uuid",
    "stationId": "uuid",
    "category": "LOCATION",
    "status": "OPEN",
    "reportedBy": "uuid",
    "createdAt": "2024-01-01T00:00:00Z"
  }
]
```

#### Get Issue Detail
- **Method**: `GET`
- **Path**: `/api/admin/issues/{id}`
- **Description**: Get full details of a specific issue
- **Path Parameters**:
  - `id` (required): Issue UUID
- **Response**: `200 OK`

#### Acknowledge Issue
- **Method**: `POST`
- **Path**: `/api/admin/issues/{id}/acknowledge`
- **Description**: Mark an OPEN issue as ACKNOWLEDGED (seen by admin)
- **Path Parameters**:
  - `id` (required): Issue UUID
- **Response**: `200 OK`

#### Resolve Issue
- **Method**: `POST`
- **Path**: `/api/admin/issues/{id}/resolve`
- **Description**: Mark an OPEN or ACKNOWLEDGED issue as RESOLVED
- **Path Parameters**:
  - `id` (required): Issue UUID
- **Request Body**:
```json
{
  "note": "Issue has been fixed"
}
```
- **Response**: `200 OK`

#### Reject Issue
- **Method**: `POST`
- **Path**: `/api/admin/issues/{id}/reject`
- **Description**: Mark an OPEN or ACKNOWLEDGED issue as REJECTED (invalid report)
- **Path Parameters**:
  - `id` (required): Issue UUID
- **Request Body**:
```json
{
  "note": "Issue is invalid"
}
```
- **Response**: `200 OK`

### Audit Logs

#### Query Audit Logs
- **Method**: `GET`
- **Path**: `/api/admin/audit`
- **Description**: Query audit logs with optional filters: entityType, entityId, from, to
- **Query Parameters**:
  - `entityType` (optional): Filter by entity type (CHANGE_REQUEST, STATION, STATION_VERSION)
  - `entityId` (optional): Filter by entity ID (UUID)
  - `from` (optional): Filter from date (ISO format)
  - `to` (optional): Filter to date (ISO format)
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`
```json
{
  "content": [
    {
      "id": "uuid",
      "entityType": "STATION",
      "entityId": "uuid",
      "action": "CREATE",
      "performedBy": "uuid",
      "timestamp": "2024-01-01T00:00:00Z"
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 100
}
```

#### Get Station Audit Logs
- **Method**: `GET`
- **Path**: `/api/admin/stations/{stationId}/audit`
- **Description**: Get all audit logs related to a station (including versions and change requests)
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Response**: `200 OK`

#### Get Change Request Audit Logs
- **Method**: `GET`
- **Path**: `/api/admin/change-requests/{id}/audit`
- **Description**: Get all audit logs for a specific change request
- **Path Parameters**:
  - `id` (required): Change request UUID
- **Response**: `200 OK`

### Collaborators Management

#### Create Collaborator Profile
- **Method**: `POST`
- **Path**: `/api/admin/collaborators`
- **Description**: Create a collaborator profile for a user account with COLLABORATOR role
- **Request Body**:
```json
{
  "userAccountId": "uuid",
  "phone": "+84123456789",
  "address": "Address"
}
```
- **Response**: `201 Created`

#### List Collaborators
- **Method**: `GET`
- **Path**: `/api/admin/collaborators`
- **Description**: Get all collaborator profiles with pagination
- **Query Parameters**:
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`

#### Get Collaborator by ID
- **Method**: `GET`
- **Path**: `/api/admin/collaborators/{id}`
- **Description**: Get a specific collaborator profile by ID
- **Path Parameters**:
  - `id` (required): Collaborator profile UUID
- **Response**: `200 OK`

### Contracts Management

#### Create Contract
- **Method**: `POST`
- **Path**: `/api/admin/contracts`
- **Description**: Create a new contract for a collaborator
- **Request Body**:
```json
{
  "collaboratorId": "uuid",
  "startDate": "2024-01-01",
  "endDate": "2024-12-31",
  "region": "Hanoi",
  "note": "Contract note"
}
```
- **Response**: `201 Created`

#### List Contracts by Collaborator
- **Method**: `GET`
- **Path**: `/api/admin/contracts`
- **Description**: Get all contracts for a specific collaborator
- **Query Parameters**:
  - `collaboratorId` (required): Collaborator profile UUID
- **Response**: `200 OK`

#### Get Contract by ID
- **Method**: `GET`
- **Path**: `/api/admin/contracts/{id}`
- **Description**: Get a specific contract by ID
- **Path Parameters**:
  - `id` (required): Contract UUID
- **Response**: `200 OK`

#### Update Contract
- **Method**: `PUT`
- **Path**: `/api/admin/contracts/{id}`
- **Description**: Update contract dates, region, or note
- **Path Parameters**:
  - `id` (required): Contract UUID
- **Request Body**:
```json
{
  "startDate": "2024-01-01",
  "endDate": "2024-12-31",
  "region": "Hanoi",
  "note": "Updated note"
}
```
- **Response**: `200 OK`

#### Terminate Contract
- **Method**: `POST`
- **Path**: `/api/admin/contracts/{id}/terminate`
- **Description**: Terminate an active contract
- **Path Parameters**:
  - `id` (required): Contract UUID
- **Request Body** (optional):
```json
{
  "reason": "Contract termination reason"
}
```
- **Response**: `200 OK`

### Verification Tasks Management

#### Create Verification Task
- **Method**: `POST`
- **Path**: `/api/admin/verification-tasks`
- **Description**: Create a new verification task for a station. Optionally link to a change request.
- **Request Body**:
```json
{
  "stationId": "uuid",
  "changeRequestId": "uuid",
  "priority": 1,
  "slaHours": 24,
  "note": "Task note"
}
```
- **Response**: `200 OK`

#### Get Collaborator Candidates
- **Method**: `GET`
- **Path**: `/api/admin/verification-tasks/{id}/collaborator-candidates`
- **Description**: Get list of collaborators sorted by distance to station with workload stats
- **Path Parameters**:
  - `id` (required): Verification task UUID
- **Query Parameters**:
  - `onlyActiveContract` (optional, default: true): Only include collaborators with active contracts
  - `includeUnlocated` (optional, default: false): Include collaborators without location
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`

#### Assign Task to Collaborator
- **Method**: `POST`
- **Path**: `/api/admin/verification-tasks/{id}/assign`
- **Description**: Assign an OPEN verification task to a collaborator by user ID (selected from candidates)
- **Path Parameters**:
  - `id` (required): Verification task UUID
- **Request Body**:
```json
{
  "collaboratorUserId": "uuid"
}
```
or
```json
{
  "collaboratorEmail": "collaborator@example.com"
}
```
- **Response**: `200 OK`

#### Get Verification Tasks
- **Method**: `GET`
- **Path**: `/api/admin/verification-tasks`
- **Description**: Get verification tasks with optional status filter
- **Query Parameters**:
  - `status` (optional): Filter by status (OPEN, ASSIGNED, CHECKED_IN, SUBMITTED, REVIEWED)
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`

#### Get Verification Task by ID
- **Method**: `GET`
- **Path**: `/api/admin/verification-tasks/{id}`
- **Description**: Get a specific verification task with all details including check-in and review
- **Path Parameters**:
  - `id` (required): Verification task UUID
- **Response**: `200 OK`

#### Review Verification Task
- **Method**: `POST`
- **Path**: `/api/admin/verification-tasks/{id}/review`
- **Description**: Review a SUBMITTED verification task as PASS or FAIL
- **Path Parameters**:
  - `id` (required): Verification task UUID
- **Request Body**:
```json
{
  "result": "PASS",
  "note": "Review note"
}
```
- **Response**: `200 OK`

---

## EV User Mobile APIs

**Base Path**: `/api/ev`  
**Required Role**: `EV_USER` or `PROVIDER`

### User Profile

#### Get My Profile
- **Method**: `GET`
- **Path**: `/api/profile/me`
- **Description**: Get current user's profile information
- **Response**: `200 OK`
```json
{
  "userId": "uuid",
  "email": "user@example.com",
  "name": "User Name",
  "phone": "+84123456789",
  "role": "EV_USER"
}
```

#### Update My Profile
- **Method**: `PUT`
- **Path**: `/api/profile/me`
- **Description**: Update current user's profile (name, phone)
- **Request Body**:
```json
{
  "name": "Updated Name",
  "phone": "+84123456789"
}
```
- **Response**: `200 OK`

#### Change Password
- **Method**: `POST`
- **Path**: `/api/profile/me/change-password`
- **Description**: Change current user's password
- **Request Body**:
```json
{
  "currentPassword": "OldPassword123",
  "newPassword": "NewPassword123"
}
```
- **Response**: `200 OK`
```json
{
  "message": "Password changed successfully"
}
```

### Stations

#### Search Stations Within Radius
- **Method**: `GET`
- **Path**: `/api/ev/stations`
- **Description**: Find published charging stations within specified radius. Only returns PUBLISHED versions.
- **Query Parameters**:
  - `lat` (required): Latitude (-90 to 90)
  - `lng` (required): Longitude (-180 to 180)
  - `radiusKm` (required): Radius in kilometers (0.1 to 100)
  - `minPowerKw` (optional): Minimum power in kW (DC ports only)
  - `hasAC` (optional): Filter stations that have AC ports (true/false)
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`
```json
{
  "content": [
    {
      "stationId": "uuid",
      "name": "Station Name",
      "address": "Station Address",
      "latitude": 21.0285,
      "longitude": 105.8542,
      "distanceKm": 2.5,
      "trustScore": 85.5,
      "totalPorts": 10,
      "dcPorts": 8,
      "acPorts": 2
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 50
}
```

#### Get Station Detail
- **Method**: `GET`
- **Path**: `/api/ev/stations/{stationId}`
- **Description**: Get full detail of a published station including all charging ports
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Response**: `200 OK`
```json
{
  "stationId": "uuid",
  "name": "Station Name",
  "address": "Station Address",
  "latitude": 21.0285,
  "longitude": 105.8542,
  "operatingHours": "24/7",
  "parking": "Paid",
  "stationType": "Public",
  "trustScore": 85.5,
  "chargingPorts": [
    {
      "portId": "uuid",
      "powerKw": 250,
      "powerType": "DC",
      "connectorType": "CCS2"
    }
  ],
  "services": [...]
}
```

#### Search Stations by Name
- **Method**: `GET`
- **Path**: `/api/ev/stations/search/by-name`
- **Description**: Search published charging stations by name (case-insensitive, partial match). Only returns PUBLISHED versions.
- **Query Parameters**:
  - `name` (required): Search query for station name
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`

#### Get Station Recommendations
- **Method**: `POST`
- **Path**: `/api/ev/stations/recommendations`
- **Description**: Get optimal station recommendations based on battery level, capacity, and target charge level. Optimizes for minimum total time (travel + charging).
- **Request Body**:
```json
{
  "currentLat": 21.0285,
  "currentLng": 105.8542,
  "batteryLevel": 20,
  "batteryCapacity": 60,
  "targetChargeLevel": 80,
  "maxRadiusKm": 50
}
```
- **Response**: `200 OK`
```json
{
  "recommendations": [
    {
      "stationId": "uuid",
      "name": "Station Name",
      "totalTimeMinutes": 45,
      "travelTimeMinutes": 15,
      "chargingTimeMinutes": 30,
      "distanceKm": 10
    }
  ]
}
```

#### Get Availability
- **Method**: `GET`
- **Path**: `/api/ev/stations/{stationId}/availability`
- **Description**: Get slot availability matrix for charger units on a specific date
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Query Parameters**:
  - `date` (required): Date (YYYY-MM-DD)
  - `tz` (optional, default: "Asia/Bangkok"): Timezone
  - `slotMinutes` (optional, default: 30): Slot duration in minutes
  - `powerType` (optional): Filter by power type (DC or AC)
  - `minPowerKw` (optional): Minimum power in kW
- **Response**: `200 OK`
```json
{
  "stationId": "uuid",
  "date": "2024-01-01",
  "slots": [
    {
      "chargerUnitId": "uuid",
      "timeSlots": [
        {
          "startTime": "08:00",
          "endTime": "08:30",
          "available": true
        }
      ]
    }
  ]
}
```

#### Get Charger Units
- **Method**: `GET`
- **Path**: `/api/ev/stations/{stationId}/charger-units`
- **Description**: Get all active charger units for a published station
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Response**: `200 OK`
```json
[
  {
    "chargerUnitId": "uuid",
    "portId": "uuid",
    "powerKw": 250,
    "powerType": "DC",
    "connectorType": "CCS2"
  }
]
```

### Bookings

#### Create Booking
- **Method**: `POST`
- **Path**: `/api/ev/bookings`
- **Description**: Create a booking with HOLD status. Hold expires in 10 minutes. Station must exist and have a published version.
- **Request Body**:
```json
{
  "stationId": "uuid",
  "chargerUnitId": "uuid",
  "startTime": "2024-01-01T08:00:00Z",
  "endTime": "2024-01-01T09:00:00Z"
}
```
- **Response**: `201 Created`
```json
{
  "bookingId": "uuid",
  "stationId": "uuid",
  "status": "HOLD",
  "startTime": "2024-01-01T08:00:00Z",
  "endTime": "2024-01-01T09:00:00Z",
  "expiresAt": "2024-01-01T08:10:00Z"
}
```

#### Get My Bookings
- **Method**: `GET`
- **Path**: `/api/ev/bookings/mine`
- **Description**: Get all bookings for the current user, paginated
- **Query Parameters**:
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`

#### Get Booking by ID
- **Method**: `GET`
- **Path**: `/api/ev/bookings/{id}`
- **Description**: Get a specific booking by ID (only if it belongs to the current user)
- **Path Parameters**:
  - `id` (required): Booking UUID
- **Response**: `200 OK`

#### Cancel Booking
- **Method**: `POST`
- **Path**: `/api/ev/bookings/{id}/cancel`
- **Description**: Cancel a booking. Allowed when status is HOLD or CONFIRMED.
- **Path Parameters**:
  - `id` (required): Booking UUID
- **Response**: `200 OK`

### Payments

#### Create Payment Intent
- **Method**: `POST`
- **Path**: `/api/ev/bookings/{bookingId}/payment-intent`
- **Description**: Create a payment intent for a HOLD booking. Booking must be HOLD status and not expired. Only one payment intent can exist per booking.
- **Path Parameters**:
  - `bookingId` (required): Booking UUID
- **Response**: `201 Created`
```json
{
  "intentId": "uuid",
  "bookingId": "uuid",
  "amount": 100000,
  "currency": "VND",
  "status": "PENDING"
}
```

#### Simulate Payment Success
- **Method**: `POST`
- **Path**: `/api/ev/payments/{intentId}/simulate-success`
- **Description**: Simulate a successful payment. Sets payment intent to SUCCEEDED and transitions booking HOLD -> CONFIRMED. Idempotent: calling twice returns the same result.
- **Path Parameters**:
  - `intentId` (required): Payment Intent UUID
- **Response**: `200 OK`

#### Simulate Payment Failure
- **Method**: `POST`
- **Path**: `/api/ev/payments/{intentId}/simulate-fail`
- **Description**: Simulate a failed payment. Sets payment intent to FAILED. Booking remains HOLD until it expires.
- **Path Parameters**:
  - `intentId` (required): Payment Intent UUID
- **Response**: `200 OK`

### Change Requests

#### Create Change Request
- **Method**: `POST`
- **Path**: `/api/ev/change-requests`
- **Description**: Create a new change request for CREATE_STATION or UPDATE_STATION. Status will be DRAFT.
- **Request Body**:
```json
{
  "type": "CREATE_STATION",
  "stationData": {
    "name": "Station Name",
    "address": "Station Address",
    "latitude": 21.0285,
    "longitude": 105.8542,
    "operatingHours": "24/7",
    "parking": "Paid",
    "stationType": "Public",
    "services": [...],
    "chargingPorts": [...]
  }
}
```
- **Response**: `201 Created`

#### Submit Change Request
- **Method**: `POST`
- **Path**: `/api/ev/change-requests/{id}/submit`
- **Description**: Submit a DRAFT change request for review. Status changes from DRAFT to PENDING.
- **Path Parameters**:
  - `id` (required): Change request UUID
- **Response**: `200 OK`

#### Get My Change Requests
- **Method**: `GET`
- **Path**: `/api/ev/change-requests/mine`
- **Description**: Get all change requests submitted by the current user
- **Response**: `200 OK`

#### Get Change Request
- **Method**: `GET`
- **Path**: `/api/ev/change-requests/{id}`
- **Description**: Get details of a specific change request by ID
- **Path Parameters**:
  - `id` (required): Change request UUID
- **Response**: `200 OK`

### Issues

#### Report Issue
- **Method**: `POST`
- **Path**: `/api/ev/stations/{stationId}/issues`
- **Description**: Report a data discrepancy (location, price, hours, ports, other) on a published station
- **Path Parameters**:
  - `stationId` (required): Station UUID
- **Request Body**:
```json
{
  "category": "LOCATION",
  "description": "Location is incorrect",
  "suggestedFix": "Update coordinates"
}
```
- **Response**: `201 Created`

#### Get My Issues
- **Method**: `GET`
- **Path**: `/api/ev/issues/mine`
- **Description**: Get all issues reported by the current user
- **Response**: `200 OK`

---

## Collaborator APIs

**Base Path**: `/api/collab`  
**Required Role**: `COLLABORATOR`

### Collaborator Web

#### Test Endpoint
- **Method**: `GET`
- **Path**: `/api/collab/web/test`
- **Description**: Test endpoint for Collaborator Web API
- **Response**: `200 OK`
```json
{
  "message": "Collaborator Web API is accessible"
}
```

#### Get My Profile
- **Method**: `GET`
- **Path**: `/api/collab/web/me/profile`
- **Description**: Get the current collaborator's profile
- **Response**: `200 OK`
```json
{
  "id": "uuid",
  "userAccountId": "uuid",
  "phone": "+84123456789",
  "address": "Address"
}
```

#### Get My Contracts
- **Method**: `GET`
- **Path**: `/api/collab/web/me/contracts`
- **Description**: Get the current collaborator's contracts with active flag
- **Response**: `200 OK`
```json
[
  {
    "id": "uuid",
    "collaboratorId": "uuid",
    "startDate": "2024-01-01",
    "endDate": "2024-12-31",
    "region": "Hanoi",
    "active": true
  }
]
```

#### Update My Location (Manual)
- **Method**: `PUT`
- **Path**: `/api/collab/web/me/location`
- **Description**: Update the current collaborator's location manually from web interface
- **Request Body**:
```json
{
  "lat": 21.0285,
  "lng": 105.8542
}
```
- **Response**: `200 OK`

### Collaborator Mobile

#### Test Endpoint
- **Method**: `GET`
- **Path**: `/api/collab/mobile/test`
- **Description**: Test endpoint for Collaborator Mobile API
- **Response**: `200 OK`
```json
{
  "message": "Collaborator Mobile API is accessible"
}
```

#### Update My Location (GPS)
- **Method**: `PUT`
- **Path**: `/api/collab/mobile/me/location`
- **Description**: Update the current collaborator's location from mobile device GPS
- **Request Body**:
```json
{
  "lat": 21.0285,
  "lng": 105.8542
}
```
- **Response**: `200 OK`

### Verification Tasks (Web)

#### Get Tasks with Filters
- **Method**: `GET`
- **Path**: `/api/collab/web/tasks`
- **Description**: Get verification tasks assigned to the current collaborator with optional filters for status, priority, and SLA
- **Query Parameters**:
  - `status` (optional): Filter by status (OPEN, ASSIGNED, CHECKED_IN, SUBMITTED, REVIEWED)
  - `priority` (optional): Filter by priority (1-5)
  - `slaDueBefore` (optional): Filter by SLA due date (ISO format)
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`

#### Get Task History
- **Method**: `GET`
- **Path**: `/api/collab/web/tasks/history`
- **Description**: Get reviewed (completed) verification tasks for the current collaborator
- **Query Parameters**:
  - `page` (optional, default: 0): Page number
  - `size` (optional, default: 20): Page size
- **Response**: `200 OK`

#### Get KPI Summary
- **Method**: `GET`
- **Path**: `/api/collab/web/tasks/kpi`
- **Description**: Get simple KPI: count of reviewed tasks PASS/FAIL for the current month
- **Response**: `200 OK`
```json
{
  "month": "2024-01",
  "totalReviewed": 10,
  "passed": 8,
  "failed": 2,
  "passRate": 80.0
}
```

### Verification Tasks (Mobile)

#### Get Assigned Tasks
- **Method**: `GET`
- **Path**: `/api/collab/mobile/tasks`
- **Description**: Get verification tasks assigned to the current collaborator with status ASSIGNED, CHECKED_IN, or SUBMITTED
- **Query Parameters**:
  - `status` (optional): Filter by status (can be multiple, comma-separated)
- **Response**: `200 OK`
```json
[
  {
    "id": "uuid",
    "stationId": "uuid",
    "status": "ASSIGNED",
    "priority": 1,
    "slaDueAt": "2024-01-01T12:00:00Z"
  }
]
```

#### Check-in at Station
- **Method**: `POST`
- **Path**: `/api/collab/mobile/tasks/{id}/check-in`
- **Description**: Check-in at the station location. Must be within 200 meters of the published station location. Requires task status to be ASSIGNED.
- **Path Parameters**:
  - `id` (required): Verification task UUID
- **Request Body**:
```json
{
  "lat": 21.0285,
  "lng": 105.8542
}
```
- **Response**: `200 OK`

---

## Error Codes

### Common HTTP Status Codes

- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `204 No Content`: Request successful, no content to return
- `400 Bad Request`: Invalid request parameters or body
- `401 Unauthorized`: Missing or invalid authentication token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error

### Business Error Codes

- `VALIDATION_ERROR`: Request validation failed
- `NOT_FOUND`: Resource not found
- `UNAUTHORIZED`: Authentication required
- `FORBIDDEN`: Insufficient permissions
- `BUSINESS_RULE_VIOLATION`: Business rule violation
- `DUPLICATE_ENTRY`: Duplicate resource
- `INVALID_STATE`: Invalid state transition

---

## Notes

1. All timestamps are in ISO 8601 format (UTC)
2. All UUIDs are in standard UUID format
3. Pagination uses 0-based indexing
4. JWT tokens expire after a configured time (check application settings)
5. File uploads use `multipart/form-data` content type
6. All monetary values are in VND (Vietnamese Dong)
7. Coordinates use WGS84 (latitude/longitude)
8. Time zones default to "Asia/Bangkok" if not specified

---

**Last Updated**: 2024-01-01  
**API Version**: 1.0

