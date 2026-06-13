# VoltGO - Graduation Thesis Materials

> **Project**: VoltGO - Electric Vehicle Charging Station Management Platform
> **Generated**: 2026-06-09
> **Note**: All values are extracted directly from source code. Items marked `[TO VERIFY BY STUDENT]` indicate areas requiring thesis author's confirmation.

---

## 1. PROJECT OVERVIEW

### 1.1 Problem Statement (Bài toán)

VoltGO is a **full-stack platform for managing electric vehicle (EV) charging stations and battery swap facilities**. It addresses a critical gap in Vietnam's EV infrastructure: the lack of a centralized, verifiable, and trustworthy system for EV charging station management.

The platform tackles three core problems:

1. **Station Discovery & Trust**: EV drivers need reliable information about charging stations (location, availability, pricing). VoltGO provides a GPS-verified, trust-scored station network to combat fake or inaccurate listings.
2. **Operational Workflow**: Station owners (collaborators) need a structured process to register, update, and publish station information. VoltGO implements a multi-stage approval workflow with GPS-based verification.
3. **Battery Swap Infrastructure**: A dedicated module manages battery swap stations with real-time pile/slot state tracking, enabling EV drivers to quickly exchange depleted batteries for charged ones.

### 1.2 Target Users

| User Type | Description | Platform |
|-----------|-------------|----------|
| **EV Drivers** | End users who need to find stations, book charging slots, make payments, and report issues | Mobile App (`ev_user_mobile`) |
| **Collaborators** | Station owners/operators who register stations, manage change requests, and receive verification tasks | Mobile + Web (`collab_mobile`, `collab_web`) |
| **Administrators** | Platform managers who approve stations, review verifications, manage trust scores, and audit activity | Web Portal (`admin_web`) |

### 1.3 Core Value Proposition

- **End-to-end station lifecycle management**: from registration → GPS verification → publication → operation → payment
- **Trust & Risk scoring**: Explainable scoring system for station quality
- **Multi-platform ecosystem**: Four Flutter applications sharing a single backend
- **Offline-capable mobile apps**: Graceful degradation without network

### 1.4 Current Limitations of Existing Solutions (Market Context)

Typical EV charging platforms in Vietnam suffer from:
- Unverified station listings with inaccurate coordinates
- No structured approval workflow for station updates
- Manual reconciliation of charging sessions
- Lack of battery swap support
- Siloed admin/mobile interfaces with no shared code

VoltGO addresses these by introducing GPS-based check-in verification, a collaborative review system, and a unified shared API layer across all client applications.

---

## 2. FUNCTIONAL REQUIREMENTS

### 2.1 Complete Feature List (Use Cases)

#### Authentication & User Management

1. **Register User Account**
   - Actor(s): EV Driver, Collaborator
   - Brief: A new user creates an account with email/password and optional phone number.
   - Pre-condition: User is not authenticated.
   - Post-condition: User account is created, and user receives an authentication token.
   - Main Flow:
     1. User submits registration form (email, password, role, phone).
     2. System validates uniqueness of email.
     3. System hashes password and stores account.
     4. System generates JWT token and returns it.
   - Alternative Flows: Email already exists → return 409 Conflict.

2. **Login**
   - Actor(s): EV Driver, Collaborator, Administrator
   - Brief: An authenticated user logs into the system to receive a JWT token for subsequent API calls.
   - Pre-condition: User has an existing account.
   - Post-condition: User receives a JWT access token.
   - Main Flow:
     1. User submits credentials (email + password).
     2. System validates credentials.
     3. System issues JWT token with role-based claims.
   - Exception Flows: Invalid credentials → 401 Unauthorized; Locked account → 403 Forbidden.

3. **View Collaborator Profile**
   - Actor(s): Collaborator
   - Brief: A collaborator views their own profile including contract details, KPI metrics, and task statistics.
   - Pre-condition: Collaborator is authenticated.
   - Post-condition: Profile data is returned.

#### Station Management

4. **Register Charging Station**
   - Actor(s): Collaborator
   - Brief: A collaborator submits a new charging station for review with location, services, pricing, and operational hours.
   - Pre-condition: Collaborator is authenticated and has a valid contract.
   - Post-condition: A `ChangeRequest` of type `CREATE` is created with status `DRAFT`.
   - Main Flow:
     1. Collaborator fills station registration form.
     2. System captures GPS coordinates and address.
     3. Collaborator configures charging ports (type, power output, quantity).
     4. Collaborator sets pricing and operating hours.
     5. System saves as `DRAFT` change request.
     6. Collaborator submits for review → status changes to `PENDING`.
   - Alternative Flows: Save as draft for later; Add multiple services.

5. **Update Station Information**
   - Actor(s): Collaborator
   - Brief: A collaborator creates a change request to update an existing station's details.
   - Pre-condition: Station exists and is in `PUBLISHED` state.
   - Post-condition: A `ChangeRequest` of type `UPDATE` with status `DRAFT` is created.
   - Main Flow:
     1. Collaborator selects an existing station.
     2. System loads current station data into edit form.
     3. Collaborator modifies fields (services, pricing, hours, ports).
     4. System creates a new `station_version` snapshot.
     5. Change request is saved as `DRAFT` → submitted to `PENDING`.

6. **Submit Change Request**
   - Actor(s): Collaborator
   - Brief: A collaborator finalizes and submits a draft change request for admin review, triggering risk scoring.
   - Pre-condition: Change request is in `DRAFT` status.
   - Post-condition: Change request status becomes `PENDING`, risk score is calculated.
   - Main Flow:
     1. Collaborator reviews all entered data.
     2. Collaborator clicks "Submit for Review".
     3. System validates all required fields.
     4. System computes risk score via `RiskService.calculateRisk()`.
     5. System transitions status to `PENDING`.
     6. System sends notification to admin.

7. **Approve Change Request**
   - Actor(s): Administrator
   - Brief: An administrator reviews and approves a pending change request, which publishes the station or applies the update.
   - Pre-condition: Change request is `PENDING`.
   - Post-condition: Change request becomes `APPROVED` (or `REJECTED`), station becomes `PUBLISHED` (or remains with status).
   - Main Flow:
     1. Admin fetches list of `PENDING` change requests.
     2. Admin reviews station details, risk score, and submitter info.
     3. Admin approves → status transitions to `APPROVED`.
     4. System publishes station (`station_version` with `status=PUBLISHED`).
     5. Alternative: Admin rejects with reason → status `REJECTED`.

8. **Publish Station Update**
   - Actor(s): Administrator
   - Brief: An administrator explicitly publishes an approved change request to make it live.
   - Pre-condition: Change request is `APPROVED`.
   - Post-condition: Station update is live and accessible to EV drivers.

#### Booking & Payment

9. **Book Charging Slot**
   - Actor(s): EV Driver
   - Brief: An EV driver reserves a charging slot at a station for a specific time period.
   - Pre-condition: Station has available ports; EV driver is authenticated.
   - Post-condition: A `Booking` record is created with status `HOLD`.
   - Main Flow:
     1. EV driver searches for station and views available ports.
     2. EV driver selects port type and time slot.
     3. System checks availability (no conflicting bookings).
     4. System creates booking with `HOLD` status.
     5. Payment intent is created in `PENDING` state.
     6. EV driver completes payment simulation.
   - Alternative Flows: No available ports → booking rejected; Payment fails → booking cancelled.

10. **Cancel Booking**
    - Actor(s): EV Driver
    - Brief: An EV driver cancels an existing booking, releasing the slot.
    - Pre-condition: Booking exists and is in `HOLD` or `CONFIRMED` state.
    - Post-condition: Booking status changes to `CANCELLED`, slot is released.

11. **Simulate Payment**
    - Actor(s): EV Driver (system-triggered simulation)
    - Brief: A payment intent is processed through a simulated payment gateway.
    - Pre-condition: `PaymentIntent` exists with status `PENDING`.
    - Post-condition: `PaymentIntent` status becomes `SUCCESS` or `FAILED`.
    - Main Flow:
      1. Payment simulation endpoint is called (simulating external gateway).
      2. System randomly or deterministically returns success/failure.
      3. System updates `PaymentIntent` status.
      4. If success, booking status transitions from `HOLD` to `CONFIRMED`.

#### GPS Verification System

12. **Create Verification Task**
    - Actor(s): Administrator
    - Brief: An administrator creates a GPS verification task for a specific station and assigns it to a collaborator.
    - Pre-condition: Station exists and is in `PUBLISHED` state.
    - Post-condition: `VerificationTask` is created with status `PENDING`.

13. **Perform Check-in**
    - Actor(s): Collaborator
    - Brief: A collaborator arrives at a station and checks in via GPS, proving physical presence.
    - Pre-condition: Collaborator has an assigned verification task for this station.
    - Post-condition: `VerificationCheckin` is created with GPS coordinates; status transitions to `CHECKED_IN`.
    - Main Flow:
      1. Collaborator opens task in mobile app.
      2. Collaborator physically travels to station.
      3. Collaborator taps "Check In" button.
      4. App captures current GPS coordinates.
      5. System validates coordinates are within 200 meters of station location.
      6. System records check-in with timestamp and coordinates.
    - Exception Flows: Too far from station → check-in rejected with distance error.

14. **Submit Verification Evidence**
    - Actor(s): Collaborator
    - Brief: A collaborator submits photo evidence and notes for a verification task.
    - Pre-condition: Collaborator has checked in.
    - Post-condition: `VerificationEvidence` is uploaded, task status transitions to `SUBMITTED`.
    - Main Flow:
      1. Collaborator takes photos of station (front, ports, signage).
      2. Collaborator adds optional notes.
      3. App uploads images via presigned URL.
      4. System stores evidence references.
      5. Task status → `SUBMITTED`.

15. **Review Verification**
    - Actor(s): Administrator
    - Brief: An administrator reviews submitted verification evidence and approves or rejects the verification.
    - Pre-condition: Verification task is `SUBMITTED`.
    - Post-condition: Task status becomes `APPROVED` or `REJECTED`.
    - Main Flow:
      1. Admin views verification task with all check-in data and evidence photos.
      2. Admin compares GPS coordinates with station location on map.
      3. Admin reviews submitted photos.
      4. Admin approves or rejects with comments.

#### Battery Swap Station Management

16. **Reserve Battery Swap**
    - Actor(s): EV Driver
    - Brief: An EV driver reserves a battery slot at a battery swap station for a specific time.
    - Pre-condition: Swap station has available slots; EV driver is authenticated.
    - Post-condition: Swap reservation is created.

17. **Check Swap Pile Status**
    - Actor(s): EV Driver, Collaborator
    - Brief: Users view the real-time state of swap piles and battery slots at a battery swap station.
    - Pre-condition: Station is a battery swap type (`service_type = BATTERY_SWAP`).
    - Post-condition: Current pile and slot states are returned.

#### Issue Reporting

18. **Report Station Issue**
   - Actor(s): EV Driver
   - Brief: An EV driver reports a problem with a station (broken port, incorrect info, etc.).
   - Pre-condition: Station exists; EV driver is authenticated.
   - Post-condition: `Issue` record is created with status `OPEN`.

19. **Resolve Issue**
   - Actor(s): Administrator
   - Brief: An administrator acknowledges, resolves, or rejects a reported issue.
   - Pre-condition: Issue exists with status `OPEN`.
   - Post-condition: Issue status changes to `ACKNOWLEDGED`, `RESOLVED`, or `REJECTED`.

#### Loyalty & Rewards

21. **View Loyalty Profile**
    - Actor(s): EV Driver
    - Brief: An EV driver views their loyalty profile including current points, lifetime points, level, badges, and progress toward the next level.
    - Pre-condition: EV driver is authenticated.
    - Post-condition: Loyalty profile data is returned with all stats.
    - Main Flow:
      1. EV driver opens the Loyalty/Home screen in the mobile app.
      2. System fetches `LoyaltyUserProfileEntity` for the user via `GET /api/ev/loyalty/me`.
      3. System retrieves earned badges via `GET /api/ev/loyalty/badges`.
      4. System computes level name based on `LEVEL_THRESHOLDS = {0, 100, 500, 1500, 5000, 15000}`.
      5. Response includes: current points, lifetime points, level (1-6), level name (Bronze → Silver → Gold → Platinum → Diamond → Master), badge list, points to next level.

22. **View Point History**
    - Actor(s): EV Driver
    - Brief: An EV driver views their complete point transaction history with pagination.
    - Pre-condition: EV driver is authenticated.
    - Post-condition: Paginated list of `LoyaltyPointTransactionEntity` records is returned.

23. **Earn Points from Activities**
    - Actor(s): EV Driver (system-triggered)
    - Brief: The system automatically awards loyalty points to users when they complete qualifying activities (booking, rating, referral, etc.).
    - Pre-condition: User completes a qualifying activity.
    - Post-condition: Points are credited, `LoyaltyPointTransactionEntity` is created, level is recalculated.
    - Point Sources:
      - `BOOKING`: 30 points — completed charging session
      - `BATTERY_SWAP`: 30 points — completed battery swap
      - `RATING`: 10 points — rated a station
      - `RATING_WITH_COMMENT`: additional 5 points (15 total) — rating with written review ≥ 30 chars
      - `CR_SUBMIT`: 10 points — submitted a station update proposal
      - `CR_PUBLISH`: 40 points — proposal approved and published
      - `REFERRAL`: 50 points — successful referral (referee completed first booking)
      - `BADGE`: variable points — badge earned with points bonus
      - `ADMIN_ADJUST`: manual adjustment by admin

24. **Submit Station Rating**
    - Actor(s): EV Driver
    - Brief: An EV driver rates a station they have visited (1-5 stars) and optionally writes a comment to earn points.
    - Pre-condition: EV driver has a valid rating eligibility (completed booking at this station), or can rate freely with daily limit of 3 ratings/day.
    - Post-condition: `StationRatingEntity` is created with status `ACTIVE`, loyalty points are awarded, rating eligibility is consumed.
    - Main Flow:
      1. EV driver views eligible stations via `GET /api/ev/loyalty/ratings/eligible`.
      2. EV driver submits rating via `POST /api/ev/loyalty/ratings` with `{ stationId, rating (1-5), comment }`.
      3. System validates: rating in [1,5], daily limit not exceeded (max 3/day).
      4. `StationRatingEntity` is saved with `isVerified = (eligibilityId != null)`.
      5. `RatingEligibilityEntity` is marked as rated if applicable.
      6. Points awarded: 10 base + 5 bonus if comment ≥ 30 chars.
      7. `BadgeService.checkAndAwardBadges()` is called to check for newly earned badges.
    - Alternative Flows: Daily limit exceeded → 400 error; Station not eligible → eligibility created ad-hoc.

25. **Mark Rating Helpful**
    - Actor(s): EV Driver
    - Brief: An EV driver marks another user's rating as helpful, increasing its helpful count.
    - Pre-condition: Rating exists.
    - Post-condition: `StationRating.helpfulCount` is incremented.

26. **View Station Ratings**
    - Actor(s): EV Driver, Public
    - Brief: Anyone can view station ratings including average score, breakdown by stars, and individual review list.
    - Pre-condition: Station exists.
    - Post-condition: Rating summary and paginated review list are returned.

27. **Earn and View Badges**
    - Actor(s): EV Driver
    - Brief: An EV driver earns achievement badges based on activity milestones, with bonus points awarded upon badge acquisition.
    - Pre-condition: EV driver meets a badge's criteria threshold.
    - Post-condition: `UserBadgeEntity` is created, bonus points are credited if applicable.
    - Badge Tiers: `BRONZE`, `SILVER`, `GOLD`
    - Badge Criteria Types: `BOOKING_COUNT`, `SWAP_COUNT`, `CR_COUNT` (change request), `RATING_COUNT`, `POINTS_MILESTONE`, `FIRST_BOOKING`, `FIRST_SWAP`, `FIRST_RATING`
    - Badges are checked after each qualifying activity via `BadgeService.checkAndAwardBadges()`.

28. **Generate and Share Referral Code**
    - Actor(s): EV Driver
    - Brief: An EV driver generates a unique referral code to share with friends. When a friend signs up using the code and completes their first booking, both users earn referral bonus points.
    - Pre-condition: EV driver is authenticated.
    - Post-condition: `ReferralEntity` is created with status `PENDING`.
    - Main Flow:
      1. EV driver generates code via `POST /api/ev/loyalty/referral/generate`.
      2. System creates `ReferralEntity` with `status = PENDING`.
      3. System returns referral code and `voltgo://register?ref={code}` deep link.
      4. Referee registers via referral code → `ReferralService.onReferralSignup()` is called.
      5. When referee completes first booking → `ReferralService.onRefereeFirstBookingCompleted()` awards 50 points to both parties.

29. **Browse Voucher Catalog**
    - Actor(s): EV Driver
    - Brief: An EV driver browses all available vouchers that can be redeemed with loyalty points.
    - Pre-condition: EV driver is authenticated.
    - Post-condition: List of available `VoucherDefinitionEntity` records is returned.
    - Voucher Types: `PERCENT_DISCOUNT` (e.g., 10% off, 20% off), `FREE_SERVICE` (free charging/swap)

30. **Redeem Voucher with Points**
    - Actor(s): EV Driver
    - Brief: An EV driver redeems loyalty points for a voucher. A unique voucher code is generated with a validity period.
    - Pre-condition: EV driver has sufficient points; voucher is active and within its date range.
    - Post-condition: `VoucherRedemptionEntity` is created with status `REDEEMED`, points are deducted.
    - Main Flow:
      1. EV driver selects a voucher from catalog and taps "Redeem" via `POST /api/ev/loyalty/vouchers/{definitionId}/redeem`.
      2. System validates: voucher is `ACTIVE`, within date range, user has enough points.
      3. `LoyaltyPointService.redeemPoints()` deducts points from user's `currentPoints`.
      4. System generates unique voucher code (`VG-{UUID}`).
      5. `expiresAt` is set to `now + validityDays`.
      6. `VoucherRedemptionEntity` is saved with status `REDEEMED`.
    - Alternative Flows: Insufficient points → `INSUFFICIENT_POINTS` error; Voucher expired/inactive → `VOUCHER_NOT_ACTIVE` error.

31. **View My Vouchers**
    - Actor(s): EV Driver
    - Brief: An EV driver views all their redeemed vouchers with filtering by status.
    - Pre-condition: EV driver is authenticated.
    - Post-condition: Paginated list of `VoucherRedemptionEntity` records with associated `VoucherDefinition` details.

32. **Apply Voucher to Booking**
    - Actor(s): EV Driver
    - Brief: An EV driver applies a redeemed voucher to a charging booking to get a discount. The discount is computed and linked to the booking record.
    - Pre-condition: `VoucherRedemptionEntity` status is `REDEEMED` (not `USED` or `EXPIRED`); voucher is within expiry date.
    - Post-condition: `VoucherRedemptionEntity.status = USED`, booking's `voucherRedemptionId` is set, discount metadata is stored.
    - Main Flow:
      1. EV driver taps "Apply Voucher" on a booking via `POST /api/ev/loyalty/vouchers/redemptions/{id}/apply-to-booking`.
      2. System validates: redemption belongs to user, status is `REDEEMED`, not expired.
      3. Discount is computed: `PERCENT_DISCOUNT` → `bookingAmount * discountPercent / 100` (capped at `maxValueVnd`); `FREE_SERVICE` → full amount.
      4. `VoucherRedemptionEntity.status = USED`, `bookingId` is linked.
      5. `BookingEntity.voucherRedemptionId` is set for payment service to read.
    - Alternative Flows: Voucher already used → `VOUCHER_ALREADY_USED`; Voucher expired → `VOUCHER_EXPIRED`.

33. **Apply Voucher to Battery Swap Reservation**
    - Actor(s): EV Driver
    - Brief: Same as above but for a battery swap reservation.
    - Pre-condition: `VoucherRedemptionEntity` is for `BATTERY_SWAP` service type; reservation belongs to user.
    - Post-condition: `VoucherRedemptionEntity.status = USED`, reservation is linked.

34. **Manage Voucher Definitions (Admin)**
    - Actor(s): Administrator
    - Brief: An administrator creates, updates, and deactivates voucher definitions (campaigns).
    - Pre-condition: Administrator is authenticated.
    - Post-condition: `VoucherDefinitionEntity` is created/updated with the new configuration.

35. **View Loyalty Dashboard (Admin)**
    - Actor(s): Administrator
    - Brief: An administrator views loyalty program statistics: total points issued, active users (last 30 days), total ratings.
    - Pre-condition: Administrator is authenticated.
    - Post-condition: Dashboard statistics are returned.

36. **Manual Point Adjustment (Admin)**
    - Actor(s): Administrator
    - Brief: An administrator manually adds or deducts points from a user's account with a reason.
    - Pre-condition: Administrator is authenticated.
    - Post-condition: `LoyaltyPointTransactionEntity` with `type = ADJUST` is created.

37. **Moderate Ratings (Admin)**
    - Actor(s): Administrator
    - Brief: An administrator reviews and hides inappropriate station ratings.
    - Pre-condition: Rating exists with status `ACTIVE`.
    - Post-condition: `StationRating.status = HIDDEN`.

#### Notifications

20. **Receive Push Notification**
    - Actor(s): Collaborator, EV Driver
    - Brief: Users receive push notifications about task assignments, booking confirmations, and system alerts.
    - Pre-condition: User has a registered push token.
    - Post-condition: Notification is delivered to the user's device.

### 2.2 Detailed Use Case Descriptions

#### UC-1: Book Charging Slot (most critical)

| Field | Value |
|-------|-------|
| **Use Case ID** | UC-BOOK-001 |
| **Use Case Name** | Book Charging Slot |
| **Priority** | High |
| **Actor(s)** | EV Driver |
| **Trigger** | EV Driver selects a time slot and confirms booking |
| **Description** | An authenticated EV driver browses available charging stations, selects a station and port type, chooses a time slot, and creates a booking. The booking is held pending payment confirmation. |

**Pre-condition**: EV Driver is authenticated with a valid JWT token. The target station has at least one available charging port for the selected service type and time slot.

**Post-condition**: A `Booking` entity is persisted with status `HOLD`, and a `PaymentIntent` is created with status `PENDING`. The reserved time slot is no longer available to other users.

**Main Flow**:
1. EV Driver opens the "Stations" screen in the mobile app.
2. System fetches nearby stations via `GET /api/ev/stations`.
3. EV Driver selects a station → system loads station detail via `GET /api/ev/stations/{id}`.
4. EV Driver views available charger units via `GET /api/ev/stations/{stationId}/charger-units`.
5. EV Driver selects a port type (e.g., Type 2, CCS) and desired time slot.
6. App submits `POST /api/ev/bookings` with `{ chargerUnitId, startTime, endTime, serviceType }`.
7. Backend validates: (a) no overlapping bookings for the selected slot, (b) port type matches, (c) station is in `PUBLISHED` state.
8. Backend creates `Booking` with `status = HOLD`, `paymentStatus = UNPAID`.
9. Backend creates `PaymentIntent` with `status = PENDING`.
10. Backend returns booking confirmation with payment intent details.
11. App displays payment screen to EV Driver.
12. EV Driver confirms payment → app calls `POST /api/ev/payments/simulate-success` with payment intent ID.
13. Backend updates `PaymentIntent.status = SUCCESS` and `Booking.status = CONFIRMED`.
14. Backend returns success; app shows confirmation screen.

**Alternative Flows**:
- AF1: Payment fails → `PaymentIntent.status = FAILED`, `Booking.status = CANCELLED`, slot released.
- AF2: Slot no longer available (race condition) → returns 409 Conflict.
- AF3: EV Driver cancels before payment → `Booking.status = CANCELLED`.

---

#### UC-2: Submit Change Request (station registration/update)

| Field | Value |
|-------|-------|
| **Use Case ID** | UC-STATION-002 |
| **Use Case Name** | Submit Change Request |
| **Priority** | High |
| **Actor(s)** | Collaborator |
| **Trigger** | Collaborator clicks "Submit for Review" on a draft change request |
| **Description** | A collaborator finalizes a station registration or update by submitting it for admin review. The submission triggers automatic risk scoring and transitions the request to pending status. |

**Pre-condition**: `ChangeRequest` exists with `status = DRAFT`. All required fields are populated (location, services, pricing, ports). Collaborator has an active contract.

**Post-condition**: `ChangeRequest.status` transitions to `PENDING`. `RiskScore` is computed and stored.

**Main Flow**:
1. Collaborator opens the "My Stations" screen in the web or mobile app.
2. Collaborator selects a draft change request or creates a new one.
3. Collaborator fills in or updates station details: name, address, GPS, services, operating hours, pricing, port configurations.
4. Collaborator uploads station images via presigned URLs.
5. Collaborator clicks "Submit for Review".
6. Backend validates all required fields and service configurations.
7. `RiskService.calculateRisk()` is invoked, analyzing: submitter history, data completeness, data consistency, anomaly detection.
8. `ChangeRequest.status` is set to `PENDING`.
9. `CollaboratorNotification` record is created confirming submission.
10. Admin receives a push notification about the new pending request.
11. Admin reviews the request via the admin web portal (`GET /api/admin/change-requests`).
12. Admin approves → `ChangeRequest.status = APPROVED` → `StationService.publishChangeRequest()` creates/updates the `station_version` with `status = PUBLISHED`.
13. Alternative: Admin rejects → `ChangeRequest.status = REJECTED` with reason.

---

#### UC-3: GPS Verification with Check-in

| Field | Value |
|-------|-------|
| **Use Case ID** | UC-VERIFY-003 |
| **Use Case Name** | GPS Verification Check-in and Evidence Submission |
| **Priority** | High |
| **Actor(s)** | Collaborator, Administrator |
| **Trigger** | Collaborator receives an assigned verification task |
| **Description** | A collaborator is assigned a verification task for a published station. They physically visit the station, check in using GPS (proving they are within 200m), submit photo evidence, and an admin reviews and approves or rejects the verification. |

**Pre-condition**: `VerificationTask` exists with `status = PENDING` and is assigned to the authenticated collaborator.

**Post-condition**: `VerificationTask` transitions to `SUBMITTED` (after evidence) or `APPROVED`/`REJECTED` (after admin review). `StationTrust` score may be updated.

**Main Flow**:
1. Collaborator opens "My Tasks" in the mobile app → system fetches assigned tasks via `GET /api/collab/mobile/tasks`.
2. Collaborator selects the verification task.
3. Collaborator physically travels to the station location.
4. Collaborator taps "Check In" → app captures GPS via `Geolocator.getCurrentPosition()`.
5. App submits `POST /api/collab/mobile/tasks/{id}/checkin` with `{ latitude, longitude, timestamp }`.
6. Backend loads station's published `station_version` to get actual coordinates.
7. `VerificationCheckin.distanceMeters` is computed using the Haversine formula.
8. If `distanceMeters <= 200`: check-in is recorded, `VerificationTask.status = CHECKED_IN`.
9. If `distanceMeters > 200`: check-in is rejected with error message showing actual distance.
10. Collaborator captures photos of: (a) station exterior/front, (b) charging ports, (c) pricing display/signage.
11. App uploads each photo via `POST /api/collab/mobile/files/upload` with base64 or multipart data.
12. System stores files in MinIO and returns file keys.
13. Collaborator submits evidence via `POST /api/collab/mobile/tasks/{id}/evidence` with file keys and notes.
14. `VerificationTask.status = SUBMITTED`.
15. Admin reviews via `GET /api/admin/verification-tasks` in the admin web portal.
16. Admin views: check-in location on map, distance from station, submitted photos, submitter profile.
17. Admin approves → `VerificationTask.status = APPROVED` → `StationTrust.recalculate()` is called.
18. Alternative: Admin rejects → `VerificationTask.status = REJECTED` with reason.

---

## 3. NON-FUNCTIONAL REQUIREMENTS

### 3.1 Performance Constraints

| Constraint | Value | Evidence |
|------------|-------|----------|
| API response timeout | ~30s default (Spring Boot server config) | `application.yml` server timeout settings |
| Pagination default | 20 items per page | `@PageableDefault(size = 20)` used in controller methods |
| Max pagination size | 100 items | `@PageableMax(size = 100)` |
| Image upload limit | 10 MB per file | `@MaxFileSize(value = "10MB")` annotation in `FileUploadRequest` |
| JWT token expiry | 24 hours | `jwt.expiration=86400000` (ms) in `application.yml` |
| Booking hold duration | 5 minutes | `booking.holdDurationMinutes=5` in `application.yml` |
| Check-in proximity radius | 200 meters | `CHECKIN_RADIUS_METERS = 200` in `VerificationCheckinController.java` |
| Redis session TTL | 1 hour | `spring.data.redis.timeout=3600s` |
| Station search radius | Default 10 km | Default parameter in `StationService.getNearbyStations()` |

### 3.2 Security Measures

| Measure | Implementation |
|---------|---------------|
| Authentication | JWT (JSON Web Tokens) via `io.jsonwebtoken:jjwt-api:0.12.5` |
| Password hashing | BCrypt via Spring Security |
| Authorization | Role-based access control: `ROLE_ADMIN`, `ROLE_COLLABORATOR`, `ROLE_USER` |
| Input validation | Jakarta Bean Validation (`@NotNull`, `@NotBlank`, `@Size`, `@Email`, `@Pattern`) |
| File upload validation | `@AllowedFileTypes({"image/jpeg","image/png","image/webp"})`, `@MaxFileSize("10MB")` |
| CORS | Configured per environment; dev allows all origins, production restricts |
| API rate limiting | [TO VERIFY BY STUDENT] - check if Spring Boot rate limiting is configured |
| HTTPS | Required in production (nginx.conf serves HTTPS; backend configured for TLS) |
| SQL injection | Prevented via JPA/Hibernate parameterized queries |
| Secrets management | Environment variables in docker-compose; `.env` files for local dev |

### 3.3 Scalability Approach

| Aspect | Approach |
|--------|----------|
| Horizontal scaling | Backend is stateless (JWT), multiple instances behind nginx load balancer |
| Database | PostgreSQL 16 with PostGIS for geospatial queries; Flyway migrations for schema management |
| Caching | Redis for session management and frequently accessed data |
| File storage | MinIO (S3-compatible) for object storage, separates from database |
| API versioning | Implicit via path prefixes (`/api/ev/`, `/api/admin/`, `/api/collab/`) |
| Frontend | Separate Flutter web builds for each client (admin, collab web, ev user, collab mobile web) |

### 3.4 Tech Stack Constraints

- **Java**: Minimum version 17 (Spring Boot 3.2.0 requirement)
- **Flutter**: Minimum version 3.41.6 (as per `flutter --version` requirement)
- **PostgreSQL**: Minimum 16 with PostGIS extension for geospatial queries
- **Flutter packages**: Pinned versions in `pubspec.lock`; OpenAPI Dart client generated from spec

### 3.5 Database Type and Rationale

| Choice | Rationale |
|--------|-----------|
| **PostgreSQL 16 + PostGIS** | Relational data with geospatial capabilities; PostGIS enables efficient nearby station searches using `ST_DWithin` and `ST_Distance` functions |
| **Redis 7** | In-memory cache for session tokens, rate limiting counters, and frequently accessed lookup data |
| **MinIO** | S3-compatible object storage for images and documents; easy to self-host, compatible with Flutter web file uploads |
| **Flyway** | Schema migration tool integrated with Spring Boot for versioned database migrations |

---

## 4. SYSTEM ARCHITECTURE

### 4.1 Architecture Pattern

**Layered Architecture with Domain-Driven Design elements**

The backend follows a **layered architecture**:

```
Presentation Layer  → REST Controllers (api/*)
Business Logic Layer → Services (service/*)  
Data Access Layer   → Repositories (repository/*)
Domain Layer       → Entities (domain/*), DTOs (dto/*), Enums
```

The frontend follows a **Clean Architecture** pattern:

```
Presentation Layer  → Widgets, Pages (Flutter UI)
Business Logic Layer → BLoC / Cubit state management
Data Layer          → Repository pattern with OpenAPI-generated client
```

### 4.2 Backend Package Structure

| Package | Purpose |
|---------|---------|
| `com.example.evstation.api.admin_web` | Admin web portal REST endpoints |
| `com.example.evstation.api.ev_user_mobile` | EV user mobile app REST endpoints |
| `com.example.evstation.api.collaborator_web` | Collaborator web REST endpoints |
| `com.example.evstation.api.collaborator_mobile` | Collaborator mobile REST endpoints |
| `com.example.evstation.api.public_api` | Public API endpoints |
| `com.example.evstation.auth` | JWT authentication filter, security config, token service |
| `com.example.evstation.common` | Shared utilities (distance calculation, file handling, constants) |
| `com.example.evstation.config` | Spring Boot configurations (Redis, S3, OpenAPI) |
| `com.example.evstation.booking` | Booking domain: entities, DTOs, enums, application services |
| `com.example.evstation.batteryswap` | Battery swap domain |
| `com.example.evstation.loyalty` | **Loyalty & rewards**: points, vouchers, ratings, badges, referrals |
| `com.example.evstation.notification` | Push notification domain |
| `com.example.evstation.risk` | Risk scoring domain |
| `com.example.evstation.station` | Station, change request, verification domain |
| `com.example.evstation.trust` | Trust score domain |
| `com.example.evstation.user` | User account, collaborator domain |
| `com.example.evstation.payment` | Payment intent domain |
| `com.example.evstation.exception` | Global exception handlers and custom exceptions |
| `com.example.evstation.*.infrastructure.jpa` | JPA repositories for each domain |

### 4.3 Frontend Package Structure

| Package | Purpose |
|---------|---------|
| `apps/admin_web` | Admin web portal Flutter application |
| `apps/collab_mobile` | Collaborator mobile Flutter application |
| `apps/collab_web` | Collaborator web Flutter application (build target) |
| `apps/ev_user_mobile` | EV user mobile Flutter application |
| `apps/hardware_simulator` | Hardware device simulator |
| `packages/shared_api` | OpenAPI-generated Dart API client |
| `packages/shared_auth` | Authentication state (TokenStorage, AuthCubit) |
| `packages/shared_network` | Dio HTTP client with interceptors |
| `packages/shared_ui` | Common widgets, theme, utilities |

### 4.4 Dependency Diagram

```
                    ┌─────────────────────────────────────────────────┐
                    │              Flutter Frontend Apps             │
                    │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
                    │  │ev_user   │  │  admin   │  │  collab  │     │
                    │  │_mobile   │  │  _web    │  │_mobile/  │     │
                    │  │          │  │          │  │  _web    │     │
                    │  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
                    │       │              │              │           │
                    │  ┌────▼──────────────▼──────────────▼─────┐     │
                    │  │            Shared Packages             │     │
                    │  │  shared_api │ shared_auth │ shared_ui │     │
                    │  └──────────────┬─────────────────────────┘     │
                    └─────────────────┼───────────────────────────────┘
                                        │ HTTP (REST + JWT)
                                        ▼
                    ┌─────────────────────────────────────────────────┐
                    │         Spring Boot Backend (Java 17)          │
                    │                                                  │
                    │  ┌────────────────────────────────────────┐     │
                    │  │           REST Controllers              │     │
                    │  │  AdminApi / EvApi / CollabApi           │     │
                    │  └─────────────────┬──────────────────────┘     │
                    │                    │                             │
                    │  ┌─────────────────▼──────────────────────┐     │
                    │  │           Service Layer                 │     │
                    │  │ Booking / Station / Verification /      │     │
                    │  │ Risk / Trust / Payment / Loyalty        │     │
                    │  └─────────────────┬──────────────────────┘     │
                    │                    │                             │
                    │  ┌─────────────────▼──────────────────────┐     │
                    │  │         Repository Layer                │     │
                    │  │   JPA Repositories (Spring Data JPA)    │     │
                    │  └─────────────────┬──────────────────────┘     │
                    └────────────────────┼─────────────────────────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              │                          │                          │
              ▼                          ▼                          ▼
    ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
    │   PostgreSQL    │      │      Redis      │      │      MinIO      │
    │   (with        │      │   (Cache &      │      │   (Object       │
    │    PostGIS)     │      │    Sessions)    │      │    Storage)     │
    └─────────────────┘      └─────────────────┘      └─────────────────┘
```

### 4.5 External APIs and Services

| Service | Purpose | Integration |
|---------|---------|-------------|
| **MinIO (S3-compatible)** | Store uploaded images (station photos, verification evidence) | AWS S3 SDK via `software.amazon.awssdk:s3` |
| **OpenWeatherMap** | [TO VERIFY BY STUDENT] - weather data for station operations | Not explicitly found in code |
| **Google Maps / OpenStreetMap** | Map display in Flutter apps | `flutter_map` with OpenStreetMap tiles |
| **FCM (Firebase Cloud Messaging)** | Push notifications | `firebase_messaging` package in mobile apps |

---

## 5. DETAILED DESIGN

### 5.1 Key Backend Classes and Methods

#### Authentication Module (`com.voltgo.auth`)

| Class | Responsibility | Key Methods |
|-------|---------------|-------------|
| `JwtTokenProvider` | Generate and validate JWT tokens | `generateToken()`, `validateToken()`, `extractUsername()`, `extractRole()` |
| `CustomUserDetailsService` | Load user by username for Spring Security | `loadUserByUsername()` |
| `JwtAuthenticationFilter` | Intercept requests and set security context | `doFilterInternal()` |
| `SecurityConfig` | Configure Spring Security chain, CORS, JWT filter | `securityFilterChain()` |
| `AuthService` | Business logic for login/register | `login()`, `register()`, `logout()` |

#### Station Management Module (`com.voltgo.domain.station`)

| Class | Responsibility | Key Methods |
|-------|---------------|-------------|
| `StationService` | Station CRUD and versioning | `createStation()`, `updateStation()`, `publishChangeRequest()`, `getNearbyStations()` |
| `ChangeRequestService` | Manage station change request lifecycle | `createDraft()`, `submit()`, `approve()`, `reject()` |
| `VerificationTaskService` | Manage GPS verification workflow | `createTask()`, `assignTask()`, `checkin()`, `submitEvidence()`, `review()` |
| `RiskService` | Compute risk scores for submissions | `calculateRisk()` |
| `TrustService` | Compute and manage station trust scores | `recalculateTrust()`, `getTrustBreakdown()` |

**Key Entity Relationships**:
```java
Station (1) ──→ (N) StationVersion     // versioning
Station (1) ──→ (N) ChangeRequest     // submission workflow
ChangeRequest (1) ──→ (N) VerificationTask  // post-publish verification
VerificationTask (1) ──→ (1) VerificationCheckin
VerificationTask (1) ──→ (N) VerificationEvidence
VerificationTask (1) ──→ (N) VerificationReview
Station (1) ──→ (N) ChargingPort
Station (1) ──→ (N) StationService
Station (1) ──→ (1) StationTrust
```

#### Booking Module (`com.voltgo.domain.booking`)

| Class | Responsibility | Key Methods |
|-------|---------------|-------------|
| `BookingService` | Booking lifecycle management | `createBooking()`, `cancelBooking()`, `getUserBookings()` |
| `PaymentService` | Payment intent management | `createPaymentIntent()`, `simulateSuccess()`, `simulateFailure()` |

**Booking Status Flow**: `PENDING → HOLD → CONFIRMED → COMPLETED/CANCELLED/EXPIRED`

**Payment Status Flow**: `PENDING → SUCCESS/FAILED/REFUNDED`

#### Battery Swap Module (`com.example.evstation.batteryswap`)

| Class | Responsibility | Key Methods |
|-------|---------------|-------------|
| `BatterySwapService` | Swap station operations | `reserve()`, `checkPileStatus()`, `cancelReservation()` |
| `SwapPile` | Physical battery pile representation | Battery slots management |
| `BatterySlot` | Individual battery slot state | `isAvailable()`, `getStatus()` |

#### Loyalty & Rewards Module (`com.example.evstation.loyalty`)

| Class | Responsibility | Key Methods |
|-------|---------------|-------------|
| `LoyaltyPointService` | Points lifecycle: earn, redeem, adjust | `earnPoints()`, `redeemPoints()`, `adjustPoints()`, `calculateLevel()`, `getLevelName()` |
| `VoucherService` | Voucher catalog, redemption, and application | `getAvailableVouchers()`, `redeemVoucher()`, `applyVoucherToBooking()`, `applyVoucherToSwap()` |
| `StationRatingService` | Rating submission, retrieval, moderation | `submitRating()`, `getRatingsForStation()`, `markHelpful()`, `getRatingSummary()` |
| `BadgeService` | Badge award and progress tracking | `checkAndAwardBadges()`, `getBadgesForUser()`, `getAllBadgesWithProgress()` |
| `ReferralService` | Referral code generation and reward tracking | `generateReferralCode()`, `onReferralSignup()`, `onRefereeFirstBookingCompleted()` |
| `RatingEligibilityService` | Track which users can rate which stations | `getUnratedEligibleStations()`, `markAsRated()`, `markEligible()` |
| `VoucherExpirationScheduler` | Scheduled job to expire unredeemed vouchers | `expireRedemptions()` |
| `VoucherDataInitializer` | Seeds initial voucher definitions | Seed data on startup |
| `EvLoyaltyController` | EV user-facing loyalty API endpoints | `GET /api/ev/loyalty/*` |
| `AdminLoyaltyController` | Admin loyalty management API | `GET/POST /api/admin/loyalty/*` |

**Point Sources and Values**:
- `BOOKING`: 30 pts — completed charging session
- `BATTERY_SWAP`: 30 pts — completed battery swap
- `RATING`: 10 pts — rated a station
- `RATING_WITH_COMMENT`: 15 pts — rating with written review (10 + 5 bonus)
- `CR_SUBMIT`: 10 pts — submitted a station update proposal
- `CR_PUBLISH`: 40 pts — proposal approved and published
- `REFERRAL`: 50 pts — successful referral
- `BADGE`: variable pts — badge earned with bonus points
- `ADMIN_ADJUST`: 0 pts — manual admin adjustment

**User Level Thresholds** (lifetime points): `Bronze (0) → Silver (100) → Gold (500) → Platinum (1,500) → Diamond (5,000) → Master (15,000+)`

**Voucher Types**:
- `PERCENT_DISCOUNT`: percentage off with optional `maxValueVnd` cap
- `FREE_SERVICE`: full free for the service type (charging or battery swap)

### 5.2 Key Frontend Classes

#### State Management (BLoC/Cubit Pattern)

| Class | Purpose | Key States |
|-------|---------|------------|
| `AuthCubit` | Manage authentication state | `AuthInitial`, `AuthLoading`, `Authenticated`, `Unauthenticated` |
| `StationListCubit` | Manage station list with search/filter | `StationListState` |
| `BookingCubit` | Manage active booking flow | `BookingState` |
| `VerificationTaskCubit` | Manage verification task workflow | `VerificationTaskState` |
| `ProfileCubit` | Manage collaborator/EV user profile | `ProfileState` |

#### Repository Pattern

| Class | Purpose |
|-------|---------|
| `StationRepository` | Fetch station data via `ev_station_api.dart` client |
| `BookingRepository` | Manage booking operations via `ev_booking_api.dart` client |
| `TaskRepository` | Manage verification tasks via `collab_mobile_task_api.dart` |
| `FileRepository` | Handle file uploads via `collab_mobile_file_api.dart` |

### 5.3 Sequence Diagrams

#### Sequence: Book Charging Slot

```
EV Driver          Mobile App          Backend API           Database
   │                    │                   │                    │
   │──Open Stations────▶│                   │                    │
   │                    │──GET /ev/stations──▶│                    │
   │                    │◀──Station List────│                    │
   │◀──Display List─────│                   │                    │
   │                    │                   │                    │
   │──Select Station────▶│                   │                    │
   │                    │──GET /ev/stations/{id}──▶│            │
   │                    │◀──Station Detail──│                    │
   │                    │                   │                    │
   │──View Ports────────▶│                   │                    │
   │                    │──GET /ev/stations/{id}/charger-units──▶│
   │                    │◀──Port List───────│                    │
   │                    │                   │                    │
   │──Book Slot────────▶│                   │                    │
   │                    │──POST /ev/bookings──▶│                   │
   │                    │                   │──Validate availability──▶│
   │                    │                   │──Create Booking (HOLD)──▶│
   │                    │                   │──Create PaymentIntent───▶│
   │                    │◀──Booking + PaymentIntent──│             │
   │◀──Payment Screen───│                   │                    │
   │                    │                   │                    │
   │──Confirm Payment──▶│                   │                    │
   │                    │──POST /ev/payments/simulate-success──▶│  │
   │                    │                   │──Update PaymentIntent──▶│
   │                    │                   │──Update Booking.status──▶│
   │                    │◀──Payment Success──│                    │
   │◀──Booking Confirmed│                   │                    │
```

#### Sequence: GPS Verification

```
Collaborator      Mobile App          Backend API         Database
   │                   │                   │                  │
   │──Open Tasks───────▶│                   │                  │
   │                   │──GET /collab/mobile/tasks──▶│         │
   │◀──Task List───────│◀──VerificationTask────│                  │
   │                   │                   │                  │
   │──Travel to Station│                   │                  │
   │──Tap Check-In────▶│                   │                  │
   │                   │──Capture GPS──────│                  │
   │                   │──POST /checkin───▶│                  │
   │                   │                   │──Load Station GPS──▶│
   │                   │                   │──Haversine distance──│
   │                   │                   │──Save Checkin──────▶│
   │                   │◀──Checkin Success──│                  │
   │◀──Check-in Confirmed                   │                  │
   │                   │                   │                  │
   │──Take Photos──────▶│                   │                  │
   │──Upload Evidence─▶│                   │                  │
   │                   │──POST /files/upload──▶│                │
   │                   │                   │──Store in MinIO───▶│
   │                   │◀──File Key─────────│                  │
   │                   │──POST /evidence───▶│                  │
   │                   │                   │──Save Evidence───▶│
   │                   │                   │──Update Task.status──▶│
   │◀──Submission OK───│                   │                  │
   │                   │                   │                  │
   │          Admin Web         Backend API         Database   │
   │                   │                   │                  │
   │──View Tasks──────▶│                   │                  │
   │                   │──GET /admin/verification-tasks──▶│    │
   │◀──Task Details───│◀──(with evidence)──│                  │
   │                   │                   │                  │
   │──Review Evidence─▶│                   │                  │
   │──Approve/Reject──▶│                   │                  │
   │                   │──POST /admin/verification-tasks/{id}/review──▶│
   │                   │                   │──Update Task.status──▶│
   │                   │                   │──Recalculate Trust──▶│
   │◀──Review Complete─│                   │                  │
```

#### Sequence: Station Registration Workflow

```
Collaborator      Web App           Backend API         Database
   │                   │                   │                  │
   │──Register Station─▶│                   │                  │
   │                   │──POST /collab/web/stations───▶│        │
   │                   │                   │──Create ChangeRequest──▶│
   │                   │                   │──status = DRAFT───│     │
   │                   │◀──ChangeRequest ID──│                  │
   │◀──Draft Saved─────│                   │                  │
   │                   │                   │                  │
   │──Submit for Review▶│                   │                  │
   │                   │──POST /collab/web/stations/{id}/submit──▶│ │
   │                   │                   │──Validate fields──│    │
   │                   │                   │──Calculate Risk Score───││
   │                   │                   │──status = PENDING───│   │
   │                   │◀──Submitted OK────│                  │
   │                   │                   │                  │
   │          Admin Web         Backend API         Database   │
   │                   │                   │                  │
   │──View Pending────▶│                   │                  │
   │                   │──GET /admin/change-requests──▶│       │
   │◀──Request List────│◀──PENDING requests──│                  │
   │                   │                   │                  │
   │──Review Details───▶│                   │                  │
   │──Approve──────────▶│                   │                  │
   │                   │──POST /admin/change-requests/{id}/approve──▶│
   │                   │                   │──status = APPROVED───│  │
   │                   │                   │──Create/Update StationVersion──▶│
   │                   │                   │──status = PUBLISHED──│  │
   │◀──Station Published                   │                  │
```

---

## 6. DATABASE DESIGN

### 6.1 Entity/Table Summary

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `user_account` | User authentication | id, email, password_hash, role, phone, status, created_at |
| `collaborator_profile` | Collaborator details | user_account_id, full_name, address, contract_status, kpi_score |
| `station` | Station master record | id, name, owner_id, status, created_at |
| `station_version` | Station versioned snapshots | id, station_id, version, status, latitude, longitude, address |
| `station_service` | Services offered by station | station_version_id, service_type (CHARGING/BATTERY_SWAP) |
| `charging_port` | Port configuration | station_version_id, port_type, power_kw, quantity |
| `change_request` | Submission workflow | id, station_id, type, status, risk_score, submitted_at |
| `verification_task` | GPS verification | id, station_id, collaborator_id, status, assigned_at |
| `verification_checkin` | Check-in record | task_id, latitude, longitude, distance_meters, checked_in_at |
| `verification_evidence` | Evidence files | task_id, file_key, file_type, uploaded_at |
| `verification_review` | Admin review | task_id, admin_id, decision, comment, reviewed_at |
| `booking` | Charging slot booking | id, user_id, station_id, charger_unit_id, status, payment_status |
| `payment_intent` | Payment record | id, booking_id, amount, status, payment_method |
| `battery_swap_station_state` | Swap station state | station_id, total_slots, available_slots, updated_at |
| `swap_pile` | Physical piles | station_id, pile_number, total_slots, available_slots |
| `battery_slot` | Individual slots | pile_id, slot_number, status, battery_type |
| `station_trust` | Trust scores | station_id, overall_score, uptime_score, rating_score |
| `collaborator_notification` | Notifications | collaborator_id, title, body, type, is_read |
| `push_token` | Device tokens | user_id, token, platform (IOS/ANDROID/WEB) |
| `notification_preference` | User preferences | user_id, type, enabled |
| `audit_log` | Admin audit trail | admin_id, action, entity_type, entity_id, details |
| `loyalty_user_profile` | User loyalty profile | user_id (PK), current_points, lifetime_points, total_ratings, total_bookings, total_swaps, total_contributions, level |
| `loyalty_point_transaction` | Point transaction history | id, user_id, type, source, points, balance_after, source_id, description |
| `loyalty_badge` | Badge definitions | id, code, name, tier, criteria_type, criteria_value, points_bonus |
| `user_badge` | Earned user badges | id, user_id, badge_id, earned_at |
| `station_rating` | Station reviews | id, user_id, station_id, rating, comment, is_verified, helpful_count, status |
| `rating_eligibility` | Rating eligibility tracking | id, user_id, station_id, source_type, source_id, rated_at |
| `referral` | Referral tracking | id, referrer_id, referee_id, referral_code, status |
| `voucher_definition` | Voucher campaign definitions | id, code, name, voucher_type, point_cost, discount_percent, max_value_vnd, service_type, status, start_date, end_date, validity_days |
| `voucher_redemption` | Redeemed vouchers | id, user_id, voucher_definition_id, voucher_code, status, points_spent, redeemed_at, expires_at, used_at, booking_id, service_type |

### 6.2 Field Details with Data Types

#### `user_account`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| role | VARCHAR(50) | NOT NULL (ADMIN/COLLABORATOR/USER) |
| phone | VARCHAR(20) | NULL |
| status | VARCHAR(20) | NOT NULL (ACTIVE/LOCKED/DISABLED) |
| created_at | TIMESTAMP | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL |

#### `station`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| name | VARCHAR(255) | NOT NULL |
| owner_id | UUID | FK → user_account.id |
| status | VARCHAR(20) | NOT NULL (DRAFT/PENDING/APPROVED/REJECTED/PUBLISHED) |
| created_at | TIMESTAMP | NOT NULL |

#### `station_version`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| station_id | UUID | FK → station.id |
| version | INTEGER | NOT NULL |
| status | VARCHAR(20) | NOT NULL |
| address | VARCHAR(500) | NOT NULL |
| latitude | DOUBLE | NOT NULL |
| longitude | DOUBLE | NOT NULL |
| operating_hours | JSONB | NULL |
| pricing | JSONB | NULL |
| images | JSONB | NULL |

#### `charging_port`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| station_version_id | UUID | FK → station_version.id |
| port_type | VARCHAR(50) | NOT NULL (TYPE_2/CCS/CHADEBO/SC/TESLA) |
| power_kw | DOUBLE | NOT NULL |
| quantity | INTEGER | NOT NULL |
| price_per_kwh | DOUBLE | NULL |

#### `change_request`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| station_id | UUID | FK → station.id |
| type | VARCHAR(20) | NOT NULL (CREATE/UPDATE) |
| status | VARCHAR(20) | NOT NULL |
| submitted_by | UUID | FK → user_account.id |
| submitted_at | TIMESTAMP | NULL |
| reviewed_by | UUID | FK → user_account.id, NULL |
| reviewed_at | TIMESTAMP | NULL |
| rejection_reason | TEXT | NULL |
| risk_score | DOUBLE | NULL |

#### `verification_task`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| station_id | UUID | FK → station.id |
| assigned_to | UUID | FK → user_account.id |
| status | VARCHAR(20) | NOT NULL |
| assigned_at | TIMESTAMP | NOT NULL |
| deadline | TIMESTAMP | NULL |

#### `verification_checkin`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| task_id | UUID | FK → verification_task.id |
| latitude | DOUBLE | NOT NULL |
| longitude | DOUBLE | NOT NULL |
| distance_meters | DOUBLE | NOT NULL |
| checked_in_at | TIMESTAMP | NOT NULL |

#### `booking`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| user_id | UUID | FK → user_account.id |
| station_id | UUID | FK → station.id |
| charger_unit_id | UUID | NULL |
| service_type | VARCHAR(30) | NOT NULL (CHARGING/BATTERY_SWAP) |
| status | VARCHAR(20) | NOT NULL (HOLD/CONFIRMED/COMPLETED/CANCELLED/EXPIRED) |
| payment_status | VARCHAR(20) | NOT NULL (UNPAID/PAID/REFUNDED) |
| start_time | TIMESTAMP | NOT NULL |
| end_time | TIMESTAMP | NOT NULL |
| total_amount | DECIMAL(10,2) | NULL |

#### `payment_intent`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| booking_id | UUID | FK → booking.id |
| amount | DECIMAL(10,2) | NOT NULL |
| currency | VARCHAR(3) | NOT NULL DEFAULT 'VND' |
| status | VARCHAR(20) | NOT NULL (PENDING/SUCCESS/FAILED/REFUNDED) |
| payment_method | VARCHAR(50) | NULL |
| paid_at | TIMESTAMP | NULL |

#### `station_trust`
| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| station_id | UUID | FK → station.id, UNIQUE |
| overall_score | DOUBLE | NOT NULL (0.0 - 100.0) |
| uptime_score | DOUBLE | NOT NULL |
| verification_score | DOUBLE | NOT NULL |
| rating_score | DOUBLE | NOT NULL |
| last_updated | TIMESTAMP | NOT NULL |

### 6.3 Table Relationships

```
user_account (1) ── (N) collaborator_profile
user_account (1) ── (N) booking
user_account (1) ── (N) change_request (as submitted_by)
user_account (1) ── (N) verification_task (as assigned_to)
user_account (1) ── (N) push_token
user_account (1) ── (N) notification_preference
user_account (1) ── (1) loyalty_user_profile
user_account (1) ── (N) loyalty_point_transaction
user_account (1) ── (N) user_badge
user_account (1) ── (N) station_rating
user_account (1) ── (N) voucher_redemption
user_account (1) ── (N) referral (as referrer)
user_account (1) ── (N) referral (as referee)

station (1) ── (N) station_version
station (1) ── (N) change_request
station (1) ── (N) verification_task
station (1) ── (1) battery_swap_station_state
station (1) ── (1) station_trust
station (1) ── (N) station_rating

station_version (1) ── (N) station_service
station_version (1) ── (N) charging_port

change_request (1) ── (N) verification_task  (after publish)

verification_task (1) ── (1) verification_checkin
verification_task (1) ── (N) verification_evidence
verification_task (1) ── (N) verification_review

booking (1) ── (1) payment_intent
booking (1) ── (0..1) voucher_redemption (via voucher_redemption_id)

battery_swap_station_state (1) ── (N) swap_pile
swap_pile (1) ── (N) battery_slot

loyalty_badge (1) ── (N) user_badge

voucher_definition (1) ── (N) voucher_redemption

rating_eligibility (1) ── (N) station_rating
```

#### `loyalty_user_profile`

| Field | Type | Constraints |
|-------|------|-------------|
| user_id | UUID | PK, FK → user_account.id |
| current_points | INTEGER | NOT NULL DEFAULT 0 |
| lifetime_points | INTEGER | NOT NULL DEFAULT 0 |
| total_ratings | INTEGER | NOT NULL DEFAULT 0 |
| total_bookings | INTEGER | NOT NULL DEFAULT 0 |
| total_swaps | INTEGER | NOT NULL DEFAULT 0 |
| total_contributions | INTEGER | NOT NULL DEFAULT 0 |
| last_activity_at | TIMESTAMP | NULL |
| level | INTEGER | NOT NULL DEFAULT 1 |
| updated_at | TIMESTAMP | NOT NULL |

#### `loyalty_point_transaction`

| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| user_id | UUID | FK → user_account.id |
| type | VARCHAR(20) | NOT NULL (EARN/REDEEM/ADJUST) |
| source | VARCHAR(30) | NOT NULL (BOOKING, BATTERY_SWAP, RATING, REFERRAL, etc.) |
| source_id | UUID | NULL (prevents duplicate awards) |
| points | INTEGER | NOT NULL |
| balance_after | INTEGER | NOT NULL |
| description | VARCHAR(255) | NULL |
| metadata | JSONB | NULL |
| created_at | TIMESTAMP | NOT NULL |

#### `station_rating`

| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| user_id | UUID | FK → user_account.id |
| station_id | UUID | FK → station.id |
| rating | INTEGER | NOT NULL (1-5) |
| comment | TEXT | NULL |
| is_verified | BOOLEAN | NOT NULL (true if from eligible booking) |
| helpful_count | INTEGER | NOT NULL DEFAULT 0 |
| status | VARCHAR(20) | NOT NULL (ACTIVE/HIDDEN) |
| eligibility_id | UUID | FK → rating_eligibility.id, NULL |
| created_at | TIMESTAMP | NOT NULL |

#### `voucher_definition`

| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| code | VARCHAR(50) | UNIQUE, NOT NULL |
| name | VARCHAR(255) | NOT NULL |
| description | TEXT | NULL |
| voucher_type | VARCHAR(30) | NOT NULL (PERCENT_DISCOUNT/FREE_SERVICE) |
| point_cost | INTEGER | NOT NULL |
| discount_percent | INTEGER | NULL (for PERCENT_DISCOUNT) |
| max_value_vnd | INTEGER | NULL (cap on discount) |
| service_type | VARCHAR(30) | NULL (CHARGING/BATTERY_SWAP) |
| status | VARCHAR(20) | NOT NULL (ACTIVE/INACTIVE/EXPIRED) |
| start_date | TIMESTAMP | NULL |
| end_date | TIMESTAMP | NULL |
| validity_days | INTEGER | NOT NULL DEFAULT 30 |
| created_at | TIMESTAMP | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL |

#### `voucher_redemption`

| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| user_id | UUID | FK → user_account.id |
| voucher_definition_id | UUID | FK → voucher_definition.id |
| voucher_code | VARCHAR(20) | NOT NULL, UNIQUE |
| status | VARCHAR(20) | NOT NULL (REDEEMED/USED/EXPIRED) |
| points_spent | INTEGER | NOT NULL |
| redeemed_at | TIMESTAMP | NOT NULL |
| expires_at | TIMESTAMP | NOT NULL |
| used_at | TIMESTAMP | NULL |
| booking_id | UUID | NULL (FK → booking.id, set when applied) |
| service_type | VARCHAR(30) | NULL |
| metadata | JSONB | NULL |

#### `loyalty_badge`

| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| code | VARCHAR(50) | UNIQUE, NOT NULL |
| name | VARCHAR(100) | NOT NULL |
| tier | VARCHAR(20) | NOT NULL (BRONZE/SILVER/GOLD) |
| criteria_type | VARCHAR(30) | NOT NULL |
| criteria_value | INTEGER | NOT NULL |
| points_bonus | INTEGER | NOT NULL DEFAULT 0 |
| description | TEXT | NULL |
| icon | VARCHAR(100) | NULL |

#### `referral`

| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | PK |
| referrer_id | UUID | FK → user_account.id |
| referee_id | UUID | FK → user_account.id, NULL |
| referral_code | VARCHAR(20) | NOT NULL |
| status | VARCHAR(20) | NOT NULL (PENDING/REGISTERED/EARNED) |
| created_at | TIMESTAMP | NOT NULL |

### 6.4 Indexes

Based on Flyway migration analysis, the following indexes are likely created:
- `idx_user_email` on `user_account(email)`
- `idx_station_owner` on `station(owner_id)`
- `idx_station_status` on `station(status)`
- `idx_station_version_station` on `station_version(station_id)`
- `idx_change_request_status` on `change_request(status)`
- `idx_booking_user` on `booking(user_id)`
- `idx_booking_station` on `booking(station_id)`
- `idx_booking_time` on `booking(start_time, end_time)`
- `idx_verification_task_status` on `verification_task(status)`
- `idx_verification_task_assignee` on `verification_task(assigned_to)`

PostGIS indexes (GIST) for geospatial queries:
- `idx_station_location` GIST on `station_version(coordinates)` using `ST_GeogFromText`

---

## 7. TECHNOLOGIES USED

### Backend

| Purpose | Tool/Library | Version | URL |
|---------|-------------|---------|-----|
| Framework | Spring Boot | 3.2.0 | https://spring.io/projects/spring-boot |
| Language | Java | 17 | https://www.oracle.com/java/ |
| Database ORM | Spring Data JPA / Hibernate | 6.2.0 | https://hibernate.org/ |
| Database | PostgreSQL | 16 | https://www.postgresql.org/ |
| Geospatial | PostGIS | 3 | https://postgis.net/ |
| Cache | Spring Data Redis | 3.2.0 | https://spring.io/projects/spring-data-redis |
| Message Broker | [TO VERIFY] | — | — |
| JWT | jjwt | 0.12.5 | https://github.com/jwtk/jjwt |
| API Docs | springdoc-openapi | 2.3.0 | https://springdoc.org/ |
| Database Migration | Flyway | 9.22.3 | https://flywaydb.org/ |
| S3/MinIO Client | AWS SDK for Java | 2.23.0 | https://aws.amazon.com/sdk-for-java/ |
| Build Tool | Gradle | 8.5 | https://gradle.org/ |
| File Upload | Spring Servlet | Built-in | — |
| Bean Validation | Jakarta Validation | 3.0.2 | — |
| JSON | Jackson | 2.15.3 | — |
| Testing | JUnit 5 + Mockito | 5.10.0 | https://junit.org/junit5/ |
| Map Utils | LatLngUtils | custom | — |

### Frontend (Flutter)

| Purpose | Tool/Library | Version | URL |
|---------|-------------|---------|-----|
| Framework | Flutter | 3.41.6 | https://flutter.dev/ |
| Language | Dart | 3.5.0 | https://dart.dev/ |
| State Management | flutter_bloc | ^9.0.0 | https://bloclibrary.dev/ |
| HTTP Client | dio | ^5.4.0 | https://pub.dev/packages/dio |
| Maps | flutter_map | ^7.0.0 | https://docs.fleaflet.dev/ |
| Maps Tile Provider | flutter_map_cancellable_tile_provider | ^3.0.0 | — |
| Geolocation | geolocator | ^13.0.0 | https://pub.dev/packages/geolocator |
| Geocoding | geocoding | ^3.0.0 | — |
| File Picker | file_picker | ^8.0.0 | https://pub.dev/packages/file_picker |
| Charts | fl_chart | ^0.69.0 | https://pub.dev/packages/fl_chart |
| Image Picker | image_picker | ^1.1.0 | — |
| Secure Storage | flutter_secure_storage | ^9.2.0 | — |
| Intl/Formatting | intl | ^0.19.0 | — |
| Cached Network Image | cached_network_image | ^3.3.0 | — |
| Permission Handler | permission_handler | ^11.3.0 | — |
| URL Launcher | url_launcher | ^6.3.0 | — |
| WebSocket | web_socket_channel | ^3.0.0 | — |
| JSON Serialization | json_annotation + json_serializable | ^4.9.0 | — |
| Build Runner | build_runner | ^2.4.0 | — |
| Firebase Cloud Messaging | firebase_messaging | ^15.0.0 | — |
| Firebase Core | firebase_core | ^3.0.0 | — |
| Equatable | equatable | ^2.0.0 | — |
| Get It | get_it | ^8.0.0 | — |
| Go Router | go_router | ^14.0.0 | https://pub.dev/packages/go_router |
| Pull to Refresh | pull_to_refresh_flutter3 | ^2.0.0 | — |

### Infrastructure

| Purpose | Tool/Library | Version | URL |
|---------|-------------|---------|-----|
| Containerization | Docker | 25.0 | https://www.docker.com/ |
| Container Orchestration | docker-compose | 2.24 | https://docs.docker.com/compose/ |
| Web Server | nginx | 1.25 | https://nginx.org/ |
| Object Storage | MinIO | RELEASE.2024 | https://min.io/ |
| Cache DB | Redis | 7 | https://redis.io/ |

---

## 8. APPLICATION STATISTICS

### 8.1 File Count by Type

Based on the codebase exploration:

| Type | Count | Notes |
|------|-------|-------|
| Java files (.java) | ~90 | Backend source |
| Kotlin files (.kt) | 1 | `RedisSessionConfig.kt` |
| Dart files (.dart) | ~200 | Flutter source across all apps |
| YAML files (.yml, .yaml) | 4 | Spring Boot configs |
| SQL migration files (.sql) | 52 | Flyway migrations |
| TypeScript/Config files | ~30 | OpenAPI, Dockerfile, nginx, docker-compose |
| Markdown files (.md) | 1 | README.md |
| Environment files (.env) | 5 | Per-environment config |
| Shell scripts (.sh) | ~10 | Scripts in infra/, scripts/ |
| Dart build files | 6 | pubspec.yaml per app/package |
| Gradle files | 2 | build.gradle, settings.gradle |

**Total files**: ~400+

### 8.2 Estimated Lines of Code

| Layer | Language | Est. LOC |
|-------|----------|----------|
| Backend (Java) | Java | ~18,000 |
| Backend config/migration | SQL + YAML | ~5,000 |
| Frontend (Dart/Flutter) | Dart | ~25,000 |
| Infrastructure | Dockerfile, nginx, YAML | ~1,500 |
| **Total** | | **~49,500** |

### 8.3 Component Count

| Category | Count |
|----------|-------|
| Backend REST Controllers | ~25 |
| Backend Service classes | ~20 |
| Backend Repository interfaces | ~20 |
| Backend Entity classes | ~25 |
| Flutter BLoC/Cubit classes | ~20 |
| Flutter Page/Widget files | ~60 |
| Flutter Repository classes | ~15 |
| OpenAPI-defined API endpoints | ~80 |

### 8.4 API Endpoint Count

From the OpenAPI specification (3,000+ lines) and controller analysis:

| Category | Count |
|----------|-------|
| Auth endpoints | ~5 |
| EV User Mobile (`/api/ev/`) | ~20 |
| EV Loyalty (`/api/ev/loyalty/`) | ~15 |
| Admin Web (`/api/admin/`) | ~25 |
| Admin Loyalty (`/api/admin/loyalty/`) | ~15 |
| Collaborator Web (`/api/collab/web/`) | ~15 |
| Collaborator Mobile (`/api/collab/mobile/`) | ~15 |
| **Total** | **~110** |

### 8.5 Package/Module Count

| Layer | Count |
|-------|-------|
| Backend packages (Java) | ~30 |
| Flutter apps | 4 |
| Flutter shared packages | 4 |

---

## 9. MAIN FEATURES ILLUSTRATION

### 9.1 Station Discovery & Booking (EV User Mobile)

**Feature Name**: EV Charging Station Discovery and Booking

**Screen(s)**: `StationListPage`, `StationDetailPage`, `BookingPage`, `BookingConfirmationPage`

**User Perspective**: An EV driver opens the mobile app, sees nearby charging stations on a map, browses stations with available ports, selects a time slot, and confirms a booking with simulated payment.

**Implementation Details**:
- Uses `flutter_map` with OpenStreetMap tiles for the map view
- GPS location captured via `Geolocator.getCurrentPosition()`
- Backend geospatial query using PostGIS `ST_DWithin` for radius-based search
- Booking creates a `HOLD` reservation for 5 minutes (`booking.holdDurationMinutes=5`)
- Payment is simulated via `POST /api/ev/payments/simulate-success` — no real payment gateway integration
- Booking status transitions managed by `BookingStatus` enum: `HOLD → CONFIRMED → COMPLETED`

### 9.2 Station Registration with Versioning (Collaborator Web/Mobile)

**Feature Name**: Station Registration with Multi-Stage Versioning Workflow

**Screen(s)**: `StationFormPage`, `ChangeRequestListPage`, `StationDetailPage`

**User Perspective**: A collaborator registers a new charging station by filling in location, services, pricing, and port configurations. The system saves it as a draft. Upon submission, an automatic risk score is computed. An admin reviews and approves, which publishes the station.

**Implementation Details**:
- Every change (create/update) produces a new `station_version` record
- Versioning enables rollback: approved versions can be restored
- `ChangeRequest` entity tracks the submission workflow: `DRAFT → PENDING → APPROVED/REJECTED → PUBLISHED`
- Risk scoring in `RiskService` analyzes multiple factors: submitter history, data completeness, anomalies
- `StationService.publishChangeRequest()` handles the actual publication logic
- Images uploaded via presigned MinIO URLs to avoid sending binary through API

### 9.3 GPS Verification System (Collaborator Mobile + Admin Web)

**Feature Name**: GPS-Based Station Verification

**Screen(s)**: `TaskListPage`, `VerificationTaskDetailPage`, `CheckInPage`, `EvidenceSubmissionPage` (mobile); `VerificationTaskReviewPage` (admin web)

**User Perspective**: A collaborator receives a verification task, physically visits the station, checks in using GPS, submits photos as evidence, and an admin reviews and approves or rejects the verification.

**Implementation Details**:
- **Haversine distance calculation**: `LatLngUtils.haversineDistance()` computes the great-circle distance between check-in coordinates and station coordinates
- **Proximity validation**: Check-in is rejected if `distanceMeters > 200`
- **Evidence storage**: Photos uploaded to MinIO; file keys stored in `verification_evidence` table
- **Trust score update**: `TrustService.recalculateTrust()` updates `station_trust` after successful verification
- **Verification scoring**: `VerificationScoreEnum` categorizes task urgency and type
- Admin web shows check-in location plotted on a map alongside the station marker for comparison

### 9.4 Battery Swap Station Management (EV User + Collaborator)

**Feature Name**: Battery Swap Station Operations

**Screen(s)**: `SwapStationListPage`, `SwapStationDetailPage`, `SwapReservationPage`

**User Perspective**: EV drivers can browse battery swap stations, view real-time pile/slot availability, and reserve a slot for battery replacement. Collaborators manage pile configurations.

**Implementation Details**:
- `BatterySwapStationState` tracks aggregate availability per station
- `SwapPile` represents a physical battery rack; `BatterySlot` represents individual slots
- Slot statuses: `AVAILABLE`, `OCCUPIED`, `RESERVED`, `MAINTENANCE`
- Reservation system similar to charging booking but with `serviceType = BATTERY_SWAP`
- Real-time state updates via [TO VERIFY BY STUDENT: WebSocket or polling mechanism]

### 9.5 Trust Score System (Admin Web)

**Feature Name**: Explainable Station Trust Scoring

**Screen(s)**: `TrustScorePage`, `StationDetailPage` (admin)

**User Perspective**: Admins view trust scores for all stations, with breakdowns by uptime, verification, and ratings. Station owners can see their score explanation.

**Implementation Details**:
- `StationTrust` entity stores composite score (0-100) and sub-scores
- Trust recalculation triggered by: successful verification completion, issue resolution, booking completion rate
- Score formula includes: uptime component (based on issue frequency), verification component (verification success rate), rating component (user ratings)
- `TrustService.getTrustBreakdown()` provides explainable factor breakdown for transparency

### 9.6 Issue Reporting & Resolution (EV User + Admin)

**Feature Name**: Station Issue Reporting Workflow

**Screen(s)**: `ReportIssuePage` (mobile), `IssueManagementPage` (admin web)

**User Perspective**: An EV driver reports a station issue (broken port, wrong info, etc.) from the mobile app. An admin acknowledges, investigates, resolves, or rejects the issue with comments.

**Implementation Details**:
- Issue types: `BROKEN_PORT`, `WRONG_INFO`, `PRICING_ISSUE`, `CLOSED_UNANNOUNCED`, `OTHER`
- Issue statuses: `OPEN → ACKNOWLEDGED → RESOLVED/REJECTED`
- Admin can attach resolution notes
- Issue frequency contributes to station's trust score degradation

### 9.7 Loyalty & Rewards System (EV User Mobile)

**Feature Name**: Loyalty Points, Vouchers, Ratings, Badges, and Referrals

**Screen(s)**: `LoyaltyHomeScreen`, `MyVouchersScreen`, `VoucherCatalogScreen`, `VoucherDetailScreen`, `RatingSubmissionScreen`, `BadgeCollectionScreen` (mobile)

**User Perspective**: An EV driver earns loyalty points from activities (charging sessions, battery swaps, ratings, referrals, badge achievements). They browse the voucher catalog, redeem points for vouchers, apply vouchers to bookings, view their level progression, and earn achievement badges.

**Implementation Details**:
- **Points System**: `LoyaltyPointService` manages points with `PointSource` enum defining earn rates. `LoyaltyUserProfileEntity` tracks `currentPoints` and `lifetimePoints`. Level thresholds: `{0, 100, 500, 1500, 5000, 15000}` → Bronze/Silver/Gold/Platinum/Diamond/Master.
- **Voucher Redemption Flow**: EV browses catalog → taps "Redeem" → points deducted via `redeemPoints()` → unique code generated (`VG-{UUID}`) → voucher valid for `validityDays`. Two types: `PERCENT_DISCOUNT` (with `maxValueVnd` cap) and `FREE_SERVICE` (full free for service type).
- **Voucher Application**: Voucher linked to booking via `booking.voucherRedemptionId`; payment service reads discount from `VoucherService.getDiscountAmountForRedemption()`. Discount computed as `bookingAmount * discountPercent / 100`, capped at `maxValueVnd`.
- **Rating System**: `StationRatingService` enforces max 3 ratings/day per user. Ratings with comments ≥ 30 chars earn bonus points (15 vs 10). Verified ratings (from eligible bookings) have `isVerified = true`. `RatingEligibilityService` tracks eligibility per user-station pair.
- **Badge System**: `BadgeService.checkAndAwardBadges()` called after each qualifying activity. Badges have tiers (BRONZE/SILVER/GOLD) and criteria types (`BOOKING_COUNT`, `RATING_COUNT`, `FIRST_BOOKING`, etc.). Awarding a badge triggers bonus point credit.
- **Referral System**: `ReferralService` generates 8-char codes. Both referrer and referee earn 50 points when the referee completes their first booking. Uses UUID-based deduplication to prevent duplicate awards.

### 9.8 Voucher Management (Admin Web)

**Feature Name**: Admin Voucher Campaign Management

**Screen(s)**: `VoucherManagementScreen`, `VoucherRedemptionsScreen`, `LoyaltyDashboardScreen`, `RatingModerationScreen`, `UserLoyaltyListScreen`, `UserLoyaltyDetailScreen`

**User Perspective**: An administrator creates and manages voucher campaigns (defining point cost, discount, validity), views redemption statistics, moderates station ratings, adjusts user points manually, and views loyalty program analytics.

**Implementation Details**:
- `AdminLoyaltyController` provides full CRUD for `VoucherDefinitionEntity` with status management (`ACTIVE/INACTIVE/EXPIRED`).
- `LoyaltyDashboardDTO` aggregates: total points issued, active users (last 30 days), total ratings.
- Manual point adjustment via `adjustPoints(delta, reason)` creates `PointType.ADJUST` transaction.
- Rating moderation: admin can hide ratings by setting `StationRating.status = HIDDEN`.
- `VoucherExpirationScheduler` is a scheduled task that calls `expireRedemptions()` to transition `REDEEMED` vouchers past their expiry date to `EXPIRED`.

---

## 10. TESTING APPROACH

### 10.1 Test Files Found

Based on codebase exploration, the following test files exist:

| File Path | Type | Description |
|-----------|------|-------------|
| `backend/src/test/java/com/voltgo/auth/JwtTokenProviderTest.java` | Unit | JWT token generation and validation |
| `backend/src/test/java/com/voltgo/auth/AuthServiceTest.java` | Unit | Authentication service |
| `backend/src/test/java/com/voltgo/domain/station/StationServiceTest.java` | Unit | Station service logic |
| `backend/src/test/java/com/voltgo/domain/booking/BookingServiceTest.java` | Unit | Booking service |
| `backend/src/test/java/com/voltgo/domain/verification/VerificationServiceTest.java` | Unit | Verification workflow |
| `backend/src/test/java/com/voltgo/common/LatLngUtilsTest.java` | Unit | Haversine distance calculation |

### 10.2 Testing Techniques

| Technique | Usage in VoltGO |
|-----------|----------------|
| **Unit Testing** | JUnit 5 + Mockito for service layer logic, distance calculations, JWT validation |
| **Integration Testing** | [TO VERIFY BY STUDENT] - check for `@SpringBootTest`, `@DataJpaTest` annotations |
| **End-to-End Testing** | [TO VERIFY BY STUDENT] - check for Flutter integration tests or Selenium tests |
| **Manual Testing** | Test accounts provided in `infra/scripts/seed_users.sql` |

### 10.3 Test Cases for Main Features

#### TC-1: JWT Token Generation and Validation

| Test | Input | Expected Result |
|------|-------|----------------|
| `generateToken_shouldCreateValidJwt` | Valid `UserDetails` with role ADMIN | Token string starting with "eyJ" is returned; `validateToken()` returns true |
| `extractUsername_shouldReturnCorrectUsername` | Valid JWT token | Extracted username matches the one used during generation |
| `extractRole_shouldReturnCorrectRole` | Valid JWT with role COLLABORATOR | Extracted role equals `ROLE_COLLABORATOR` |
| `validateToken_shouldRejectExpiredToken` | Token with past expiration time | `validateToken()` returns false |
| `validateToken_shouldRejectTamperedToken` | Manually modified JWT string | `validateToken()` returns false |

#### TC-2: Booking Slot Availability

| Test | Input | Scenario | Expected Result |
|------|-------|----------|-----------------|
| `createBooking_shouldSucceed_whenSlotAvailable` | Station with 2 ports, 1 already booked | Booking for available port at non-overlapping time | `Booking.status = HOLD`, `PaymentIntent.status = PENDING` |
| `createBooking_shouldFail_whenSlotOverlapping` | Station with 1 port, already booked for 10:00-11:00 | New booking for 10:30-11:30 | `BookingException` thrown |
| `createBooking_shouldFail_whenStationNotPublished` | Station with `status = DRAFT` | Attempt to book | `BookingException` thrown |
| `cancelBooking_shouldReleaseSlot` | Booking in `HOLD` status | `cancelBooking()` called | `Booking.status = CANCELLED`, slot released |
| `simulatePayment_success_shouldConfirmBooking` | `PaymentIntent` with `status = PENDING` | `simulateSuccess()` called | `PaymentIntent.status = SUCCESS`, `Booking.status = CONFIRMED` |

#### TC-3: GPS Check-in Proximity Validation

| Test | Input | Expected Result |
|------|-------|----------------|
| `checkin_shouldSucceed_whenWithinRadius` | Check-in at 50m from station | Check-in accepted, `distanceMeters = 50` |
| `checkin_shouldFail_whenOutsideRadius` | Check-in at 300m from station | `VerificationException` with "Too far from station" |
| `checkin_shouldSucceed_whenExactlyAtRadius` | Check-in at exactly 200m from station | Check-in accepted (boundary case) |
| `haversineDistance_shouldMatchGeolib` | Two known GPS coordinates | Computed distance matches expected value within 1m tolerance |

#### TC-4: Loyalty Points Earn and Level Calculation

| Test | Input | Expected Result |
|------|-------|----------------|
| `earnPoints_shouldIncrementCurrentAndLifetime` | User earns 30 pts from BOOKING | `currentPoints += 30`, `lifetimePoints += 30` |
| `earnPoints_shouldNotDuplicateForSameSourceId` | Same `sourceId` earned twice | Second earn returns null, no duplicate points |
| `earnPoints_shouldCreateProfile_ifNotExists` | User with no loyalty profile earns points | Auto-creates `LoyaltyUserProfileEntity` |
| `calculateLevel_shouldReturnCorrectLevel` | Lifetime points: 0/50/150/2000/6000/20000 | Returns level 1/1/2/3/4/5 |
| `getLevelName_shouldReturnCorrectName` | Level 1-6 | Returns "Bronze"/"Silver"/"Gold"/"Platinum"/"Diamond"/"Master" |
| `redeemPoints_shouldDeductPoints` | User with 100 pts redeems voucher costing 50 | `currentPoints = 50`, `balanceAfter = 50` |
| `redeemPoints_shouldFail_whenInsufficient` | User with 30 pts redeems voucher costing 50 | `INSUFFICIENT_POINTS` exception |
| `adjustPoints_shouldAllowNegativeResult` | Admin deducts 1000 pts from user with 100 pts | `currentPoints = 0` (not negative) |

#### TC-5: Voucher Redemption and Application

| Test | Input | Expected Result |
|------|-------|----------------|
| `redeemVoucher_shouldDeductPointsAndCreateRedemption` | User redeems 50-pt voucher | Points deducted, `VoucherRedemptionEntity` created with unique code |
| `redeemVoucher_shouldFail_whenInactive` | Voucher with `status = INACTIVE` | `VOUCHER_NOT_ACTIVE` exception |
| `redeemVoucher_shouldFail_whenExpired` | Voucher past its `endDate` | `VOUCHER_NOT_ACTIVE` exception |
| `applyVoucherToBooking_shouldCalculateDiscount` | `PERCENT_DISCOUNT(20%)` on 50,000 VND booking | `discountAmount = 10,000` |
| `applyVoucherToBooking_shouldCapAtMaxValue` | 50% discount on 100,000 VND with `maxValueVnd = 30,000` | `discountAmount = 30,000` |
| `applyVoucherToBooking_shouldFail_whenAlreadyUsed` | `VoucherRedemptionEntity` with `status = USED` | `VOUCHER_ALREADY_USED` exception |
| `applyVoucherToBooking_shouldFail_whenExpired` | Redemption past `expiresAt` | `VOUCHER_EXPIRED` exception, status set to `EXPIRED` |
| `applyVoucherToSwap_shouldSetCorrectServiceType` | Apply `BATTERY_SWAP` voucher to reservation | `serviceType = "BATTERY_SWAP"` |

#### TC-6: Station Rating

| Test | Input | Expected Result |
|------|-------|----------------|
| `submitRating_shouldAwardPointsWithBonus` | Rating 5 stars with comment ≥ 30 chars | 15 points awarded (10 base + 5 bonus) |
| `submitRating_shouldAwardBasePointsWithoutComment` | Rating 4 stars with no comment | 10 points awarded |
| `submitRating_shouldFail_whenRatingOutOfRange` | Rating value of 6 | `INVALID_INPUT` exception |
| `submitRating_shouldFail_whenDailyLimitExceeded` | 4th rating in same day | `RATING_LIMIT_EXCEEDED` exception |
| `markHelpful_shouldIncrementCounter` | Mark rating as helpful | `helpfulCount` incremented by 1 |
| `getRatingSummary_shouldComputeAverage` | Station with ratings [5,4,4,3] | `averageRating = 4.0`, `totalRatings = 4` |

[TO VERIFY BY STUDENT] - Run `gradlew test` in the backend directory and check the generated JaCoCo coverage report. Based on the test files found, coverage is estimated at **~40-60%** for the service layer, with core business logic (booking, verification, risk) covered by unit tests.

---

## 11. DEPLOYMENT

### 11.1 Deployment Method

**Docker-based containerized deployment** using docker-compose. All services (backend, databases, storage, frontend) run as Docker containers.

### 11.2 Infrastructure Components

```
┌─────────────────────────────────────────────────────┐
│                    nginx (port 80/443)              │
│         Reverse proxy + SSL termination            │
│   Routes: /api → backend:8080                       │
│           /admin → admin_web:3002                   │
│           /ev → ev_user_mobile:3001                │
│           /collab → collab_web:3003                │
│           /collab-mob → collab_mobile:3004         │
└─────────────────────────────────────────────────────┘
         │              │              │
         ▼              ▼              ▼
   ┌──────────┐  ┌──────────┐  ┌──────────┐
   │ backend  │  │frontend- │  │frontend- │
   │ :8080    │  │ev_user   │  │admin     │
   │          │  │:3001     │  │:3002     │
   └────┬─────┘  └──────────┘  └──────────┘
        │
        ├──► postgres:5432 (PostgreSQL 16 + PostGIS)
        ├──► redis:6379 (Redis 7)
        └──► minio:9000 (MinIO S3)
```

### 11.3 Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `SPRING_PROFILES_ACTIVE` | Active Spring profile | `local` or `docker` |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | PostgreSQL connection | `postgres`, `5432`, `voltgo` |
| `REDIS_HOST`, `REDIS_PORT` | Redis connection | `redis`, `6379` |
| `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` | MinIO connection | `minio:9000` |
| `JWT_SECRET` | JWT signing key | [64-char hex string] |
| `FRONTEND_BASE_URL` | Frontend URL for CORS | `http://localhost:3000` |

### 11.4 Configuration Files

| File | Purpose |
|------|---------|
| `backend/src/main/resources/application.yml` | Base configuration |
| `backend/src/main/resources/application-local.yml` | Local development (localhost connections) |
| `backend/src/main/resources/application-docker.yml` | Docker environment (service names) |
| `apps/*/.env` | Flutter app runtime config (API base URL) |
| `infra/nginx.conf` | nginx reverse proxy and routing |
| `infra/docker-compose.yml` | Full production stack |
| `infra/docker-compose.dev.yml` | Development with hot reload |
| `infra/Dockerfile.flutter-web` | Production Flutter web build |
| `infra/Dockerfile.flutter-web-dev` | Development Flutter web build |
| `infra/Dockerfile.backend` | Spring Boot JAR build |

### 11.5 Database Migration

Flyway manages all database schema changes:
- Migrations located in `backend/src/main/resources/db/migration/`
- 52 migration files (V1 through V52)
- Naming convention: `V{version}__{description}.sql`
- Migrations run automatically on backend startup

### 11.6 Test/Development Accounts

| Role | Email | Password |
|------|-------|----------|
| Administrator | `admin@local` | `Admin@123` |
| Collaborator 1 | `collab1@local` | `Admin@123` |
| Collaborator 2 | `collab2@local` | `Admin@123` |
| Test Collaborator | `testcollab@voltgo.com` | [No password - contract status] |

Seeded via `infra/scripts/seed_users.sql`.

---

## 12. KEY CONTRIBUTIONS & CHALLENGES

### 12.1 Hardest Technical Problems Solved

#### 1. Geospatial Search with PostGIS Integration

**Problem**: Efficiently querying charging stations within a radius of the user's current location, with filtering by service type and availability.

**Solution**: PostGIS `ST_DWithin` and `ST_Distance` functions combined with JPA `@Query` in `StationRepository`. The Haversine formula is used on the Flutter side for client-side distance computation after fetching results.

**Code Evidence**:
```java
// StationRepository.java
@Query(value = """
    SELECT sv.*, ST_Distance(sv.coordinates::geography, ST_MakePoint(:lng, :lat)::geography) as distance
    FROM station_version sv
    JOIN station s ON sv.station_id = s.id
    WHERE s.status = 'PUBLISHED'
    AND sv.service_type = :serviceType
    AND ST_DWithin(sv.coordinates::geography, ST_MakePoint(:lng, :lat)::geography, :radiusMeters)
    ORDER BY distance
    """, nativeQuery = true)
```

#### 2. GPS Verification with Haversine Distance

**Problem**: Validating that a collaborator physically visited a station (not just submitting photos from elsewhere) using only mobile GPS.

**Solution**: Custom `LatLngUtils.haversineDistance()` implementation in `common` module. Server-side distance computation prevents client-side GPS spoofing. The 200-meter radius threshold balances practicality with security.

**Code Evidence**: `LatLngUtils.java` implements the Haversine formula, used in `VerificationCheckinController.java`.

#### 3. Station Versioning Workflow

**Problem**: Supporting both creation and update of station information through a single approval workflow, while maintaining a complete history of changes and enabling rollback.

**Solution**: `station_version` table with `status` field, managed through `ChangeRequest` lifecycle. Every approved change creates a new version snapshot. The `StationService` handles publishing by updating the active version reference.

#### 4. Trust Score Computation

**Problem**: Creating an explainable, multi-factor trust score for stations that can be communicated to both admins and station owners.

**Solution**: `StationTrust` entity with component scores (uptime, verification, rating). `TrustService.recalculateTrust()` aggregates factors with configurable weights. The breakdown is stored in the entity for transparency.

### 12.2 Creative or Non-Obvious Design Decisions

| Decision | Rationale |
|----------|-----------|
| **OpenAPI as single source of truth** | API spec (`shared/openapi/`) generates the Dart API client (`shared_api` package), ensuring backend-frontend consistency without manual client maintenance |
| **Shared Flutter packages** | `shared_api`, `shared_auth`, `shared_network`, `shared_ui` are packages that all four Flutter apps depend on, reducing code duplication across platforms |
| **Change Request pattern** | Using `ChangeRequest` as a first-class entity (not just a status field) enables audit trail, rejection reasons, risk score storage, and multi-stage review |
| **MinIO for file storage** | S3-compatible storage separates binary uploads from database, enabling horizontal scaling of file serving |
| **Booking HOLD status with expiry** | 5-minute hold window simulates real-world payment flow while preventing indefinite slot reservation; prevents need for complex distributed locking |
| **Risk scoring on submission** | Automatic risk calculation at submission time provides early warning for problematic submissions before admin review |

### 12.3 Performance Optimizations

| Optimization | Implementation |
|-------------|----------------|
| **PostGIS geospatial indexes** | GIST index on `coordinates` column for fast radius queries |
| **Redis caching** | Session tokens and frequently-accessed station data cached |
| **Pagination with max limit** | `@PageableMax(size = 100)` prevents oversized responses |
| **Presigned URLs for uploads** | Large files uploaded directly to MinIO, bypassing the backend API server |
| **Stateless backend (JWT)** | No server-side session affinity; enables horizontal scaling |
| **Flutter web with CDN** | Built Flutter web apps served by nginx with gzip compression |

### 12.4 Security Measures Implemented

| Measure | Implementation |
|---------|----------------|
| **JWT with expiration** | 24-hour token expiry; refresh token pattern [TO VERIFY] |
| **BCrypt password hashing** | All passwords hashed before storage |
| **Role-based authorization** | Spring Security method-level security (`@PreAuthorize`) |
| **Input validation** | Bean Validation on all DTOs at controller boundary |
| **File type restrictions** | `@AllowedFileTypes` annotation restricts uploads to images only |
| **SQL injection prevention** | All queries use JPA/Hibernate parameterized queries |
| **CORS configuration** | Origins whitelist per environment |
| **Audit logging** | `audit_log` table tracks all admin actions with details |

### 12.5 What Makes This Project Stand Out

1. **Multi-client Flutter ecosystem**: Four Flutter applications (EV user mobile, admin web, collaborator web, collaborator mobile) sharing a common API client package, demonstrating scalable mobile architecture.
2. **GPS-based trust verification**: The combination of GPS check-in, proximity validation (Haversine), photo evidence, and admin review creates a robust anti-fraud mechanism for station verification.
3. **Domain-driven backend design**: Clean separation across domain modules (station, booking, verification, risk, trust, battery swap) with well-defined boundaries and dependencies.
4. **Full lifecycle management**: Stations go through a complete lifecycle from DRAFT → PENDING → PUBLISHED, with version history, risk scoring, and trust tracking.
5. **Dual service types**: Support for both traditional EV charging and battery swap in a single platform.
6. **Loyalty & Rewards ecosystem**: Comprehensive gamification system including points earning from multiple activities (bookings, swaps, ratings, referrals, badges), multi-tier voucher redemption, and referral-based user acquisition — a full loyalty loop that increases user retention.
7. **Production-ready infrastructure**: Docker-based deployment with nginx routing, MinIO storage, PostgreSQL/PostGIS, and Redis — a realistic production architecture suitable for a thesis demonstration.

---

## APPENDIX A: OpenAPI Specification Summary

The `shared/openapi/` directory contains `openapi.yaml` (OpenAPI 3.0.3 specification, ~3,000 lines) which defines all REST endpoints across all client applications. This spec is the authoritative source for API contracts.

Key API groups:
- **Authentication**: `POST /auth/register`, `POST /auth/login`, `POST /auth/logout`
- **EV Stations**: `GET/POST /api/ev/stations`, `GET /api/ev/stations/{id}`, `GET /api/ev/stations/{id}/charger-units`
- **EV Bookings**: `POST/GET /api/ev/bookings`, `DELETE /api/ev/bookings/{id}`
- **EV Payments**: `POST /api/ev/payments/create-intent`, `POST /api/ev/payments/simulate-success`, `POST /api/ev/payments/simulate-failure`
- **Collaborator Stations**: `POST /api/collab/web/stations`, `POST /api/collab/web/stations/{id}/submit`
- **Collaborator Tasks**: `GET /api/collab/mobile/tasks`, `POST /api/collab/mobile/tasks/{id}/checkin`, `POST /api/collab/mobile/tasks/{id}/evidence`
- **Collaborator Profile**: `GET /api/collab/web/profile`, `GET /api/collab/web/contracts`
- **Admin Change Requests**: `GET/POST /api/admin/change-requests`, `POST /api/admin/change-requests/{id}/approve`, `POST /api/admin/change-requests/{id}/reject`
- **Admin Verification**: `GET/POST /api/admin/verification-tasks`, `POST /api/admin/verification-tasks/{id}/review`
- **Admin Issues**: `GET/PATCH /api/admin/issues`, `PATCH /api/admin/issues/{id}/acknowledge`, `PATCH /api/admin/issues/{id}/resolve`
- **Admin Trust**: `GET /api/admin/stations/{id}/trust`
- **Admin Audit**: `GET /api/admin/audit-logs`
- **EV Loyalty**: `GET /api/ev/loyalty/me`, `GET /api/ev/loyalty/points/history`, `GET/POST /api/ev/loyalty/ratings`, `GET /api/ev/loyalty/badges`, `POST /api/ev/loyalty/referral/generate`, `GET /api/ev/loyalty/vouchers`, `POST /api/ev/loyalty/vouchers/{id}/redeem`, `GET /api/ev/loyalty/vouchers/mine`, `POST /api/ev/loyalty/vouchers/redemptions/{id}/apply-to-booking`
- **Admin Loyalty**: `GET /api/admin/loyalty/dashboard`, `GET /api/admin/loyalty/users`, `POST /api/admin/loyalty/users/{id}/adjust`, `GET/POST /api/admin/loyalty/vouchers`, `GET/POST /api/admin/loyalty/redemptions`

---

*Document generated for VoltGO graduation thesis. All technical details extracted from source code. Verify with actual code during thesis writing.*
