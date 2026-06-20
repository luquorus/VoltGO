# DOC 9 — Testing & Evaluation Notes

---

## 9.1 Types of Tests in the Codebase

| Test Type | Coverage | Location |
|---|---|---|
| **Unit Tests (Java)** | Minimal — only `RiskEngineServiceTest` | `backend/src/test/java/com/example/evstation/risk/application/RiskEngineServiceTest.java` |
| **Unit Tests (Dart/Flutter)** | None — only default `widget_test.dart` stubs | `apps/*/test/widget_test.dart` |
| **API Smoke Test** | Basic, generated | `backend/src/test/java/com/example/evstation/auth/util/PasswordHashGenerator.java` (this is a utility, not a test) |
| **Integration Tests** | None found | — |
| **End-to-End Tests** | None found | — |
| **Manual Testing** | Not tracked in code | — |

---

## 9.2 Test File Details

### `RiskEngineServiceTest.java`

**Path:** `backend/src/test/java/com/example/evstation/risk/application/RiskEngineServiceTest.java`

This is the only meaningful test in the backend. It covers:

**Test cases:**

1. **Standard station — Haversine GPS change** (`assessChangeRequest_shouldDetectGpsChange`) — Creates a `UPDATE_STATION` change request where the GPS coordinates shift by more than 100 meters. Expects `GPS_CHANGED_100M` reason with score contribution of 50.

2. **Standard station — Port multiset comparison** (`assessChangeRequest_shouldDetectPortChanges`) — Creates an `UPDATE_STATION` request where the set of charging ports changes (different power type or power kw). Expects `PORTS_CHANGED` reason with score contribution of 30.

3. **Battery swap — Battery count change** (`assessBatterySwapStationChange_shouldDetectBatteryCountChange`) — Creates a `UPDATE_BATTERY_SWAP_STATION` request where `totalBatteries` changes. Expects `BATTERY_COUNT_CHANGED` reason with score contribution of 20.

**Coverage assessment:** The test covers the Haversine formula implementation and port multiset comparison. However, it does not cover: low inventory checks, hours changed, access changed, or any battery swap safety risk factors.

### Manual test cases for **Collaborator Change Request feature** (NEW 2026-06)

These should be executed end-to-end before each release. The full checklist is mirrored in `changelog.md` § "Proposed test cases".

1. **CR creation — charging** — Authenticate as a collaborator. From the new *Requests* tab → tap *+* → choose *Charging* → fill station ID + change rationale + at least one modified field → save as DRAFT. Expect: row appears in the list with status `DRAFT`.
2. **CR submission — charging** — Open the DRAFT above → tap *Submit*. Expect: status becomes `PENDING`. The creator receives an in-app notification (category `CHANGE_REQUEST`, type `CR_SUBMITTED`).
3. **CR approval** — Sign in as admin, open the same CR → tap *Approve*. Expect: status becomes `APPROVED`. The collaborator receives a notification of type `CR_APPROVED`.
4. **CR rejection** — Admin rejects a different CR with a reason. Expect: status `REJECTED`, collaborator receives `CR_REJECTED` notification containing the reason.
5. **CR publishing** — Admin publishes an approved CR. Expect: status `PUBLISHED`, station data is updated, collaborator receives `CR_PUBLISHED` notification.
6. **CR creation — battery swap** — Repeat (1)–(2) with the *Battery swap* type. Same status transitions and notifications must be observed.
7. **Performance metrics** — Open admin *Collaborator Performance*. Expect two new columns *CRs* (published/total) and *CR Publish %*. The values must match counts in DB. Detail page must show the same four metrics (`totalChangeRequests`, `publishedChangeRequests`, `rejectedChangeRequests`, `changeRequestPublishRate`).
8. **Bottom navigation** — Open the collaborator app. Expect a sixth tab *Requests* between *Swap* and *Notifications*. Selecting it navigates to `/change-requests`.
9. **Authz negative** — Hit `/api/collab/mobile/change-requests/**` with an EV_USER JWT. Expect `403 Forbidden`.

### Manual test cases for **Station search & auto-fill + Self-assign guard** (NEW 2026-06-14)

10. **Search shows results** — Authenticate as a collaborator, open *New change request* → set *Action = Update* → type a known station name (≥ 2 chars) in the search box. Expect: a list of matching published stations appears with name, address and station ID.
11. **Auto-fill populates the form** — Pick a result from the list. Expect: `Station ID`, name, address, lat, lng, operating hours, the list of charging ports, and (when present) `totalBatteries` + `avgChargePowerKw` are filled in. A success toast `Đã điền thông tin trạm` is shown.
12. **Self-assign — charging** — Sign in as collaborator A and submit a charging-station CR → wait for admin to create the verification task from it. Sign in as admin, open the candidate list, pick A again, then *Assign*. Expect: `409 Conflict` with the message `Cannot assign this verification task to the same collaborator who submitted the originating change request…`.
13. **Self-assign — battery swap** — Repeat (12) with a battery-swap CR. Expect the same `409 Conflict`.
14. **Self-assign audit log** — Open the audit log for the task that was blocked in (12)/(13). Expect a row with action `BLOCK_SELF_ASSIGN` and metadata listing `taskId`, `attemptedAssignee`, `crSubmitter`, `crKind`, `changeRequestId`, and the `reason` field.

### Manual test cases for **EV User mobile Home Map redesign + Ratings & Reviews + providerId/parking** (NEW 2026-06-20)

15. **Home Map single search bar** — Open the EV user app, navigate to *Home Map*. Type a station name in the search bar. Expect: a list of suggested stations appears (debounced ~500ms). Type a destination address. Expect: route suggestions appear in the same bar. The two are merged in one input.
16. **Tab Charging does not show battery-swap-only stations** — Switch the bottom sheet to *Charging* mode. Expect: the list shows only stations with charging ports. Battery-swap-only stations (no `station_service` row of `CHARGING` type) should not appear even if they are within the radius.
17. **Filter bottom sheet** — Tap the *Filter* icon. Expect: a modal bottom sheet appears (not an AlertDialog) with 3 sections: *Distance* (chips 2/5/10/20 km + slider 1–50 km), *Minimum power* (chips Any/22 kW+/50 kW+/100 kW+), *Charger type* (chips Any/AC/DC Fast). Apply filters and verify the list refreshes.
18. **Selected Station Preview** — Tap a station marker on the map. Expect: a large preview card appears with name, address, distance, trust score, ports/batteries, and 2 action buttons *Route* (Outlined) + *Book* (Filled). For battery-swap-only stations the second button shows *Reserve* with a battery icon.
19. **Ratings & Reviews on charging station detail** — Open a charging station detail page. Scroll to the bottom. Expect: a *Ratings & Reviews* section rendered by the reusable `StationRatingSection` widget showing average rating, star count, and a per-star breakdown. If the user is eligible to rate, the button reads *Rate this station*; otherwise *View all ratings*.
20. **Ratings & Reviews on battery swap screen** — Open the Battery Swap tab → tap a station. Scroll to the bottom. Expect: the same *Ratings & Reviews* widget appears in `compact` mode.
21. **Change Request with no parking** — In the EV user app, create a new Change Request for an existing charging station. Do **not** select a value in the *Parking* dropdown. Submit. Expect: 200 OK (previously would have been 400 because `parking` was `@NotNull`).
22. **Change Request with explicit parking** — Create a Change Request and pick *STREET_PARKING* from the new dropdown. Submit. Expect: 200 OK. Verify the new station version (if approved) has `parking = STREET_PARKING` in DB.
23. **`BatterySwapStationDTO.providerId` present** — Hit `GET /api/ev/battery-swap/stations?lat=…&lng=…&radiusKm=…` with a valid EV user JWT. Expect: every item has a `providerId` field (may be `null` for legacy records). For a station created by the admin via the admin UI, expect `providerId == adminId`.
24. **VoltGo seed battery-swap stations visible** — `GET /api/ev/battery-swap/stations` should now return V124/V125 VoltGo-seeded stations (previously these were dropped because the old `bsv.id = sv.id` join did not match for seed data).

### Flutter `widget_test.dart` Files

Each app has a default `widget_test.dart` created by `flutter create`. These are the default counter app tests and do not test any actual application code:

- `apps/ev_user_mobile/test/widget_test.dart`
- `apps/admin_web/test/widget_test.dart`
- `apps/collab_mobile/test/widget_test.dart`

### `PasswordHashGenerator.java` (Not a Test)

**Path:** `backend/src/test/java/com/example/evstation/auth/util/PasswordHashGenerator.java`

This is a standalone utility class for generating BCrypt password hashes, not a unit test class. It is used to pre-generate hashed passwords for database seeding.

---

## 9.3 Performance Considerations Visible in Code

### Database Performance

**PostGIS Spatial Index**
The `station_version.location` column is a `GEOGRAPHY(POINT, 4326)` type with a GiST index (`idx_station_version_location`). This makes nearby-station queries O(log n) instead of O(n) full-table scan.

**Booking Exclusion Constraint**
A PostgreSQL `EXCLUDE USING gist` constraint prevents double-booking at the database level:
```sql
ALTER TABLE booking ADD CONSTRAINT ck_booking_no_overlap_active
  EXCLUDE USING gist (
    charger_unit_id WITH =,
    tstzrange(start_time, end_time) WITH &&
  ) WHERE (status IN ('HOLD', 'CONFIRMED'));
```
This eliminates race conditions where two simultaneous booking requests could double-book the same slot.

**HikariCP Connection Pool**
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      idle-timeout: 300000
      connection-timeout: 20000
```
Connection pool sized appropriately for a single-instance deployment.

**Read-Only Transactions**
Services use `@Transactional(readOnly = true)` for queries to benefit from Hibernate's read-only query optimizations.

**Pagination**
All list endpoints use Spring Data's `Pageable` parameter with `Page<T>` return type. Default page size and max page size enforced.

**Native SQL for PostGIS**
PostGIS spatial queries are written as native SQL in `@Query` annotations rather than JPQL, ensuring the SQL is not modified by Hibernate's query processor:
```java
@Query(value = """
    SELECT s.*, sv.latitude, sv.longitude,
      ST_Distance(sv.location, ST_MakePoint(:lng, :lat)::geography) AS distanceMeters
    FROM station s ...
    """, nativeQuery = true)
```

### Application Performance

**Optimistic Locking**
`BatterySlot` and `SwapSession` use JPA `@Version` for optimistic locking, preventing concurrent slot update race conditions.

**Async Email**
`EmailService` uses `@Async` to send emails without blocking the HTTP request thread:
```java
@Async
public void sendEmail(...) { ... }
```

**Redis (Configured but Underutilized)**
Redis is configured (`spring.data.redis`) but the current implementation does not use it for caching. `BatterySwapBroadcastService` uses Redis pub/sub for WebSocket fan-out. Booking hold tokens are stored in DB, not Redis.

**Scheduled Jobs**
Four `@Scheduled` jobs run on fixed intervals:
- Booking expiry: every 60s
- Battery charging simulation: every 30s
- Swap reservation expiry: every 60s
- Swap session expiry: every 60s

---

## 9.4 Known Limitations

### 1. Battery Swap Safety Risk Checks Are Stubs

The `BatterySwapRiskAssessor` declares `BatterySwapRiskReason` entries for safety checks, but the actual evaluation logic is not implemented:

| Stubbed Reason | Declared Score | Implementation Status |
|---|---|---|
| `SENSITIVE_AREA` | +25 | No check — always 0 |
| `SAFETY_CONCERN` | +35 | No check — always 0 |
| `MISSING_SAFETY_EQUIPMENT` | +30 | No check — always 0 |
| `ENVIRONMENTAL_RISK` | +25 | No check — always 0 |
| `HIGH_REJECTION_RATE` | +20 | Not checked — always 0 |
| `PRICE_DEVIATION` | +20 | Not checked — always 0 |
| `PENDING_VERIFICATIONS` | +15 | Not checked — always 0 |

These contribute to the risk score as "potential" factors but do not affect the actual assessment until implemented.

### 2. Payment System Is Fully Mocked

`PaymentService` has two methods: `simulateSuccessPayment` and `simulateFailPayment`. No real payment gateway integration exists. The `SwapPayment` and `PaymentIntent` entities are ready to store real transaction data but are not connected to any payment provider.

**Recommendation for future work:** Integrate with VNPay, MoMo, or Stripe. The payment intent structure is already in place — only the service implementation needs to change.

### 3. FCM Push Notifications Are Stubbed

`FCMService` logs push notification payloads to the console:

```java
// FCMService.java (stubbed)
log.info("Sending push notification to user {}: title='{}', body='{}'",
    userId, title, body);
```

No Firebase Admin SDK is initialized, no `google-services.json` exists, and no FCM dependency is in `build.gradle`. The `fcmToken` field on `UserAccount` is populated but never used for delivery.

### 4. Email Delivery Is Stubbed

`EmailService` sends emails via Spring `JavaMailSender` but logs to console when disabled:

```java
if (!emailEnabled) {
    log.info("[EMAIL STUB] To: {}, Subject: {}", to, subject);
    return;
}
```

No SMTP server is configured in `application.yml` for production. No email templates are loaded from external files.

### 5. Hardware Simulator Is Display-Only

The `hardware_simulator` app receives swap codes via WebSocket and displays them on screen. There is no real OCPP (Open Charge Point Protocol) integration with physical charging hardware. The simulator is a proof-of-concept UI for the swap code verification workflow.

### 6. Clock Dependency Not Abstracted

Many services call `Instant.now()` or `LocalDateTime.now()` directly:

```java
Instant.now()     // BatterySwapService.java
LocalDateTime.now() // BookingService.java
```

This makes unit testing time-dependent logic (e.g., booking expiry) difficult because there is no `Clock` abstraction. In a production system, this should be injected as a `Clock` bean.

### 7. No GlobalExceptionHandler

There is no `@ControllerAdvice` class in the codebase. All error responses are generated by Spring Boot's default `BasicErrorController`. This means:
- No consistent error response structure across all endpoints.
- No custom exception classes (e.g., `ResourceNotFoundException`, `BookingConflictException`).
- Validation error messages may vary across endpoints.

### 8. Referrals Not Fully Integrated

The `Referral` entity and `ReferralService` are implemented, but:
- No UI flow exists for applying a referral code during registration (the API endpoint exists but no frontend implements it).
- `ReferralService.completeReferralOnFirstBooking` is not called by any booking service — referrals remain in `PENDING` status forever.

### 9. AI Recommendations Are Heuristic-Only

`EvUserAiService` and `RecommendationQueryService` provide personalized recommendations using rule-based scoring:
- Hardcoded default vehicle capacity: `50.0 kWh`
- Hardcoded charging efficiency: assumed linear
- No machine learning model is deployed or referenced in the codebase.

---

## 9.5 Deployment Status

- **Not deployed** — no production, staging, or public environment exists.
- **Local development** via `./gradlew bootRun` or `flutter run`.
- **Docker Compose** available for running the full stack locally (`docker-compose.yml`).
- **No CI/CD pipelines** — no GitHub Actions, GitLab CI, or Jenkins.
- **No production hosting** — no cloud provider (AWS, GCP, Azure, or Vietnamese providers like Viettel Cloud).

---

## 9.6 Database Migration Summary (Flyway)

47 migration files in `backend/src/main/resources/db/migration/` document the full schema evolution. Key migration milestones:

| Migration | Description |
|---|---|
| `V1__init_schema.sql` | Creates all core tables: user_account, station, station_version, charging_port, charger_unit, booking, payment_intent |
| `V2__battery_swap.sql` | Adds battery swap tables: swap_pile, battery_slot, swap_reservation, swap_session |
| `V3__add_location.sql` | Adds PostGIS geography columns to station_version and collaborator_profile |
| `V4__change_request.sql` | Adds change_request table with JSONB proposed_data |
| `V5__loyalty.sql` | Adds loyalty tables: loyalty_user_profile, loyalty_point_transaction, loyalty_badge, user_badge |
| `V6__vouchers.sql` | Adds voucher_definition and voucher_redemption |
| `V7__referral.sql` | Adds referral table |
| `V8__verification.sql` | Adds verification_task, verification_evidence, verification_checkin, verification_review |
| `V9__trust.sql` | Adds station_trust and battery_swap_trust tables |
| `V10__audit_log.sql` | Adds audit_log table |
| `V11__risk_engine.sql` | Adds risk-related columns to change_request |
| `V12__notifications.sql` | Adds ev_user_notification, collaborator_notification, push_token, notification_preference |
| `V13__device_key.sql` | Adds battery_swap_station_device with device_key |
| `V14__constraints.sql` | Adds PostgreSQL exclusion constraint on booking table |

**Seeding migrations** (suffix `_seed_*` or `_init_data.sql`):
- Seeds `loyalty_badge` with predefined badge definitions.
- Seeds `voucher_definition` with sample vouchers.
- Seeds test user accounts, stations, and collaborator profiles.
