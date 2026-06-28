# VoltGO Backend — Cấu trúc `src/main`

> Tài liệu mô tả tổng quan kiến trúc package `com.example.evstation` trong backend Spring Boot.

---

## 1. Tổng quan ứng dụng

**Tên**: VoltGO — Nền tảng quản lý trạm sạc & đổi pin xe điện (EV Charging & Battery Swap).

**Entry point**: `EvStationApplication.java`
- Annotation: `@SpringBootApplication`, `@EnableScheduling`, `@EnableAsync`
- Loại trừ auto-config: `UserDetailsServiceAutoConfiguration`

**Profiles** (`backend/src/main/resources/`):
- `application.yml` — cấu hình chung
- `application-local.yml` — PostgreSQL/Redis localhost, email tuỳ chọn
- `application-dev.yml` — PostgreSQL/Redis chạy trong Docker
- `application-docker.yml` — môi trường production-like với MinIO
- Mặc định: `local`

**Stack hạ tầng**:
- **Database**: PostgreSQL + PostGIS (truy vấn không gian)
- **Cache**: Redis (với fallback graceful — `ResilientCacheManager`)
- **Object storage**: MinIO (tương thích S3)
- **Email**: SMTP
- **Push notification**: Firebase Cloud Messaging (FCM)
- **Routing**: OSRM (Open Source Routing Machine)
- **Migration**: Flyway

**Layout tổng thể** (`src/main/java/com/example/evstation/`):

```
com.example.evstation/
├── api/                  ← Lớp REST API (entry point)
├── audit/                ← Concept only (chỉ có package-info)
├── auth/                 ← Xác thực, JWT, phân quyền
├── batteryswap/          ← Đổi pin: vòng đời + WebSocket
├── batteryswapchange/    ← Wrapper REST cho battery swap trust
├── booking/              ← Đặt chỗ sạc (HOLD → CONFIRMED)
├── collaborator/         ← Cộng tác viên: hồ sơ, hợp đồng, GPS
├── common/               ← Tiện ích chia sẻ (cache, lỗi, email…)
├── config/               ← Bean cấu hình dịch vụ ngoài
├── governance/           ← Concept only (workflow CR nằm ở station/bswap)
├── loyalty/              ← Điểm thưởng, huy hiệu, voucher, đánh giá
├── notification/         ← Thông báo in-app, push, email
├── payment/              ← Payment intent (giả lập gateway)
├── risk/                 ← Chấm điểm rủi ro cho Change Request
├── station/              ← CRUD trạm, versioning, CQRS
├── trust/                ← Chấm điểm uy tín trạm sạc
└── verification/         ← Task xác minh hiện trường + GPS check-in
```

**Phong cách kiến trúc**: DDD-lite theo bounded context. Các context nghiệp vụ lớn (`auth`, `station`, `batteryswap`, `booking`, `loyalty`, `verification`, `collaborator`, `notification`) đều có cấu trúc 4 lớp:

- `api/` — Controller + DTO
- `application/` — Service, use case, mapper
- `domain/` — Entity, value object, enum
- `infrastructure/` — JPA repository, JPA entity, adapter bên ngoài

---

## 2. Chi tiết từng package

### 2.1. `api` — Lớp REST API (entry point cho tất cả client)

- **Path**: `backend/src/main/java/com/example/evstation/api`
- **Subpackages**: `admin_web`, `collaborator_mobile`, `collaborator_web`, `ev_user_mobile`, `public_api`, `common`
- **Mục đích**: Cổng REST duy nhất cho mọi client. Mỗi subpackage ứng với một đối tượng người dùng cụ thể. Dùng annotation `@Tag` (Swagger) để nhóm API.
- **Các nhóm API chính**:
  - `api/admin_web` — Dashboard quản trị (stations, dashboard, collaborators, change-requests, issues, loyalty, audit-logs, files, registration requests)
  - `api/ev_user_mobile` — App người dùng EV (stations, bookings, battery-swap, payments, loyalty, charger-units, routing, availability, issues, change-requests, files, AI)
  - `api/collaborator_mobile` — App mobile của cộng tác viên (location, verification)
  - `api/collaborator_web` — Portal web cộng tác viên (profile, contracts, notifications, verification tasks)
  - `api/public_api` — API công khai (không cần JWT) cho màn hình hiển thị trạm + đăng ký công khai
  - `api/common` — DTO + controller dùng chung (file upload/download)

### 2.2. `audit` — Concept only

- **Path**: `backend/src/main/java/com/example/evstation/audit`
- **Mục đích**: Bounded context lý thuyết cho audit log. Hiện chỉ có `package-info.java`.
- **Lưu ý**: Thực tế audit log được lưu ở `AuditLogEntity` / `AuditLogJpaRepository` trong `station/infrastructure/jpa`. Các service khác (`AdminStationService`, `BookingService`…) ghi log thông qua `AuditLogService`.

### 2.3. `auth` — Xác thực & phân quyền

- **Path**: `backend/src/main/java/com/example/evstation/auth`
- **Subpackages**: `api`, `application`, `domain`, `infrastructure`
- **Mục đích**: Stateless JWT auth cho toàn bộ client. Quản lý tài khoản người dùng.
- **Các class chính**:
  - `AuthController` (`/auth/register`, `/auth/login`) — endpoint công khai, đăng ký role `EV_USER` hoặc `COLLABORATOR`
  - `UserProfileController` (`/auth/profile`) — xem/cập nhật hồ sơ
  - `SecurityConfig` — cấu hình Spring Security, JWT filter, public path (`/auth/**`, `/api/public/**`, `/api/ev/loyalty/public/**`, `/api/v1/battery-swap/trust/**`, `/ws/**`, `/swagger-ui/**`)
  - `JwtAuthenticationFilter` — trích Bearer token, validate, map claim `role` thành authority `ROLE_*`
  - `JwtTokenProviderImpl` — sinh và validate JWT
  - `LoginUseCase`, `RegisterUseCase` — application service
  - `UserAccount` — entity chính, có `Role` enum (`EV_USER`, `COLLABORATOR`, `ADMIN`) và `UserStatus`
  - `DataInitializer` — seed tài khoản admin đầu tiên

### 2.4. `batteryswap` — Đổi pin xe điện

- **Path**: `backend/src/main/java/com/example/evstation/batteryswap`
- **Subpackages**: `api`, `application`, `config`, `domain`, `infrastructure`
- **Mục đích**: Vòng đời hoàn chỉnh của trạm đổi pin: cấu hình trạm, quản lý slot, đặt chỗ, phiên đổi, giả lập thanh toán, màn hình realtime. Tích hợp điểm thưởng khi hoàn tất đổi pin.
- **Các class chính**:
  - `BatterySwapService` — đặt chỗ, thanh toán, quản lý vòng đời
  - `SwapSessionService` — xác minh mã đổi, hoàn tất phiên (cộng điểm loyalty)
  - `SwapCodeService` — sinh và quản lý mã đổi có thời hạn
  - `BatterySwapWebSocketHandler` — WebSocket cho operator (`/ws/battery-swap`), nhận lệnh `START_SWAP`, `COMPLETE_SWAP`
  - `SimulatorDisplayWebSocketHandler` — WebSocket cho màn hình trạm công cộng (`/ws/display/battery-swap`), broadcast trạng thái slot/pin
  - `BatterySwapWebSocketConfig` — đăng ký cả hai endpoint
  - `ExpireBatterySwapReservationsJob` — scheduled job gọi `expireStaleReservations`, `expireUnpaidReservations`, `expireSwapDeadline`, `expirePendingSessions`
  - `BatterySwapTrustScoringService` — chấm uy tín trạm đổi pin
  - `BatterySwapRiskAssessor` — chấm rủi ro cho Change Request của trạm đổi pin
  - `StationDeviceService` — quản lý key cho simulator/màn hình
  - `BatterySwapStationAdminService` — admin CRUD cấu hình trạm
  - `BatterySwapCsvImportService` — import CSV hàng loạt
  - **Domain entity**: `BatterySlotEntity`, `SwapPileEntity`, `SwapSessionEntity`, `BatterySwapReservationEntity`, `ChargingSessionEntity`, `BatteryEventEntity`, `BatterySwapStationStateEntity`
- **Lưu ý**: DDD layout chuẩn. Có WebSocket realtime với simulator phần cứng. `@EnableScheduling` chạy job expire định kỳ. Truy vấn không gian PostGIS cho tìm trạm lân cận.

### 2.5. `batteryswapchange` — Wrapper REST cho trust đổi pin

- **Path**: `backend/src/main/java/com/example/evstation/batteryswapchange`
- **Subpackages**: `web`
- **Mục đích**: Lớp mỏng bọc quanh battery swap trust scoring, expose REST tại `/api/v1/battery-swap/trust`.
- **Các class chính**:
  - `BatterySwapTrustController` (`GET/POST /api/v1/battery-swap/trust/{stationId}|/summary|/recalculate|/history`) — public; chỉ `POST /recalculate` và `GET /history` yêu cầu `ADMIN`
- **Lưu ý**: Toàn bộ endpoint `/api/v1/battery-swap/trust/**` được liệt kê public trong `SecurityConfig`.

### 2.6. `booking` — Đặt chỗ sạc

- **Path**: `backend/src/main/java/com/example/evstation/booking`
- **Subpackages**: `application`, `domain`, `infrastructure`
- **Mục đích**: Quản lý reservation cho slot sạc theo vòng đời `HOLD → CONFIRMED → COMPLETED/CANCELLED/EXPIRED`. Thanh toán giả lập qua context `payment`. Hỗ trợ redeem voucher.
- **Các class chính**:
  - `BookingService` — tạo booking HOLD (TTL 10 phút), huỷ, truy vấn; có ghi audit log
  - `BookingExpirationScheduler` — `@Scheduled(fixedDelay=60000)` huỷ booking HOLD quá hạn
  - `AvailabilityService` — tính slot còn trống cho một `ChargerUnit`
  - `ChargerUnitService` — quản lý trạng thái charger unit
  - `ChargerUnitCreationService` — tự động tạo charger unit khi station version được publish
  - **Domain**: `Booking`, `BookingEntity`, `ChargerUnitEntity`, `BookingStatus` (HOLD/CONFIRMED/CANCELLED/EXPIRED), `ChargerUnitStatus`
- **Lưu ý**: DDD layout. Có PostgreSQL exclusion constraint (`ck_booking_no_overlap_active`) chống double-booking. Scheduler duy nhất trong context là `BookingExpirationScheduler`.

### 2.7. `collaborator` — Hồ sơ & vị trí cộng tác viên

- **Path**: `backend/src/main/java/com/example/evstation/collaborator`
- **Subpackages**: `api`, `application`, `domain`, `infrastructure`
- **Mục đích**: Quản lý cộng tác viên từ lúc đăng ký → ký hợp đồng → trạng thái active. Theo dõi vị trí GPS.
- **Các class chính**:
  - `CollaboratorService` — tạo/xoá profile, tạo cộng tác viên + tài khoản trong một bước
  - `CollaboratorRegistrationRequestService` — submit, approve, reject đơn đăng ký
  - `ContractService` — CRUD hợp đồng
  - `ContractPolicyService` — kiểm tra cộng tác viên có hợp đồng active (dùng cho check-in, verification)
  - `CollaboratorLocationService` — cập nhật GPS từ mobile/web, tính khoảng cách Haversine
  - `CollaboratorWebVerificationController` — danh sách task, KPI, lịch sử cho portal web
  - **Domain**: `CollaboratorProfileEntity`, `ContractEntity`, `CollaboratorRegistrationRequestEntity`
  - **DTO**: `CollaboratorProfileDTO`, `ContractDTO`, `CollaboratorRegistrationRequestDTO`, …

### 2.8. `common` — Tiện ích chia sẻ (cross-cutting)

- **Path**: `backend/src/main/java/com/example/evstation/common`
- **Subpackages**: `config`, `error`, `file`, `infrastructure`, `web`
- **Mục đích**: Thành phần ngang dùng bởi mọi bounded context.
- **Các class chính**:
  - `RedisCacheConfig` + `ResilientCacheManager` — cache Redis có fallback graceful (không cache nếu Redis chết). Cấu hình TTL riêng theo vùng: `station` 5 phút, `booking` 2 phút, `bswap piles` 1 phút, …
  - `CacheNames` — hằng số tên vùng cache (`station`, `trust`, `loyalty`, `vouchers`, `badges`, `booking`, `bswap`, `collaborators`)
  - `ErrorCode` — toàn bộ mã lỗi (`NOT_FOUND`, `VALIDATION_ERROR`, `FORBIDDEN`, …)
  - `BusinessException` — domain exception có mã lỗi
  - `GlobalExceptionHandler` — map `BusinessException` thành response JSON có cấu trúc
  - `ApiError` — DTO response lỗi
  - `PaginationRequest` / `PaginationResponse` — helper phân trang generic
  - `HealthController` (`/healthz`) — health check public
  - `RequestIdFilter` — thêm header `X-Request-ID` cho mọi request
  - `CorsConfig` — cấu hình CORS (origin, method, header)
  - `JacksonConfig` — JSON serializer (Java 8 time, …)
  - `SwaggerSecurityConfig` — cấu hình OpenAPI security
  - `ClockConfig` — cung cấp bean `Clock` để trừu tượng hoá thời gian trong test
  - `EmailService` — gửi email SMTP (dùng bởi `NotificationService`)
  - `FileService` — tiện ích upload/download MinIO
- **Lưu ý**: Đây là lớp hạ tầng/cross-cutting. Điểm đáng chú ý là `ResilientCacheManager` — toàn bộ app vẫn chạy khi Redis chết.

### 2.9. `config` — Bean dịch vụ ngoài

- **Path**: `backend/src/main/java/com/example/evstation/config`
- **Mục đích**: Bean cấu hình cho dịch vụ bên ngoài không thuộc `common`.
- **Các class chính**:
  - `MinioConfig` — bean `MinioClient` (`url`, `access-key`, `secret-key`)
  - `WebClientConfig` — bean `WebClient` cho HTTP (dùng cho OSRM routing, …)

### 2.10. `governance` — Concept only

- **Path**: `backend/src/main/java/com/example/evstation/governance`
- **Mục đích**: Bounded context lý thuyết cho quy trình review Change Request & publishing. Hiện chỉ có `package-info.java`.
- **Lưu ý**: Workflow thực tế nằm ở `station` (cho trạm sạc: `ChangeRequestService`, `AdminChangeRequestService`, `RiskEngineService`) và `batteryswap` (cho trạm đổi pin: `BatterySwapChangeRequestService`). Package này đóng vai trò ranh giới khái niệm.

### 2.11. `loyalty` — Điểm thưởng, huy hiệu, voucher, đánh giá

- **Path**: `backend/src/main/java/com/example/evstation/loyalty`
- **Subpackages**: `api`, `application`, `config`, `domain`, `infrastructure`
- **Mục đích**: Loyalty cho EV user: điểm, huy hiệu, voucher, đánh giá trạm, chương trình referral. Cộng điểm khi hoàn tất booking, đổi pin, đánh giá, giới thiệu. Tích hợp với `payment` để redeem voucher cho booking.
- **Các class chính**:
  - `LoyaltyPointService` — earn/redeem/adjust điểm; hệ 6 cấp (Bronze/Silver/Gold/Platinum/Diamond/Master, ngưỡng lifetime 0/100/500/1500/5000/15000)
  - `VoucherService` — tạo/redeem/áp dụng voucher (FREE_SERVICE hoặc PERCENT_DISCOUNT) cho booking hoặc đổi pin; sinh mã duy nhất
  - `BadgeService` — tự động cấp huy hiệu theo tiêu chí (FIRST_BOOKING, FIRST_SWAP, BOOKING_COUNT, SWAP_COUNT, CONTRIBUTIONS, RATING_COUNT, REFERRALS)
  - `StationRatingService` — đánh giá trạm 1–5 sao, gộp thành `StationRatingSummaryDTO`
  - `ReferralService` — sinh mã referral, thưởng cho người được giới thiệu khi hoàn tất giao dịch đầu tiên
  - `RatingEligibilityService` — đánh dấu trạm đủ điều kiện đánh giá sau khi booking/swap thành công
  - `VoucherExpirationScheduler` — `@Scheduled(cron = "0 0 0 * * *")` job expire voucher chạy hằng ngày
  - `VoucherDataInitializer` — seed định nghĩa voucher ban đầu
  - **Domain**: `LoyaltyUserProfileEntity`, `LoyaltyPointTransactionEntity`, `VoucherDefinitionEntity`, `VoucherRedemptionEntity`, `LoyaltyBadgeEntity`, `UserBadgeEntity`, `StationRatingEntity`, `RatingEligibilityEntity`, `ReferralEntity`
- **Lưu ý**: DDD layout. Mọi thao tác ghi đều evict cache Redis liên quan (`LOYALTY_PROFILE`, `LOYALTY_HISTORY`). Điểm được cộng tự động từ `BookingService`, `PaymentService`, `SwapSessionService`.

### 2.12. `notification` — Thông báo đa kênh

- **Path**: `backend/src/main/java/com/example/evstation/notification`
- **Subpackages**: `api`, `application`, `domain`, `infrastructure`
- **Mục đích**: Thông báo in-app, push FCM và email. Hỗ trợ tuỳ chọn theo category (channel toggle PUSH/EMAIL/IN_APP). Dùng `ApplicationEventPublisher` + `@TransactionalEventListener(phase = AFTER_COMMIT)` để chỉ gửi sau khi transaction cha commit.
- **Các class chính**:
  - `NotificationService` — `send()` (lưu + publish event), `sendToUsers()`, `sendPushNotification()` (`@Async`), `sendEmailNotification()` (`@Async`), mark read, quản lý push token & preference
  - `EvUserNotificationService` — lưu thông báo in-app cho EV user
  - `SlaNotificationScheduler` — thông báo SLA (task verification quá hạn)
  - `FCMService` — tích hợp Firebase Cloud Messaging
  - `EvUserNotificationController` (`/api/ev/notifications`) — thông báo cho EV user
  - `CollabMobileNotificationController` (`/api/collab/mobile/notifications`) — thông báo cho cộng tác viên mobile
  - **Domain**: `CollaboratorNotificationEntity`, `EvUserNotificationEntity`, `PushTokenEntity`, `NotificationPreferenceEntity`
  - **Enum**: `NotificationType` (TASK_ASSIGNED, TASK_REVIEWED_PASS/FAIL, BOOKING_CONFIRMED, BOOKING_REMINDER, …), `NotificationCategory` (TASK/CONTRACT/STATION/SYSTEM/ALL), `NotificationChannel`
- **Lưu ý**: `@Async` cho push/email tránh block request thread. Đảm bảo transactional — nếu transaction cha rollback thì không gửi thông báo.

### 2.13. `payment` — Payment intent

- **Path**: `backend/src/main/java/com/example/evstation/payment`
- **Subpackages**: `application`, `domain`, `infrastructure`
- **Mục đích**: Payment intent cho booking. Thiết kế để thay bằng gateway thật (Stripe, MoMo, …) trong tương lai. Hiện giả lập success/fail.
- **Các class chính**:
  - `PaymentService` — `createPaymentIntent()` (CREATED), `simulateSuccess()` (SUCCEEDED → booking CONFIRMED + cộng điểm loyalty), `simulateFail()` (FAILED). Hỗ trợ áp voucher trước thanh toán. `simulateSuccess` idempotent.
  - **Domain**: `PaymentIntent`, `PaymentIntentEntity`, `PaymentIntentStatus` (CREATED/SUCCEEDED/FAILED), `PaymentIntentResponseDTO`
- **Lưu ý**: Entity `PaymentIntent` giữ `bookingId`, `amount`, `currency`, `status`, `voucherRedemptionId`, `discountAmount`. Khi thành công, gọi `LoyaltyPointService`, `BadgeService`, `ReferralService`, `RatingEligibilityService` để cộng thưởng. Số tiền đọc từ `Booking.priceSnapshot` (giá/slot × số slot).

### 2.14. `risk` — Chấm điểm rủi ro Change Request

- **Path**: `backend/src/main/java/com/example/evstation/risk`
- **Subpackages**: `application`, `domain`
- **Mục đích**: Engine rule-based chấm rủi ro cho Change Request trạm. Trả về điểm số + lý do.
- **Các class chính**:
  - `RiskEngineService` — `assessChangeRequest()` cho CR trạm sạc; `assessBatterySwapChangeRequest()` ủy quyền cho `BatterySwapRiskAssessor` cho rule riêng đổi pin. Rule: `GPS_CHANGED_100M` (+50), `PORTS_CHANGED` (+30), `ACCESS_CHANGED` (+10), `HOURS_CHANGED` (+10), `NEW_STATION` (+10); riêng đổi pin có rule cho inventory/power/config
  - `BatterySwapRiskAssessor` — phân tích chi tiết đổi pin với accuracy, reliability, safety, overall
  - `BatterySwapRiskAssessmentResult` — kết quả có cấu trúc (score, level, flags, reasons)
  - **Domain**: `RiskAssessment` (score + level + reasons), `RiskReasonCode` enum (`GPS_CHANGED_100M`, `PORTS_CHANGED`, `PRICE_CHANGED`, `HOURS_CHANGED`, `ACCESS_CHANGED`, `NEW_STATION`, `SWAP_LOW_INVENTORY`, `SWAP_AVG_POWER_OUT_OF_RANGE`, `SWAP_CONFIG_CHANGED`)
- **Lưu ý**: Chỉ có `application` + `domain`. Dùng công thức Haversine cho khoảng cách GPS. Điểm rủi ro quyết định CR có cần verify bắt buộc trước khi publish hay không.

### 2.15. `station` — Trạm sạc (core domain)

- **Path**: `backend/src/main/java/com/example/evstation/station`
- **Subpackages**: `application`, `domain`, `infrastructure`
- **Mục đích**: Domain chính cho dữ liệu trạm sạc. CRUD trạm, versioning (`DRAFT → PUBLISHED → ARCHIVED`), Change Request, báo cáo sự cố, audit log. Tích hợp `trust` và `verification`.
- **Các class chính**:
  - `AdminStationService` — create/update/delete với quản lý version, tự tạo charger unit + battery swap state khi publish, gọi `TrustScoringService.recalculate()`
  - `StationQueryService` — CQRS read-only cho trạm đã publish: `findStationsWithinRadius()` (PostGIS, cached), `findStationDetail()` (cached), `searchStationsByName()` (cached)
  - `RecommendationQueryService` — recommendation dựa trên AI, dùng OSRM routing (pin còn → năng lượng cần → trạm đáp ứng → sort theo tổng thời gian)
  - `ChangeRequestService` — EV user submit đề xuất thay đổi, trigger risk assessment
  - `AdminChangeRequestService` — admin review, approve/reject, publish
  - `ReportIssueService` — EV user báo sự cố, admin xử lý
  - `AuditLogService` — truy vấn audit log
  - `CsvImportService` — import CSV hàng loạt
  - `EvUserAiService` — recommendation AI (gọi routing service)
  - **Domain**: `StationEntity`, `StationVersionEntity` (PostGIS `Point`), `ChargingPortEntity`, `StationServiceEntity`, `ChangeRequestEntity`, `ReportIssueEntity`, `AuditLogEntity`, `StationVersion` (value object), `ChargingPort` (value object)
  - **Enum**: `ServiceType` (CHARGING/BATTERY_SWAP), `WorkflowStatus` (DRAFT/PUBLISHED/ARCHIVED), `ChangeRequestStatus` (PENDING/APPROVED/REJECTED), `ChangeRequestType` (CREATE_STATION/UPDATE_STATION), `IssueStatus` (OPEN/ACKNOWLEDGED/RESOLVED/CLOSED), `PowerType` (AC/DC), `ParkingType`, `VisibilityType`, `PublicStatus`
- **Lưu ý**: DDD layout. PostGIS spatial cho tìm bán kính. CQRS (`StationQueryService` đọc, `AdminStationService` ghi). `@CacheEvict` ở method ghi clear cache station/trust/rating. Versioning cho phép rollback (ARCHIVED). `ChangeRequestService` trigger `RiskEngineService.assessChangeRequest()` trước khi submit.

### 2.16. `trust` — Điểm uy tín trạm sạc

- **Path**: `backend/src/main/java/com/example/evstation/trust`
- **Subpackages**: `application`, `domain`, `infrastructure`
- **Mục đích**: Chấm điểm uy tín cho trạm sạc. Tính lại khi có review verification, thay đổi issue, hoặc publish CR rủi ro cao.
- **Các class chính**:
  - `TrustScoringService` — `recalculate()` (write-through cache evict), `getTrustScore()`, `getTrustBreakdown()`, `getTrustEntity()`, `getSummary()` (tổng hợp global cho admin dashboard). Rule: BASE = 50, +20 PASS verification, -20 FAIL, -5 mỗi issue OPEN (max -30), -10 nếu CR rủi ro cao được publish trong 30 ngày. Clamp 0–100.
  - **Domain**: `StationTrustEntity`, `TrustBreakdown` (base + verificationBonus + issuesPenalty + highRiskPenalty)
- **Lưu ý**: Được gọi từ `AdminStationService`, `VerificationService.reviewTask()`, `Station.versionPublishing`. Cache Redis 10 phút cho score/breakdown, 5 phút cho summary. Chỉ áp dụng cho trạm `CHARGING` (trạm đổi pin có hệ trust riêng trong `batteryswap`).

### 2.17. `verification` — Task xác minh hiện trường

- **Path**: `backend/src/main/java/com/example/evstation/verification`
- **Subpackages**: `api`, `application`, `domain`, `infrastructure`
- **Mục đích**: Vòng đời task verification: tạo → assign → GPS check-in (trong 200m) → nộp bằng chứng → admin review (PASS/FAIL). Hỗ trợ cả trạm sạc và trạm đổi pin. Sinh checklist từ risk reason code. Chặn tự assign (admin không giao task cho người submit CR gốc).
- **Các class chính**:
  - `VerificationService` — vòng đời đầy đủ: `createTask()`, `assignTask()`, `checkIn()`, `submitEvidence()`, `reviewTask()`, `deleteTask()`; biến thể cho đổi pin. Tính khoảng cách GPS bằng PostGIS `ST_Distance`. Tracking SLA deadline.
  - `CollaboratorCandidateQueryService` — tìm collaborator phù hợp gần đó để assign
  - `AdminVerificationController` (`/api/admin/verification/tasks`) — admin CRUD + review
  - `AdminBatterySwapVerificationController` — admin endpoint cho đổi pin
  - `CollaboratorMobileVerificationController` — check-in + nộp evidence từ mobile
  - `CollaboratorMobileBatterySwapVerificationController` — check-in đổi pin từ mobile
  - `CollaboratorWebVerificationController` — danh sách task, KPI (pass rate), lịch sử cho portal web
  - **Domain**: `VerificationTaskEntity`, `VerificationCheckinEntity`, `VerificationEvidenceEntity`, `VerificationReviewEntity`
  - **Enum**: `VerificationType` (CHARGING_STATION/BATTERY_SWAP), `VerificationTaskStatus` (OPEN/ASSIGNED/CHECKED_IN/SUBMITTED/REVIEWED), `VerificationResult` (PASS/FAIL), `EvidencePhotoType`
  - **DTO**: `ChecklistItem`, `ChecklistAnswer`, `SubmitEvidenceDTO`, `CheckinDTO`, `ReviewTaskDTO`, `CollaboratorKpiDTO`
- **Lưu ý**: DDD layout. `@TransactionalEventListener` cho dispatch notification. GPS check-in validate bằng native query PostGIS (`ST_Distance`). Khi review, trigger `TrustScoringService.recalculate()`. Publish notification event sau commit để gửi push/email.

---

## 3. Bảng tổng hợp

| # | Package | Loại | Chức năng chính | Công nghệ đáng chú ý |
|---|---|---|---|---|
| 1 | `api` | Bounded context | REST API layer (5 nhóm client) | Spring MVC, Swagger |
| 2 | `audit` | Concept only | Audit log (triển khai trong `station`) | — |
| 3 | `auth` | Bounded context | JWT auth, role, tài khoản | Spring Security, BCrypt |
| 4 | `batteryswap` | Bounded context | Vòng đời đổi pin + WebSocket | WebSocket, PostGIS, Redis |
| 5 | `batteryswapchange` | Wrapper mỏng | REST trust đổi pin | — |
| 6 | `booking` | Bounded context | Reservation sạc (HOLD → CONFIRMED) | PostgreSQL exclusion constraint |
| 7 | `collaborator` | Bounded context | Hồ sơ, hợp đồng, GPS | Haversine distance |
| 8 | `common` | Cross-cutting | Cache, error, phân trang, email, file | Redis, SMTP, MinIO |
| 9 | `config` | Hạ tầng | Bean MinIO + WebClient | MinIO, WebClient |
| 10 | `governance` | Concept only | Workflow CR (triển khai ở `station`/`batteryswap`) | — |
| 11 | `loyalty` | Bounded context | Điểm, huy hiệu, voucher, đánh giá, referral | Redis cache |
| 12 | `notification` | Bounded context | In-app, push (FCM), email + preference | FCM, SMTP, `@Async` |
| 13 | `payment` | Bounded context | Payment intent (gateway giả lập) | Idempotent operation |
| 14 | `risk` | Bounded context | Chấm rủi ro rule-based cho CR | Haversine GPS |
| 15 | `station` | Bounded context | CRUD trạm, versioning, CQRS đọc | PostGIS, CQRS, cache |
| 16 | `trust` | Bounded context | Điểm uy tín trạm sạc | Redis cache |
| 17 | `verification` | Bounded context | Task verify, GPS check-in, review | PostGIS GPS, checklist |

---

## 4. Ghi chú bổ sung

- **Khả năng chịu lỗi**: `ResilientCacheManager` trong `common` đảm bảo Redis chết không làm sập app — tự động fallback về no-op cache.
- **Realtime**: WebSocket cho cả operator (`/ws/battery-swap`) và màn hình trạm công cộng (`/ws/display/battery-swap`).
- **Scheduler**: Có 3 job chính — `BookingExpirationScheduler` (1 phút), `ExpireBatterySwapReservationsJob` (cấu hình), `VoucherExpirationScheduler` (hằng ngày lúc 00:00).
- **Transactional event**: `@TransactionalEventListener(phase = AFTER_COMMIT)` được dùng trong `notification` và `verification` để đảm bảo side-effect chỉ chạy khi transaction cha commit thành công.
- **Spatial**: PostGIS được dùng ở `station` (tìm trạm theo bán kính), `verification` (validate GPS check-in), `risk` (so sánh GPS change).
- **Versioning**: Trạm sạc hỗ trợ DRAFT/PUBLISHED/ARCHIVED, cho phép rollback về version cũ.
- **Audit**: Mặc dù có package `audit` riêng, code thực tế dùng `AuditLogEntity` trong `station` — package `audit` chỉ mang tính ranh giới khái niệm.