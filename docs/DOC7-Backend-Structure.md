# DOC 7 — Backend Structure (Spring Boot)

---

## 7.1 Package Structure

The backend is a standard Spring Boot application (`com.example.evstation`). It follows a **feature-first layered architecture** — packages are grouped by feature rather than by layer type:

```
src/main/java/com/example/evstation/
├── EvStationApplication.java          # @SpringBootApplication entry point
│
├── api/
│   ├── auth/                          # Authentication endpoints
│   │   └── AuthController.java
│   ├── common/                        # Shared utilities (file upload, presigned URLs)
│   │   ├── dto/
│   │   └── controller/
│   │       └── FileController.java
│   ├── public/                        # Public station listing (no auth)
│   │   └── PublicBatterySwapController.java
│   ├── ev_user_mobile/                # EV driver mobile API
│   │   ├── controller/
│   │   │   ├── BookingController.java
│   │   │   ├── AvailabilityController.java
│   │   │   ├── EvBatterySwapController.java
│   │   │   ├── EvLoyaltyController.java
│   │   │   ├── EvUserMobileController.java
│   │   │   ├── ChargerUnitController.java
│   │   │   ├── ChangeRequestController.java
│   │   │   ├── PaymentController.java
│   │   │   ├── IssueController.java
│   │   │   └── EvUserAiController.java
│   │   ├── dto/
│   │   └── mapper/
│   ├── collaborator_mobile/           # Field collaborator mobile API
│   │   ├── controller/
│   │   │   ├── CollaboratorMobileController.java
│   │   │   └── CollaboratorChangeRequestController.java  # NEW 2026-06 — CR endpoints for collaborators
│   │   ├── dto/
│   │   └── mapper/
│   ├── collaborator_web/              # Collaborator web portal API
│   │   ├── controller/
│   │   │   ├── CollaboratorWebController.java
│   │   │   └── CollaboratorWebNotificationController.java
│   │   ├── dto/
│   │   └── mapper/
│   └── admin_web/                     # Admin web portal API
│       ├── controller/
│       │   ├── AdminDashboardController.java
│       │   ├── AdminStationController.java
│       │   ├── AdminChangeRequestController.java
│       │   ├── AdminCollaboratorController.java
│       │   ├── AdminLoyaltyController.java
│       │   ├── AdminIssueController.java
│       │   ├── AdminAuditController.java
│       │   ├── AdminBatterySwapStationController.java
│       │   ├── AdminBatterySwapChangeRequestController.java
│       │   ├── AdminRegistrationRequestController.java
│       │   ├── AdminVerificationController.java
│       │   └── AdminFileController.java
│       ├── dto/
│       └── mapper/
│
├── domain/                            # Core business logic
│   ├── auth/                          # Auth utilities
│   │   ├── JwtTokenProvider.java      # JWT generation/validation
│   │   └── PasswordHashGenerator.java # BCrypt hashing
│   ├── booking/                       # Booking business logic
│   │   └── BookingService.java
│   ├── battery_swap/                  # Battery swap core
│   │   ├── BatterySwapService.java    # Updated 2026-06-20: JOIN refactor + providerId field
│   │   ├── SwapSessionService.java
│   │   ├── SwapCodeService.java
│   │   ├── BatteryChargingSimulationJob.java
│   │   ├── ExpireBatterySwapReservationsJob.java
│   │   └── broadcast/
│   │       └── BatterySwapBroadcastService.java
│   ├── availability/
│   │   └── AvailabilityService.java
│   ├── risk/                          # Risk assessment engines
│   │   ├── RiskEngineService.java     # Standard station CR risk
│   │   └── BatterySwapRiskAssessor.java # Battery swap CR risk
│   ├── trust/                         # Trust scoring
│   │   ├── TrustScoringService.java   # Station trust
│   │   └── BatterySwapTrustScoringService.java
│   ├── verification/
│   │   └── VerificationService.java
│   ├── loyalty/
│   │   ├── LoyaltyPointService.java
│   │   ├── BadgeService.java
│   │   ├── VoucherService.java
│   │   └── ReferralService.java
│   ├── station/
│   │   └── StationService.java
│   ├── change_request/
│   │   └── ChangeRequestService.java   # Updated 2026-06-20: parking fallback UNKNOWN
│   ├── collaborator/
│   │   ├── CollaboratorRegistrationRequestService.java
│   │   └── CollaboratorService.java
│   ├── recommendation/
│   │   ├── RecommendationQueryService.java
│   │   └── EvUserAiService.java
│   ├── notification/
│   │   ├── FCMService.java
│   │   └── EmailService.java
│   └── routing/
│       └── RoutingService.java
│
├── data/                              # Data access layer
│   ├── entity/                        # JPA entities
│   │   ├── UserAccount.java
│   │   ├── Station.java
│   │   ├── StationVersion.java
│   │   ├── ChargingPort.java
│   │   ├── ChargerUnit.java
│   │   ├── Booking.java
│   │   ├── PaymentIntent.java
│   │   ├── BatterySwapReservation.java
│   │   ├── SwapSession.java
│   │   ├── SwapPayment.java
│   │   ├── BatterySlot.java
│   │   ├── SwapPile.java
│   │   ├── BatteryEvent.java
│   │   ├── ChargingSession.java
│   │   ├── ChangeRequest.java
│   │   ├── ReportIssue.java
│   │   ├── AuditLog.java
│   │   ├── StationTrust.java
│   │   ├── BatterySwapTrust.java
│   │   ├── CollaboratorProfile.java
│   │   ├── Contract.java
│   │   ├── CollaboratorRegistrationRequest.java
│   │   ├── Referral.java
│   │   ├── VerificationTask.java
│   │   ├── VerificationCheckin.java
│   │   ├── VerificationEvidence.java
│   │   ├── VerificationReview.java
│   │   ├── LoyaltyUserProfile.java
│   │   ├── LoyaltyPointTransaction.java
│   │   ├── LoyaltyBadge.java
│   │   ├── UserBadge.java
│   │   ├── StationRating.java
│   │   ├── RatingEligibility.java
│   │   ├── VoucherDefinition.java
│   │   ├── VoucherRedemption.java
│   │   ├── BatterySwapStationState.java
│   │   ├── BatterySwapStationVersion.java
│   │   ├── BatterySwapPileTemplate.java
│   │   ├── BatterySwapSlotTemplate.java
│   │   ├── BatterySwapStationDevice.java
│   │   ├── StationService.java
│   │   ├── EvUserNotification.java
│   │   ├── CollaboratorNotification.java
│   │   ├── PushToken.java
│   │   └── NotificationPreference.java
│   └── repository/                     # Spring Data JPA repositories
│       ├── UserAccountRepository.java
│       ├── StationRepository.java
│       ├── StationVersionRepository.java
│       ├── BookingRepository.java
│       ├── BatterySwapReservationRepository.java
│       ├── SwapSessionRepository.java
│       ├── SwapPileRepository.java
│       ├── BatterySlotRepository.java
│       ├── ChangeRequestRepository.java
│       ├── StationTrustRepository.java
│       ├── BatterySwapTrustRepository.java
│       ├── CollaboratorProfileRepository.java
│       ├── VerificationTaskRepository.java
│       ├── LoyaltyUserProfileRepository.java
│       ├── LoyaltyPointTransactionRepository.java
│       ├── LoyaltyBadgeRepository.java
│       ├── VoucherDefinitionRepository.java
│       ├── VoucherRedemptionRepository.java
│       ├── StationRatingRepository.java
│       ├── AuditLogRepository.java
│       └── [etc.]
│
├── config/                            # Spring configuration
│   ├── SecurityConfig.java            # Spring Security filter chain
│   ├── JwtAuthenticationFilter.java  # JWT extraction and auth
│   └── WebSocketConfig.java          # WebSocket endpoint registration
│
└── util/                              # Utilities
    ├── HaversineCalculator.java       # GPS distance calculation
    └── PresignedUrlGenerator.java    # MinIO presigned URL generation
```

---

## 7.2 Security Configuration

### `SecurityConfig.java`

Defines the Spring Security filter chain. Key configuration:

- **Stateless session:** `SESSION` creation is disabled. All requests must carry a valid JWT.
- **CSRF disabled:** REST API, no browser-based CSRF risk.
- **Public routes:** `/api/auth/**`, `/api/public/**`, `/api/files/{key}` (GET), `/ws/**`, `/swagger-ui/**`, `/v3/api-docs/**` — bypass JWT validation.
- **Protected routes:** All other `/api/**` routes require authentication.
- **JWT Filter order:** `JwtAuthenticationFilter` is placed before `UsernamePasswordAuthenticationFilter`.
- **Role hierarchy:** `ADMIN` > `COLLABORATOR` > `EV_USER`.
- **CORS:** Configured for local dev (localhost:xxx ports).

### `JwtAuthenticationFilter.java`

Intercepts every protected request:

1. Extracts `Authorization: Bearer <token>` header.
2. Validates signature using secret key from `VoltGoProperties`.
3. Extracts claims: `userId`, `email`, `role`, `status`.
4. Builds `UsernamePasswordAuthenticationToken` with roles from JWT claims.
5. Special handling: if `role == PENDING_COLLABORATOR`, upgrades to full `COLLABORATOR` if the collaborator has completed registration.

**Role-based access (via `@PreAuthorize` annotations on controllers):**

| Role | Access |
|---|---|
| `EV_USER` | `/api/stations/**`, `/api/bookings/**`, `/api/battery-swap/**`, `/api/loyalty/**`, `/api/ai/**`, `/api/users/me/**` |
| `COLLABORATOR` | All EV_USER endpoints + `/api/collaborator/**`, `/api/collab-web/**` |
| `ADMIN` | All endpoints + `/api/admin/**` |
| `PUBLIC` | `/api/auth/**`, `/api/public/**`, `/api/files/{key}` |

---

## 7.3 Design Patterns

### Repository Pattern

Every data access goes through a Spring Data JPA `Repository` interface. The repository is injected into the service layer:

```java
@Service
public class BookingService {
    private final BookingRepository bookingRepository;

    public BookingService(BookingRepository bookingRepository) {
        this.bookingRepository = bookingRepository;
    }

    public Booking createBooking(...) {
        // business logic
        return bookingRepository.save(booking);
    }
}
```

Method naming convention auto-generates queries: `findByUserIdAndStatus(...)`, `findBySwapCodeAndStatus(...)`.

### DTO / Mapper Pattern

Controllers accept and return DTOs (Data Transfer Objects). Mappers convert between entities and DTOs. The mapper layer (`api/*/mapper/`) uses simple hand-written static methods (`toDTO`, `toEntity`) rather than MapStruct or ModelMapper to avoid code generation complexity.

### Optimistic Locking

`BatterySlot` and `SwapSession` entities use JPA `@Version` for optimistic locking. This prevents race conditions when two concurrent requests try to update the same slot or session:

```java
@Entity
public class BatterySlot {
    @Version
    private Long version;
    // ...
}
```

If a concurrent update is detected, Hibernate throws `OptimisticLockException`, which the service catches and re-throws as a `409 Conflict`.

### Service Layer

Business logic is encapsulated in `@Service` classes. Services are injected into controllers. No business logic in controllers or repositories.

### Exclusion Constraint (Database-Level)

The booking overlap check uses a PostgreSQL `EXCLUDE USING gist` constraint via Flyway migration. This guarantees no double-booking at the database level, even if two simultaneous requests bypass application-layer checks.

---

## 7.4 Background Jobs (Scheduled Tasks)

Four `@Scheduled` jobs run on fixed delays:

| Job | Schedule | Class | Purpose |
|---|---|---|---|
| **Booking Expiry** | Every 60s | `ExpireBookingJob` | Finds all `HOLD` bookings past `holdExpiresAt`, sets status to `EXPIRED` |
| **Battery Charging Simulation** | Every 30s | `BatteryChargingSimulationJob` | Increments `battery_charge_percent` on `AVAILABLE` slots, creates `ChargingSession` records, handles completion |
| **Swap Reservation Expiry** | Every 60s | `ExpireBatterySwapReservationsJob` | Cancels `RESERVED` reservations past `expiresAt`, releases slots |
| **Swap Session Expiry** | Every 60s | `SwapCodeService.expirePendingSessions()` | Expires `PENDING` swap sessions past `expires_at`, releases slots |

**Example — Booking Expiry:**

```java
@Scheduled(fixedRate = 60000)
public void expireHoldBookings() {
    var expired = bookingRepository.findExpiredHolds(Instant.now());
    for (var booking : expired) {
        booking.setStatus(BookingStatus.EXPIRED);
        bookingRepository.save(booking);
    }
}
```

---

## 7.5 Error Handling Strategy

The current implementation relies on Spring Boot's default `BasicErrorController` behavior. No custom `GlobalExceptionHandler` exists in the codebase.

**Known gaps:**
- No `@ControllerAdvice` for centralized exception handling.
- No custom exception classes (e.g., `ResourceNotFoundException`, `BookingConflictException`).
- Validation errors propagate as generic 400 Bad Request from Spring's default handler.
- No structured error response DTO wrapping all errors consistently.

**All error responses** fall back to Spring's default format:

```json
{
  "timestamp": "2024-12-20T10:00:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "...",
  "path": "/api/bookings"
}
```

---

## 7.6 External Integrations

| Service | Integration | Implementation |
|---|---|---|
| **OSRM Router** | `RoutingService` | HTTP GET to `router.project-osrm.org/route/v1/driving/{lng1},{lat1};{lng2},{lat2}`. Parses JSON response for `distance` and `duration`. Used for travel time estimation in recommendations. |
| **FCM Push Notifications** | `FCMService` | Stubbed: logs push payload to console. No Firebase Admin SDK initialized. `fcmToken` is stored on `UserAccount` but not used. |
| **Email** | `EmailService` | Uses Spring `JavaMailSender`. `@Async` for non-blocking send. Logs to console when `email.enabled=false`. HTML template defined inline as a string. |
| **MinIO** | `PresignedUrlGenerator` | Generates pre-signed upload/download URLs via MinIO Java SDK. `FileController` handles direct proxy upload via `web-driven` transfer. |
| **Redis** | `Spring Data Redis` | `RedisTemplate` used for caching. `BatterySwapBroadcastService` uses Redis pub/sub to fan out WebSocket messages. |

---

## 7.7 Configuration (application.yml)

Key Spring Boot configuration properties:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/voltgo
    username: ${DB_USER}
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      idle-timeout: 300000
      connection-timeout: 20000

  jpa:
    hibernate:
      ddl-auto: validate   # Schema managed by Flyway only
    open-in-view: false
    properties:
      hibernate:
        dialect: org.hibernate.spatial.dialect.postgis.PostgisPG10Dialect

  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true

  data:
    redis:
      host: ${REDIS_HOST}
      port: 6379

voltgo:
  jwt:
    secret: ${JWT_SECRET}
    expiration-ms: 86400000  # 24 hours
  minio:
    endpoint: ${MINIO_ENDPOINT}
    access-key: ${MINIO_ACCESS_KEY}
    secret-key: ${MINIO_SECRET_KEY}
    bucket: voltgo
  battery-swap:
    hold-minutes: 30
    session-minutes: 30
  email:
    enabled: false
  osrm:
    base-url: https://router.project-osrm.org
  app:
    recommendation:
      default-radius-meters: 10000
      default-target-battery-level: 80
```
