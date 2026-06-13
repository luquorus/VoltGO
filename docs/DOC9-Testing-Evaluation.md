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
