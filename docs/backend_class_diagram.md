# VoltGO Backend — Class Diagram Documentation

## Use Case 1: Battery Swap (EV User) & Use Case 2: Verification Task (Collaborator)

> **Nguồn:** Phân tích thực tế từ codebase tại `backend/src/main/java/com/example/evstation/`
> **Cập nhật:** 2026-06-28

---

## Mục lục

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Use Case 1: Battery Swap (EV User)](#2-use-case-1--battery-swap-ev-user)
3. [Use Case 2: Verification Task (Collaborator)](#3-use-case-2--verification-task-collaborator)
4. [Quan hệ liên kết & Data Flow](#4-quan-hệ-liên-kết--data-flow)
5. [Database Schema Mapping](#5-database-schema-mapping)

---

## 1. Tổng quan kiến trúc

```
┌─────────────────────────────────────────────────────────┐
│                    API Layer (Controllers)                │
│  EvBatterySwapController    │  CollaboratorMobileVerificationController  │
│  PublicBatterySwapController │  AdminBatterySwapVerificationController     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                  Application Layer (Services)               │
│  BatterySwapService              │  VerificationService          │
│  SwapSessionService              │  CollaboratorCandidateQueryService  │
│  SwapCodeService                 │                                 │
│  BatteryEventService             │                                 │
│  ChargingSessionService          │                                 │
│  BatterySwapTrustScoringService  │                                 │
│  BatterySwapBroadcastService     │                                 │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│               Infrastructure Layer (JPA + DB)                │
│  JpaRepository implementations  │  PostgreSQL + PostGIS       │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Use Case 1 — Battery Swap (EV User)

### 2.1 Controller Layer

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           API Controllers                                  │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────┐  ┌───────────────────────────────────────┐
│  EvBatterySwapController        │  │  PublicBatterySwapController          │
│  (/api/ev/mobile/battery-swap) │  │  (/api/public/battery-swap)           │
├─────────────────────────────────┤  ├───────────────────────────────────────┤
│ + getNearbyStations()           │  │ + listPublishedStations()            │
│ + getStationDetail()            │  │ + getStationDetail()                  │
│ + reserve()                     │  │ + listPilesAndSlots()                 │
│ + confirmArrival()             │  │ + registerDeviceKey()                 │
│ + startSwap()                  │  │ + pollActiveSwapCode()                │
│ + pay()                        │  │                                      │
│ + cancelReservation()          │  │                                      │
│ + getSwapCode()                │  │                                      │
│ + verifySwapCode()             │  │                                      │
└──────────────┬──────────────────┘  └───────────────┬───────────────────────┘
               │                                        │
┌──────────────▼────────────────────────────────────────▼───────────────────┐
│  AdminBatterySwapStationController          │  BatterySwapChangeRequestController │
│  (/api/admin/battery-swap/stations)        │  (/api/ev/mobile/battery-swap/cr)   │
├────────────────────────────────────────────┼─────────────────────────────────┤
│ + createStation()                          │ + createChangeRequest()          │
│ + updateStation()                          │ + submitChangeRequest()           │
│ + deleteStation()                          │ + getMyChangeRequests()           │
│ + importFromCsv()                         │ + updateChangeRequest()           │
│ + listStations()                          │ + deleteChangeRequest()            │
│ + getStationDetail()                       │                                  │
└────────────────────────────────────────────┴─────────────────────────────────┘
```

### 2.2 Service Layer

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          Application Services                            │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  BatterySwapService                                                    │
├──────────────────────────────────────────────────────────────────────┤
│  - SwapStationStateJpaRepository stationStateRepo                     │
│  - BatterySwapReservationJpaRepository reservationRepo                │
│  - SwapSessionJpaRepository sessionRepo                              │
│  - SwapCodeService swapCodeService                                   │
│  - LoyaltyService loyaltyService                                     │
│  - RatingService ratingService                                       │
│  - NotificationService notificationService                           │
│  - SwapStationStateJpaRepository stationStateRepo                   │
├──────────────────────────────────────────────────────────────────────┤
│  + getNearbyStations(lat, lng, radius, page) → List<StationDTO>      │
│  + getAllPublishedStations(page) → Page<StationDTO>                  │
│  + getStationDetail(stationId, userId) → StationDetailDTO            │
│  + reserveBatterySwap(req, userId) → ReservationDTO                  │
│  + confirmArrival(reservationId, userId) → ReservationDTO            │
│  + startSwap(reservationId, userId) → SwapSessionDTO                 │
│  + payAndCompleteSwap(sessionId, userId) → SwapSummaryDTO            │
│  + cancelReservation(reservationId, userId) → void                   │
│  + getSwapCode(reservationId, userId) → SwapCodeDTO                  │
│  + verifySwapCode(reservationId, code) → SwapSessionDTO              │
│  + getUserReservations(userId) → List<ReservationDTO>                │
│  + getReservationDetail(reservationId, userId) → ReservationDTO     │
└──────────────────────────────────────────────────────────────────────┘
         │
         │ uses
         ▼
┌────────────────────────────────┐  ┌──────────────────────────────────────┐
│  SwapCodeService               │  │  SwapSessionService                  │
├────────────────────────────────┤  ├──────────────────────────────────────┤
│  + generateSwapCode()          │  │  + startSession(reservationId)       │
│  + getSwapCode()              │  │  + completeSwap(sessionId)           │
│  + isSwapCodeValid()          │  │  + expireSessions()                  │
│  + getActiveSwapCode()        │  │  + getSessionByReservation()         │
└────────────────────────────────┘  │  + getSessionByCode()                │
                                    └──────────────────────────────────────┘
         │
         │ uses
         ▼
┌──────────────────────────────────────────────────────────────┐
│  BatteryEventService                                         │
├──────────────────────────────────────────────────────────────┤
│  + recordBatteryInserted(slotId, batteryId)                  │
│  + recordBatteryRemoved(slotId)                              │
│  + recordChargingStarted(slotId, percent)                    │
│  + recordFullyCharged(slotId, percent)                       │
│  + recordSwapEvent(slotId, eventType)                        │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  ChargingSessionService                                       │
├──────────────────────────────────────────────────────────────┤
│  + startChargingSession(slotId, startPercent)                │
│  + updateChargingProgress(sessionId, percent)                  │
│  + completeChargingSession(sessionId, finalPercent)          │
│  + cancelChargingSession(sessionId)                          │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  BatterySwapTrustScoringService                               │
├──────────────────────────────────────────────────────────────┤
│  + calculateTrustScore(stationId) → TrustScoreDTO            │
│  + getTrustScore(stationId) → TrustScoreDTO                  │
│  + getTrustScoreHistory(stationId, from, to)                │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  BatterySwapBroadcastService (Facade)                         │
├──────────────────────────────────────────────────────────────┤
│  + broadcastSwapCode(stationId, reservationId, code)          │
│  + broadcastSwapCompleted(stationId, reservationId)          │
│  + broadcastSlotUpdate(stationId, slotId, slotData)          │
└──────────────────────────────────────────────────────────────┘
         │
         │ delegates to:
         ▼
┌──────────────────────────────────────────────────────────────┐
│  BatterySwapWebSocketHandler  │  SimulatorDisplayWebSocketHandler│
└──────────────────────────────────────────────────────────────┘
```

### 2.3 Entity Layer (JPA)

```
┌──────────────────────────────────────────────────────────────────────┐
│  BatterySwapReservationEntity          @Entity → battery_swap_reservation │
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - userId: Long                                                     │
│  - stationId: Long                                                  │
│  - pileId: Long                                                     │
│  - slotId: Long                                                     │
│  - status: BatterySwapStatus  ← (RESERVED, SWAPPING, COMPLETED,     │
│                                    CANCELLED, EXPIRED)               │
│  - swapCode: String                                                 │
│  - paymentStatus: PaymentStatus  ← (UNPAID, PAID, REFUNDED)        │
│  - paymentAmount: BigDecimal                                        │
│  - voucherId: Long                                                  │
│  - voucherDiscount: BigDecimal                                      │
│  - arrivedAt: LocalDateTime                                         │
│  - swapStartedAt: LocalDateTime                                     │
│  - completedAt: LocalDateTime                                       │
│  - cancelledAt: LocalDateTime                                       │
│  - createdAt: LocalDateTime                                         │
│  - expiresAt: LocalDateTime                                         │
│  - updatedAt: LocalDateTime                                         │
├──────────────────────────────────────────────────────────────────────┤
│  @Enumerated(STATIONARY) status, paymentStatus                     │
│  @OneToOne SwapSessionEntity (swapSession)                          │
│  @OneToOne SwapPaymentEntity (payment)                              │
└──────────────────────────────────────────────────────────────────────┘
          │ 1:1
          │ references
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│  SwapSessionEntity                    @Entity → swap_session         │
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - reservationId: Long                                              │
│  - swapCode: String (4-digit)                                       │
│  - status: SwapSessionStatus  ← (PENDING, SWAPPING,                 │
│                                    COMPLETED, EXPIRED, CANCELLED)   │
│  - expiresAt: LocalDateTime                                         │
│  - startedAt: LocalDateTime                                         │
│  - completedAt: LocalDateTime                                        │
│  - createdAt: LocalDateTime                                          │
├──────────────────────────────────────────────────────────────────────┤
│  @OneToOne BatterySwapReservationEntity (reservation)              │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  SwapPileEntity                     @Entity → swap_pile             │
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - stationId: Long                                                  │
│  - pileIndex: Integer                                                │
│  - status: SwapPileStatus  ← (ACTIVE, MAINTENANCE)                 │
│  - createdAt: LocalDateTime                                         │
├──────────────────────────────────────────────────────────────────────┤
│  @OneToMany BatterySlotEntity (slots)  ← cascade ALL, orphanRemoval │
│  @ManyToOne BatterySwapStationStateEntity (station)                 │
└──────────────────────────────────────────────────────────────────────┘
          │ 1:N
          │ contains
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│  BatterySlotEntity                   @Entity → battery_slot          │
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - pileId: Long                                                      │
│  - batteryId: String                                                 │
│  - batteryChargePercent: Integer  ← 0-100                           │
│  - status: BatterySlotStatus  ← (AVAILABLE, OCCUPIED, CHARGING,    │
│                                    RESERVED, SWAPPED_OUT)           │
│  - insertedAt: LocalDateTime                                        │
│  - lastChargedAt: LocalDateTime                                     │
│  - fullyChargedAt: LocalDateTime                                    │
│  - createdAt: LocalDateTime                                         │
├──────────────────────────────────────────────────────────────────────┤
│  @ManyToOne SwapPileEntity (pile)                                  │
│  @OneToMany BatteryEventEntity (events)                            │
│  @OneToMany ChargingSessionEntity (chargingSessions)                │
└──────────────────────────────────────────────────────────────────────┘
          │ 1:N
          │ events
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│  BatteryEventEntity                 @Entity → battery_event          │
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - batterySlotId: Long                                              │
│  - eventType: BatteryEventType  ← (BATTERY_INSERTED, BATTERY_REMOVED,│
│                                     CHARGING_STARTED, FULLY_CHARGED, │
│                                     SWAPPED_IN, SWAPPED_OUT, ...)   │
│  - previousState: String                                            │
│  - newState: String                                                 │
│  - batteryPercent: Integer                                          │
│  - metadata: String (JSON)                                          │
│  - createdAt: LocalDateTime                                         │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  ChargingSessionEntity              @Entity → charging_session       │
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - batterySlotId: Long                                              │
│  - startPercent: Integer                                           │
│  - endPercent: Integer                                              │
│  - status: ChargingSessionStatus  ← (CHARGING, COMPLETED, CANCELLED)│
│  - startedAt: LocalDateTime                                        │
│  - completedAt: LocalDateTime                                        │
│  - createdAt: LocalDateTime                                         │
├──────────────────────────────────────────────────────────────────────┤
│  @ManyToOne BatterySlotEntity (slot)                                │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  BatterySwapStationStateEntity     @Entity → battery_swap_station_state│
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - stationId: Long                                                  │
│  - totalBatteries: Integer                                           │
│  - availableBatteries: Integer                                       │
│  - avgChargePowerKw: Double                                         │
│  - updatedAt: LocalDateTime                                         │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  BatterySwapTrustEntity             @Entity → battery_swap_trust      │
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - stationId: Long                                                  │
│  - score: Double                                                    │
│  - breakdown: String (JSONB)  ← trust dimensions breakdown           │
│  - calculatedAt: LocalDateTime                                      │
│  - createdAt: LocalDateTime                                         │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  BatterySwapChangeRequestEntity    @Entity → battery_swap_change_request│
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - submitterId: Long                                                │
│  - type: ChangeRequestType  ← (CREATE_STATION, UPDATE_STATION)      │
│  - status: ChangeRequestStatus  ← (DRAFT, PENDING, APPROVED,       │
│                                     REJECTED, PUBLISHED, SUBMITTED) │
│  - riskScore: Double                                                │
│  - proposedVersionId: Long                                          │
│  - submittedAt: LocalDateTime                                        │
│  - approvedAt: LocalDateTime                                        │
│  - publishedAt: LocalDateTime                                        │
│  - createdAt: LocalDateTime                                         │
│  - updatedAt: LocalDateTime                                         │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  SwapPaymentEntity                 @Entity → swap_payment            │
├──────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                         │
│  - reservationId: Long                                              │
│  - amount: BigDecimal                                              │
│  - status: SwapPaymentStatus  ← (PENDING, SUCCESS, FAILED,          │
│                                   REFUNDED, EXPIRED)               │
│  - paidAt: LocalDateTime                                            │
│  - transactionId: String                                            │
│  - paymentMethod: String                                            │
│  - createdAt: LocalDateTime                                         │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.4 Enums (Domain)

```
┌─────────────────────────────────────────┐
│  BatterySwapStatus                      │
├─────────────────────────────────────────┤
│  RESERVED                               │
│  SWAPPING                               │
│  COMPLETED                              │
│  CANCELLED                              │
│  EXPIRED                                │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  BatterySlotStatus                      │
├─────────────────────────────────────────┤
│  AVAILABLE                              │
│  OCCUPIED                               │
│  CHARGING                               │
│  RESERVED                               │
│  SWAPPED_OUT                            │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  SwapSessionStatus                      │
├─────────────────────────────────────────┤
│  PENDING  ← (code generated, waiting)   │
│  SWAPPING ← (swap in progress)          │
│  COMPLETED                              │
│  EXPIRED  ← (code expired)              │
│  CANCELLED                              │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  BatteryEventType                       │
├─────────────────────────────────────────┤
│  BATTERY_INSERTED                        │
│  BATTERY_REMOVED                         │
│  CHARGING_STARTED                        │
│  FULLY_CHARGED                           │
│  SWAPPED_IN                              │
│  SWAPPED_OUT                             │
│  STATUS_CHANGED                          │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  ChangeRequestStatus                    │
├─────────────────────────────────────────┤
│  DRAFT  ← (user editing)               │
│  SUBMITTED  ← (sent for review)         │
│  IN_REVIEW  ← (admin reviewing)        │
│  APPROVED  ← (ok, ready to publish)    │
│  REJECTED  ← (failed)                  │
│  PUBLISHED  ← (live in system)         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  ChangeRequestType                      │
├─────────────────────────────────────────┤
│  CREATE_BATTERY_SWAP_STATION            │
│  UPDATE_BATTERY_SWAP_STATION             │
└─────────────────────────────────────────┘
```

### 2.5 DTO Layer

```
┌─────────────────────────────────────────┐  ┌─────────────────────────────────────────┐
│  BatterySwapStationDTO                 │  │  BatterySwapStationDetailDTO            │
├─────────────────────────────────────────┤  ├─────────────────────────────────────────┤
│  stationId: Long                        │  │  + all fields of StationDTO              │
│  name: String                           │  │  + piles: List<PileDTO>                  │
│  address: String                        │  │  + operatingHours: String                │
│  lat: Double                            │  │  + parkingFee: BigDecimal               │
│  lng: Double                            │  │  + totalBatteries: Integer              │
│  distance: Double                       │  │  + availableBatteries: Integer         │
│  availableBatteries: Integer            │  │  + avgChargePowerKw: Double             │
│  avgChargePowerKw: Double               │  │  + trustScore: Double                    │
│  rating: Double                          │  │                                         │
│  ratingCount: Integer                   │  │                                         │
└─────────────────────────────────────────┘  └─────────────────────────────────────────┘

┌─────────────────────────────────────────┐  ┌─────────────────────────────────────────┐
│  BatterySwapReservationDTO              │  │  BatterySwapReserveRequestDTO            │
├─────────────────────────────────────────┤  ├─────────────────────────────────────────┤
│  reservationId: Long                    │  │  stationId: Long                        │
│  stationId: Long                        │  │  pileId: Long (optional)                │
│  stationName: String                    │  │  preferredStartTime: LocalDateTime      │
│  status: BatterySwapStatus              │  │  useVoucher: Boolean                    │
│  swapCode: String                       │  │  voucherId: Long (optional)             │
│  paymentStatus: PaymentStatus           │  │                                         │
│  totalAmount: BigDecimal                │  │                                         │
│  discount: BigDecimal                   │  │                                         │
│  finalAmount: BigDecimal                │  │                                         │
│  arrivedAt: LocalDateTime               │  │                                         │
│  swapStartedAt: LocalDateTime           │  │                                         │
│  completedAt: LocalDateTime             │  │                                         │
│  expiresAt: LocalDateTime                │  │                                         │
└─────────────────────────────────────────┘  └─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  BatterySwapSummaryDTO                  │
├─────────────────────────────────────────┤
│  reservationId: Long                    │
│  stationName: String                    │
│  finalAmount: BigDecimal                │
│  batteryIdOut: String                   │
│  batteryIdIn: String                    │
│  durationMinutes: Long                  │
│  loyaltyPointsEarned: Integer          │
│  ratingUrl: String                     │
└─────────────────────────────────────────┘
```

---

## 3. Use Case 2 — Verification Task (Collaborator)

### 3.1 Controller Layer

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           API Controllers                                  │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────┐  ┌──────────────────────────────────────────┐
│  CollaboratorMobileVerificationController │  │  CollaboratorWebVerificationController    │
│  (/api/collab/mobile/tasks)              │  │  (/api/collab/web/tasks)                  │
├──────────────────────────────────────────┤  ├──────────────────────────────────────────┤
│  + getMyAssignedTasks()                  │  │  + getFilteredTasks()                     │
│  + getTaskDetail(taskId)                 │  │  + getTaskDetail(taskId)                  │
│  + checkIn(taskId, request)             │  │  + getTaskHistory(collaboratorId)         │
│  + submitEvidence(taskId, request)      │  │  + getKpiSummary()                        │
│  + submitTask(taskId)                   │  │                                          │
│  + getCheckinStatus(taskId)             │  │                                          │
└──────────────┬───────────────────────────┘  └──────────────────┬───────────────────┘
               │                                               │
┌──────────────▼───────────────────────────────────────────────▼───────────────────┐
│  AdminVerificationController                  │  AdminBatterySwapVerificationController │
│  (/api/admin/verification-tasks)              │  (/api/admin/battery-swap/verification)  │
├──────────────────────────────────────────────┼─────────────────────────────────────┤
│  + createTask(request)                       │  + listBatterySwapTasks()            │
│  + assignTask(taskId, request)               │  + createBatterySwapTask(request)     │
│  + reviewTask(taskId, request)               │  + getBatterySwapTask(taskId)          │
│  + deleteTask(taskId)                        │  + assignBatterySwapTask(taskId, req)  │
│  + getCandidatesForAssignment(taskId)       │  + reviewBatterySwapTask(taskId, req)  │
│  + listTasks()                               │  + listBatterySwapTasksByStation()     │
│  + getTask(taskId)                           │                                        │
└──────────────────────────────────────────────┴─────────────────────────────────────┘

┌──────────────────────────────────────────┐  ┌──────────────────────────────────────────┐
│  CollaboratorMobileBatterySwap...        │  │  CollaboratorWebBatterySwap...            │
│  (/api/mobile/collab/battery-swap/...)   │  │  (/api/collab/battery-swap/...)           │
├──────────────────────────────────────────┤  ├──────────────────────────────────────────┤
│  + getMyAssignedTasks()                   │  │  + getFilteredTasks()                     │
│  + getTaskDetail(taskId)                 │  │  + getTaskDetail(taskId)                  │
│  + checkIn(taskId, request)              │  │  + getTaskHistory()                       │
│  + submitEvidence(taskId, request)       │  │  + checkIn(taskId, request)              │
│  + submitTask(taskId)                    │  │  + submitEvidence(taskId, request)        │
└──────────────────────────────────────────┘  └──────────────────────────────────────────┘
```

### 3.2 Service Layer

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  VerificationService                                                         │
│  (~1520 lines — Core verification engine)                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│  DEPENDENCIES:                                                               │
│  - VerificationTaskJpaRepository taskRepo                                   │
│  - VerificationCheckinJpaRepository checkinRepo                             │
│  - VerificationEvidenceJpaRepository evidenceRepo                           │
│  - VerificationReviewJpaRepository reviewRepo                               │
│  - CollaboratorProfileJpaRepository profileRepo                              │
│  - ContractJpaRepository contractRepo                                       │
│  - ContractPolicyService contractPolicyService                              │
│  - CollaboratorCandidateQueryService candidateQueryService                  │
│  - StationService stationService                                             │
│  - BatterySwapService batterySwapService                                     │
│  - TrustScoringService trustScoringService                                  │
│  - NotificationService notificationService                                  │
│  - MinioService minioService                                                │
│  - ChecklistDefinitionService checklistService                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  TASK LIFECYCLE METHODS:                                                     │
│  + createTask(request) → VerificationTaskDTO      [Admin]                   │
│      → generates auto-checklist from VerificationType                      │
│      → notifies assigned collaborator                                       │
│  + assignTask(taskId, collaboratorId) → void       [Admin]                   │
│      → requires active contract (ContractPolicyService)                     │
│      → prevents conflict-of-interest (submitter ≠ assignee)                │
│      → notifies collaborator via NotificationService                        │
│  + checkIn(taskId, lat, lng, answers) → CheckinDTO [Collaborator]          │
│      → validates GPS: distance <= 200m from station (PostGIS)              │
│      → records actual inventory (batteries, charge %)                      │
│      → records checklist answers (JSONB)                                    │
│  + submitEvidence(taskId, photoKey, note) → void  [Collaborator]           │
│      → validates evidence photo uploaded to MinIO                           │
│      → prevents duplicate submission                                        │
│  + submitTask(taskId) → void                   [Collaborator]              │
│      → transitions task from ASSIGNED → SUBMITTED                           │
│      → notifies admin for review                                            │
│  + reviewTask(taskId, result, note) → void      [Admin]                      │
│      → transitions SUBMITTED → REVIEWED                                     │
│      → recalculates trust score for station                                │
│      → notifies collaborator of result                                      │
│                                                                              │
│  QUERY METHODS:                                                              │
│  + getMyAssignedTasks(collaboratorId) → List<TaskDTO>                       │
│  + getTaskDetail(taskId) → TaskDTO                                          │
│  + getTaskHistory(collaboratorId, page) → Page<TaskDTO>                    │
│  + getKpiSummary(collaboratorId, period) → KpiDTO                          │
│  + getCandidatesForAssignment(taskId, page) → CandidateListResponseDTO      │
│                                                                              │
│  BATTERY SWAP SPECIFIC:                                                     │
│  + createBatterySwapTask(request) → BatterySwapTaskDTO                     │
│      → includes stationSnapshot (totalBatteries, avgChargePowerKw, etc.)   │
│      → includes battery-specific checklist                                  │
│  + checkInBatterySwap(taskId, request) → BatterySwapCheckinDTO             │
│      → records actualTotalBatteries, actualAvailableBatteries              │
│      → records observedAvgChargePowerKw                                    │
│  + reviewBatterySwapTask(taskId, dto) → void                               │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  CollaboratorCandidateQueryService                                           │
├──────────────────────────────────────────────────────────────────────────────┤
│  + findCandidatesForTask(taskId, page) → CandidateListResponseDTO           │
│      → PostGIS ST_DWithin for distance from collaborator to station         │
│      → Aggregates workload: active/completed/failedOrOverdue task counts    │
│      → Resolves CR submitter userId for conflict-of-interest flagging       │
│      → Sorts by: distance ASC, then failedOrOverdue ASC                    │
│      → Filters: active contract only, not task submitter                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Entity Layer (JPA)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  VerificationTaskEntity              @Entity → verification_task           │
├──────────────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                             │
│  - stationId: Long (nullable)                                            │
│  - changeRequestId: Long (nullable)                                     │
│  - verificationType: VerificationType  ← (CHARGING_STATION, BATTERY_SWAP)│
│  - priority: Integer  ← 1 (highest) to 5 (lowest)                        │
│  - slaDueAt: LocalDateTime                                               │
│  - assignedTo: Long (collaborator userId)                                 │
│  - status: VerificationTaskStatus  ← (OPEN, ASSIGNED, CHECKED_IN,        │
│                                        SUBMITTED, REVIEWED)               │
│  - batterySwapChangeRequestId: Long (nullable)                           │
│  - batterySwapStationSnapshot: String (JSONB)  ← snapshot at creation     │
│  - checklistJson: String (JSONB)  ← auto-generated from VerificationType  │
│  - stationSnapshotJson: String (JSONB)  ← station data at creation        │
│  - createdAt: LocalDateTime                                              │
│  - updatedAt: LocalDateTime                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  @Enumerated(STATIONARY) verificationType, status                       │
│  @OneToOne VerificationCheckinEntity (checkin)                            │
│  @OneToOne VerificationReviewEntity (review)                             │
│  @OneToMany VerificationEvidenceEntity (evidences)                        │
└──────────────────────────────────────────────────────────────────────────────┘

         │ 1:1
         │ (optional)
         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  VerificationCheckinEntity          @Entity → verification_checkin        │
├──────────────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                             │
│  - taskId: Long  @Column(unique=true)                                    │
│  - checkinLat: Double                                                   │
│  - checkinLng: Double                                                   │
│  - distanceMeters: Double  ← GPS distance from station                    │
│  - checkedInAt: LocalDateTime                                           │
│  - deviceNote: String (nullable)                                         │
│  - actualTotalBatteries: Integer (nullable)  ← Battery swap specific      │
│  - actualAvailableBatteries: Integer (nullable) ← Battery swap specific   │
│  - observedAvgChargePowerKw: Double (nullable) ← Battery swap specific    │
│  - checklistAnswersJson: String (JSONB)  ← List<ChecklistAnswer>          │
│  - createdAt: LocalDateTime                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  @OneToOne VerificationTaskEntity (task)                                 │
└──────────────────────────────────────────────────────────────────────────────┘

         │ 1:N
         │ (one task → many photos)
         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  VerificationEvidenceEntity         @Entity → verification_evidence        │
├──────────────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                             │
│  - taskId: Long                                                         │
│  - photoObjectKey: String  ← MinIO object key                            │
│  - photoType: EvidencePhotoType  ← 13 types incl. BATTERY_SWAP_PILE,     │
│                                        BATTERY_SLOT, STATION_OVERVIEW...  │
│  - note: String (nullable)                                               │
│  - submittedAt: LocalDateTime                                            │
│  - submittedBy: Long (userId)                                            │
├──────────────────────────────────────────────────────────────────────────────┤
│  @Enumerated(STATIONARY) photoType                                       │
│  @ManyToOne VerificationTaskEntity (task)                                 │
└──────────────────────────────────────────────────────────────────────────────┘

         │ 1:1
         │ (admin review)
         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  VerificationReviewEntity           @Entity → verification_review           │
├──────────────────────────────────────────────────────────────────────────────┤
│  - id: Long                                                             │
│  - taskId: Long  @Column(unique=true)                                    │
│  - result: VerificationResult  ← (PASS, FAIL)                           │
│  - adminNote: String (nullable)                                          │
│  - reviewedAt: LocalDateTime                                            │
│  - reviewedBy: Long (admin userId)                                       │
│  - swapStationVerified: Boolean  ← Battery swap: station confirmed       │
│  - inventoryAccurate: Boolean   ← Battery swap: count matches snapshot   │
│  - resolutionNote: String (nullable)                                      │
│  - createdAt: LocalDateTime                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  @Enumerated(STATIONARY) result                                          │
│  @OneToOne VerificationTaskEntity (task)                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.4 Enums (Domain)

```
┌─────────────────────────────────────────────┐
│  VerificationTaskStatus                      │
├─────────────────────────────────────────────┤
│  OPEN        ← (created, not yet assigned)  │
│  ASSIGNED    ← (assigned to collaborator)   │
│  CHECKED_IN  ← (collaborator checked in)   │
│  SUBMITTED   ← (evidence submitted)         │
│  REVIEWED    ← (admin reviewed)            │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  VerificationType                           │
├─────────────────────────────────────────────┤
│  CHARGING_STATION                            │
│  BATTERY_SWAP                                │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  VerificationResult                         │
├─────────────────────────────────────────────┤
│  PASS  ← (station verified, accurate)      │
│  FAIL  ← (issues found)                    │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  EvidencePhotoType                                       │
├─────────────────────────────────────────────────────────┤
│  STATION_ENTRANCE                                       │
│  CHARGER_EQUIPMENT / BATTERY_SWAP_PILE                  │
│  PAYMENT_DISPLAY / BATTERY_SLOT                         │
│  OPERATING_HOURS_SIGN                                   │
│  STATION_OVERVIEW                                       │
│  EV_CONNECTOR                                          │
│  STREET_VIEW                                           │
│  PARKING_AREA                                          │
│  SAFETY_EQUIPMENT                                      │
│  OTHER                                                 │
└─────────────────────────────────────────────────────────┘
```

### 3.5 DTO Layer

```
┌─────────────────────────────────────────────────────────────────────┐
│  VerificationTaskDTO                                               │
├─────────────────────────────────────────────────────────────────────┤
│  - taskId: Long                                                     │
│  - stationId: Long                                                 │
│  - stationName: String                                              │
│  - stationAddress: String                                           │
│  - verificationType: VerificationType                              │
│  - priority: Integer                                                │
│  - slaDueAt: LocalDateTime                                          │
│  - assignedTo: Long                                                │
│  - assignedToName: String                                          │
│  - status: VerificationTaskStatus                                   │
│  - checklist: List<ChecklistItem>                                  │
│  - stationSnapshot: StationSnapshotDTO                              │
│  - checkin: CheckinDTO (nullable)                                   │
│  - review: ReviewDTO (nullable)                                     │
│  - evidences: List<EvidenceDTO>                                     │
│  - createdAt: LocalDateTime                                         │
│  - updatedAt: LocalDateTime                                          │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  BatterySwapVerificationTaskDTO  extends VerificationTaskDTO        │
├─────────────────────────────────────────────────────────────────────┤
│  + stationSnapshot: BatterySwapStationSnapshotDTO  ← NEW           │
│      - totalBatteries: Integer                                      │
│      - avgChargePowerKw: Double                                     │
│      - pileCount: Integer                                           │
│      - slotCount: Integer                                           │
│      - operatingHours: String                                       │
│      - parkingFee: BigDecimal                                       │
│  + checkin: BatterySwapCheckinDTO (nullable)  ← NEW                │
│      - actualTotalBatteries: Integer                                │
│      - actualAvailableBatteries: Integer                            │
│      - observedAvgChargePowerKw: Double                             │
│      - distanceMeters: Double                                       │
│      - checklistAnswers: List<ChecklistAnswer>                       │
│  + review: BatterySwapReviewDTO (nullable)  ← NEW                   │
│      - result: VerificationResult                                    │
│      - adminNote: String                                             │
│      - riskConfirmed: Boolean                                        │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  ChecklistItem (embedded in task DTO)                               │
├─────────────────────────────────────────────────────────────────────┤
│  - id: String                                                        │
│  - question: String                                                  │
│  - type: String  ← (YES_NO, NUMERIC, TEXT, PHOTO)                    │
│  - sourceCode: String  ← references checklist definition            │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  ChecklistAnswer (submitted by collaborator)                         │
├─────────────────────────────────────────────────────────────────────┤
│  - itemId: String                                                    │
│  - question: String                                                  │
│  - type: String                                                      │
│  - sourceCode: String                                               │
│  - answer: ChecklistAnswerValue  ← (YES, NO, UNABLE_TO_VERIFY)      │
│  - supplementaryNote: String (nullable)                             │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  CollaboratorCandidateDTO                                           │
├─────────────────────────────────────────────────────────────────────┤
│  - userId: Long                                                      │
│  - profileId: Long                                                   │
│  - fullName: String                                                  │
│  - phone: String                                                     │
│  - contractActive: Boolean                                           │
│  - location: Point (PostGIS)                                         │
│  - distanceMeters: Double                                           │
│  - stats: CandidateStatsDTO                                          │
│      - activeTaskCount: Integer                                     │
│      - completedTaskCount: Integer                                  │
│      - failedOrOverdueCount: Integer                                │
│  - isCrSubmitter: Boolean  ← conflict-of-interest flag              │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  CreateTaskDTO  (Admin creates task)                                │
├─────────────────────────────────────────────────────────────────────┤
│  - stationId: Long  ← REQUIRED                                      │
│  - changeRequestId: Long (nullable)                                │
│  - priority: Integer (default: 3)                                  │
│  - slaDueAt: LocalDateTime (nullable)                              │
│  - verificationType: VerificationType                               │
│  - checklist: List<ChecklistItem> (nullable — auto-generated if null)│
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  AssignTaskDTO  (Admin assigns task)                               │
├─────────────────────────────────────────────────────────────────────┤
│  - collaboratorUserId: Long (preferred)                             │
│  - collaboratorEmail: String (backward compat, nullable)            │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  CheckinDTO  (Collaborator checks in)                               │
├─────────────────────────────────────────────────────────────────────┤
│  - lat: Double  ← validated: -90 to 90                             │
│  - lng: Double  ← validated: -180 to 180                          │
│  - deviceNote: String (nullable)                                    │
│  - checklistAnswers: List<ChecklistAnswer>                           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  CollaboratorKpiDTO                                                 │
├─────────────────────────────────────────────────────────────────────┤
│  - totalReviewed: Integer                                           │
│  - passCount: Integer                                                │
│  - failCount: Integer                                               │
│  - passRate: Double  ← (passCount / totalReviewed) * 100            │
│  - period: String  ← e.g. "2026-01"                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Quan hệ liên kết & Data Flow

### 4.1 Battery Swap — Reservation Flow (EV User)

```
┌────────┐     ┌────────────────────┐     ┌───────────────────┐     ┌────────────────────┐
│  EV    │     │ EvBatterySwap     │     │  BatterySwap      │     │  SwapCode          │
│  User  │────▶│ Controller        │────▶│  Service          │────▶│  Service            │
│  App   │◀────│                   │◀────│                   │◀────│                     │
└────────┘     └────────────────────┘     └───────────────────┘     └────────────────────┘
                                                   │                        │
                              ┌─────────────────────┼────────────────────┐  │
                              ▼                     ▼                    ▼  │
               ┌────────────────────┐  ┌────────────────────┐  ┌───────────────────┐ │
               │ SwapSessionService │  │ SwapStationState   │  │ Notification      │ │
               │                    │  │ JPA Repo           │  │ Service           │ │
               └────────────────────┘  └────────────────────┘  └───────────────────┘ │
                              │                                                      │
                              ▼                                                      ▼
               ┌─────────────────────────────────────────────────────────────────────┐
               │              SwapPileEntity ──1:N──▶ BatterySlotEntity             │
               │                    │                                                   │
               │                    │ 1:N                                               │
               │                    ▼                                                   │
               │               BatteryEventEntity                                      │
               │                    │                                                   │
               │                    │ 1:N                                               │
               │                    ▼                                                   │
               │               ChargingSessionEntity                                   │
               └─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Battery Swap — Swap Code Verification Flow

```
Step 1: Reserve        Step 2: Arrive & Start       Step 3: Swap Code Generated
EV User ──────────────▶ BatterySwapService ──────────▶ SwapCodeService
                             │                              │
                             ▼                              ▼
                      SwapSessionService             4-digit code saved
                             │                        (30-min expiry)
                             ▼
Step 4: Verify Code    SwapSessionJpaRepository
Simulator/Display ────▶ SwapSessionService ──────────▶ BatterySwapWebSocketHandler
                             │                              │
                             ▼                              ▼
                      SwapSessionEntity              Simulator screen shows
                      (code matched)                  "Ready to swap"
```

### 4.3 Verification Task — Full Lifecycle Flow

```
┌──────────┐         ┌──────────────────────────────┐         ┌──────────────────────────────┐
│  Admin   │         │  VerificationService         │         │  Collaborator                │
└──────────┘         │  (1520 lines core engine)    │         │  (Mobile App)                │
     │               └──────────────────────────────┘         └──────────────────────────────┘
     │                            │                                    │
     │ CREATE_TASK ──────────────▶│                                    │
     │                            │ Generate checklist from type       │
     │                            │ (CHARGING_STATION or BATTERY_SWAP) │
     │◀── taskId ─────────────────│                                    │
     │                            │                                    │
     │ ASSIGN ───────────────────▶│                                    │
     │   (auto-validates contract) │ Validate active contract          │
     │                            │ Check conflict-of-interest         │
     │◀── (notifies collab) ───────│                                    │
     │                            │                                    │
     │                            │◀───── GET_ASSIGNED_TASKS ─────────│
     │                            │────── task list ──────────────────▶│
     │                            │                                    │
     │                            │◀───── CHECK_IN (lat, lng, answers) │
     │                            │     │                              │
     │                            │     │ PostGIS: distance ≤ 200m?    │
     │                            │     │ Record actual inventory     │
     │                            │◀── CheckinDTO                     │
     │                            │                                    │
     │                            │◀───── SUBMIT_EVIDENCE (photoKey)  │
     │                            │     │                              │
     │                            │     │ Validate MinIO upload        │
     │                            │     │ Store EvidenceEntity         │
     │                            │                                    │
     │                            │◀───── SUBMIT_TASK ────────────────│
     │                            │     │                              │
     │                            │     │ Status: ASSIGNED → SUBMITTED │
     │                            │     │ Notify admin                 │
     │                            │                                    │
     │ REVIEW ────────────────────▶│                                    │
     │   (PASS or FAIL)           │ Transition SUBMITTED → REVIEWED    │
     │                            │ Recalculate trust score            │
     │                            │ Notify collaborator                │
     │◀── (review result) ─────────│                                    │
```

### 4.4 Verification Task — Candidate Assignment Flow

```
┌─────────────────────────────┐
│  AdminBatterySwap            │
│  VerificationController      │
└──────────────┬──────────────┘
               │ GET /candidates?taskId=X
               ▼
┌─────────────────────────────────────────────────────────┐
│  VerificationService                                    │
│  .getCandidatesForAssignment(taskId, page)             │
└──────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│  CollaboratorCandidateQueryService                     │
│  .findCandidatesForTask(taskId, page)                  │
├─────────────────────────────────────────────────────────┤
│  1. Find task → stationId                             │
│  2. PostGIS ST_DWithin: collaborator.location           │
│     within 50km of station                             │
│  3. Filter: contract.status = ACTIVE                  │
│  4. Aggregate workload stats per collaborator          │
│     (active, completed, failedOrOverdue counts)       │
│  5. Check if collaborator = CR submitter → flag        │
│  6. Sort: distance ASC, failedOrOverdue ASC           │
└─────────────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│  CandidateListResponseDTO                               │
│  → list<CollaboratorCandidateDTO>                       │
│      - userId, name, phone, distanceMeters             │
│      - stats: {active, completed, failed}              │
│      - isCrSubmitter: boolean                          │
└─────────────────────────────────────────────────────────┘
```

---

## 5. Database Schema Mapping

### 5.1 Battery Swap Tables

```
┌─────────────────────────────────────────────────────────────────┐
│  battery_swap_reservation                                        │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  user_id                 BIGINT FK → users                      │
│  station_id              BIGINT FK → battery_swap_station_state │
│  pile_id                 BIGINT FK → swap_pile                   │
│  slot_id                 BIGINT FK → battery_slot               │
│  status                  VARCHAR (RESERVED, SWAPPING, ...)      │
│  swap_code               VARCHAR(4)                             │
│  payment_status          VARCHAR (UNPAID, PAID, REFUNDED)       │
│  payment_amount          DECIMAL(10,2)                          │
│  arrived_at              TIMESTAMP                              │
│  swap_started_at         TIMESTAMP                              │
│  completed_at            TIMESTAMP                              │
│  cancelled_at            TIMESTAMP                              │
│  expires_at              TIMESTAMP                              │
│  created_at              TIMESTAMP                              │
│  updated_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  swap_session                                                    │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  reservation_id         BIGINT FK → battery_swap_reservation   │
│  swap_code               VARCHAR(4)                             │
│  status                  VARCHAR (PENDING, SWAPPING, ...)       │
│  expires_at              TIMESTAMP                              │
│  started_at              TIMESTAMP                              │
│  completed_at            TIMESTAMP                              │
│  created_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  swap_pile                                                        │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  station_id              BIGINT FK → battery_swap_station_state │
│  pile_index              INTEGER                                 │
│  status                  VARCHAR (ACTIVE, MAINTENANCE)          │
│  created_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  battery_slot                                                      │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  pile_id                 BIGINT FK → swap_pile                   │
│  battery_id              VARCHAR                                 │
│  battery_charge_percent  INTEGER (0-100)                        │
│  status                  VARCHAR (AVAILABLE, OCCUPIED, ...)     │
│  inserted_at              TIMESTAMP                              │
│  last_charged_at          TIMESTAMP                              │
│  fully_charged_at         TIMESTAMP                              │
│  created_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  battery_swap_station_state                                       │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  station_id              BIGINT                                 │
│  total_batteries         INTEGER                                │
│  available_batteries     INTEGER                                │
│  avg_charge_power_kw     DOUBLE PRECISION                       │
│  updated_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  battery_swap_change_request                                      │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  submitter_id            BIGINT FK → users                      │
│  type                    VARCHAR (CREATE_STATION, UPDATE_STATION)│
│  status                  VARCHAR (DRAFT, PENDING, ...)          │
│  risk_score              DOUBLE PRECISION                       │
│  proposed_version_id     BIGINT                                 │
│  submitted_at            TIMESTAMP                              │
│  approved_at             TIMESTAMP                              │
│  published_at            TIMESTAMP                              │
│  created_at              TIMESTAMP                              │
│  updated_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  battery_event                                                       │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  battery_slot_id         BIGINT FK → battery_slot               │
│  event_type              VARCHAR (BATTERY_INSERTED, ...)        │
│  previous_state          VARCHAR                                 │
│  new_state               VARCHAR                                 │
│  battery_percent         INTEGER                                 │
│  metadata                TEXT (JSON)                             │
│  created_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  charging_session                                                 │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  battery_slot_id         BIGINT FK → battery_slot               │
│  start_percent           INTEGER                                 │
│  end_percent             INTEGER                                 │
│  status                  VARCHAR (CHARGING, COMPLETED, ...)     │
│  started_at              TIMESTAMP                              │
│  completed_at            TIMESTAMP                              │
│  created_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  battery_swap_trust                                               │
├─────────────────────────────────────────────────────────────────┤
│  id                      BIGINT PK                              │
│  station_id              BIGINT                                 │
│  score                   DOUBLE PRECISION                       │
│  breakdown               TEXT (JSONB)                           │
│  calculated_at           TIMESTAMP                              │
│  created_at              TIMESTAMP                              │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Verification Task Tables

```
┌─────────────────────────────────────────────────────────────────────────┐
│  verification_task                                                            │
├─────────────────────────────────────────────────────────────────────────┤
│  id                            BIGINT PK                                 │
│  station_id                    BIGINT (nullable)                         │
│  change_request_id             BIGINT (nullable)                         │
│  verification_type             VARCHAR (CHARGING_STATION, BATTERY_SWAP) │
│  priority                      INTEGER (1-5)                             │
│  sla_due_at                    TIMESTAMP                                 │
│  assigned_to                   BIGINT (nullable) → collaborator userId  │
│  status                        VARCHAR (OPEN, ASSIGNED, ...)            │
│  battery_swap_change_request_id BIGINT (nullable)                      │
│  battery_swap_station_snapshot  TEXT (JSONB)  ← snapshot at creation    │
│  checklist_json                 TEXT (JSONB)                            │
│  station_snapshot_json          TEXT (JSONB)                            │
│  created_at                    TIMESTAMP                                │
│  updated_at                    TIMESTAMP                                │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  verification_checkin                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  id                            BIGINT PK                                 │
│  task_id                       BIGINT FK → verification_task (unique)  │
│  checkin_lat                   DOUBLE PRECISION                          │
│  checkin_lng                   DOUBLE PRECISION                          │
│  distance_meters               DOUBLE PRECISION                          │
│  checked_in_at                 TIMESTAMP                                 │
│  device_note                   TEXT (nullable)                          │
│  actual_total_batteries        INTEGER (nullable) ← battery swap        │
│  actual_available_batteries   INTEGER (nullable) ← battery swap        │
│  observed_avg_charge_power_kw  DOUBLE PRECISION (nullable) ← battery   │
│  checklist_answers_json        TEXT (JSONB)                             │
│  created_at                    TIMESTAMP                                 │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  verification_evidence                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  id                            BIGINT PK                                 │
│  task_id                       BIGINT FK → verification_task            │
│  photo_object_key               VARCHAR  ← MinIO storage key            │
│  photo_type                     VARCHAR (13 types)                       │
│  note                           TEXT (nullable)                         │
│  submitted_at                   TIMESTAMP                                 │
│  submitted_by                    BIGINT → userId                        │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  verification_review                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  id                            BIGINT PK                                 │
│  task_id                       BIGINT FK → verification_task (unique)   │
│  result                        VARCHAR (PASS, FAIL)                     │
│  admin_note                    TEXT (nullable)                           │
│  reviewed_at                   TIMESTAMP                                 │
│  reviewed_by                   BIGINT → admin userId                     │
│  swap_station_verified         BOOLEAN (nullable) ← battery swap        │
│  inventory_accurate            BOOLEAN (nullable)  ← battery swap       │
│  resolution_note               TEXT (nullable)                           │
│  created_at                    TIMESTAMP                                 │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Package Structure Summary

```
com.example.evstation/
│
├── batteryswap/                          # Battery Swap Bounded Context
│   ├── api/
│   │   ├── controller/
│   │   │   ├── BatterySwapChangeRequestController.java
│   │   │   ├── AdminBatterySwapStationController.java
│   │   │   └── AdminBatterySwapChangeRequestController.java
│   │   └── dto/
│   │       ├── BatterySwapCRDTO.java
│   │       ├── BatterySwapCRListDTO.java
│   │       ├── CreateBatterySwapCRDTO.java
│   │       ├── UpdateBatterySwapCRDTO.java
│   │       ├── SubmitBatterySwapCRDTO.java
│   │       ├── CreateBatterySwapStationDTO.java
│   │       ├── UpdateBatterySwapStationDTO.java
│   │       ├── BatterySwapStationListDTO.java
│   │       ├── BatterySwapStationDetailDTO.java
│   │       └── BatterySwapCsvImportResponseDTO.java
│   ├── application/
│   │   ├── BatterySwapService.java          # ★ Core service
│   │   ├── BatterySwapStationAdminService.java
│   │   ├── BatterySwapChangeRequestService.java
│   │   ├── SwapSessionService.java
│   │   ├── SwapCodeService.java
│   │   ├── SwapStationStateApplyService.java
│   │   ├── ChargingSessionService.java
│   │   ├── BatteryEventService.java
│   │   ├── BatterySwapTrustScoringService.java
│   │   ├── BatterySwapBroadcastService.java
│   │   ├── BatterySwapWebSocketHandler.java
│   │   ├── SimulatorDisplayWebSocketHandler.java
│   │   ├── StationDeviceService.java
│   │   ├── BatterySwapCsvImportService.java
│   │   ├── BatteryChargingSimulationJob.java
│   │   ├── ExpireBatterySwapReservationsJob.java
│   │   └── BatterySwapTrustScoreDTO.java
│   ├── domain/
│   │   ├── BatterySwapStatus.java
│   │   ├── BatterySlotStatus.java
│   │   ├── SwapSessionStatus.java
│   │   ├── ChangeRequestStatus.java
│   │   ├── ChangeRequestType.java
│   │   ├── SwapPileStatus.java
│   │   ├── PaymentStatus.java
│   │   ├── SwapPaymentStatus.java
│   │   ├── BatteryEventType.java
│   │   ├── ChargingSessionStatus.java
│   │   └── ActorType.java
│   ├── infrastructure/
│   │   └── jpa/
│   │       ├── BatterySwapReservationJpaRepository.java
│   │       ├── SwapSessionJpaRepository.java
│   │       ├── BatterySwapChangeRequestJpaRepository.java
│   │       ├── BatterySlotJpaRepository.java
│   │       ├── SwapPileJpaRepository.java
│   │       ├── BatterySwapStationStateJpaRepository.java
│   │       ├── BatterySwapTrustJpaRepository.java
│   │       ├── BatteryEventJpaRepository.java
│   │       ├── SwapPaymentJpaRepository.java
│   │       ├── ChargingSessionJpaRepository.java
│   │       ├── BatterySwapStationVersionJpaRepository.java
│   │       ├── BatterySwapPileTemplateJpaRepository.java
│   │       ├── BatterySwapSlotTemplateJpaRepository.java
│   │       ├── StationDeviceJpaRepository.java
│   │       ├── BatterySwapReservationEntity.java
│   │       ├── SwapPileEntity.java
│   │       ├── BatterySlotEntity.java
│   │       ├── SwapSessionEntity.java
│   │       ├── BatterySwapChangeRequestEntity.java
│   │       ├── BatterySwapStationStateEntity.java
│   │       ├── BatterySwapTrustEntity.java
│   │       ├── BatteryEventEntity.java
│   │       ├── SwapPaymentEntity.java
│   │       ├── ChargingSessionEntity.java
│   │       ├── BatterySwapStationVersionEntity.java
│   │       ├── BatterySwapPileTemplateEntity.java
│   │       ├── BatterySwapSlotTemplateEntity.java
│   │       ├── StationDeviceEntity.java
│   │       └── mapper/
│   │           └── BatterySwapVersionMapper.java
│   └── config/
│       └── BatterySwapWebSocketConfig.java
│
├── api/
│   ├── ev_user_mobile/
│   │   ├── controller/
│   │   │   ├── EvBatterySwapController.java     # ★ EV User entry point
│   │   │   └── EvBatterySwapCRController.java
│   │   └── dto/
│   │       ├── BatterySwapStationDTO.java
│   │       ├── BatterySwapStationDetailDTO.java
│   │       ├── BatterySwapReservationDTO.java
│   │       ├── BatterySwapReserveRequestDTO.java
│   │       └── BatterySwapSummaryDTO.java
│   └── public_api/
│       └── controller/
│           └── PublicBatterySwapController.java  # ★ Public simulator API
│
├── verification/                      # Verification Bounded Context
│   ├── api/
│   │   ├── controller/
│   │   │   ├── AdminVerificationController.java            # ★ Admin entry
│   │   │   ├── AdminBatterySwapVerificationController.java  # ★ Admin BS entry
│   │   │   ├── CollaboratorMobileVerificationController.java # ★ Collab mobile
│   │   │   ├── CollaboratorWebVerificationController.java   # ★ Collab web
│   │   │   ├── CollaboratorMobileBatterySwapVerificationController.java
│   │   │   └── CollaboratorWebBatterySwapVerificationController.java
│   │   └── dto/
│   │       ├── VerificationTaskDTO.java
│   │       ├── BatterySwapVerificationTaskDTO.java
│   │       ├── CreateTaskDTO.java
│   │       ├── AssignTaskDTO.java
│   │       ├── ReviewTaskDTO.java
│   │       ├── CheckinDTO.java
│   │       ├── SubmitEvidenceDTO.java
│   │       ├── BatterySwapCheckinRequestDTO.java
│   │       ├── BatterySwapReviewDTO.java
│   │       ├── ChecklistItem.java
│   │       ├── ChecklistAnswer.java
│   │       ├── ChecklistAnswerValue.java
│   │       ├── StationSnapshotDTO.java
│   │       ├── CollaboratorCandidateDTO.java
│   │       ├── CandidateStatsDTO.java
│   │       ├── CandidateListResponseDTO.java
│   │       └── CollaboratorKpiDTO.java
│   ├── application/
│   │   ├── VerificationService.java                  # ★ Core engine (1520 lines)
│   │   └── CollaboratorCandidateQueryService.java   # ★ Candidate selection
│   ├── domain/
│   │   ├── VerificationTaskStatus.java
│   │   ├── VerificationType.java
│   │   ├── VerificationResult.java
│   │   └── EvidencePhotoType.java
│   ├── infrastructure/
│   │   └── jpa/
│   │       ├── VerificationTaskJpaRepository.java
│   │       ├── VerificationCheckinJpaRepository.java
│   │       ├── VerificationEvidenceJpaRepository.java
│   │       ├── VerificationReviewJpaRepository.java
│   │       ├── VerificationTaskEntity.java
│   │       ├── VerificationCheckinEntity.java
│   │       ├── VerificationEvidenceEntity.java
│   │       └── VerificationReviewEntity.java
│   └── package-info.java
│
├── batteryswapchange/
│   └── web/
│       └── BatterySwapTrustController.java
│
├── risk/
│   └── application/
│       └── BatterySwapRiskAssessmentResult.java
│
└── collaborator/
    ├── application/
    │   └── ContractPolicyService.java   # (used by VerificationService)
    └── infrastructure/
        └── jpa/
            ├── CollaboratorProfileJpaRepository.java
            └── ContractJpaRepository.java
```

---

## 7. Key Metrics

| Metric | Value |
|--------|-------|
| Total Battery Swap Java files | ~60 |
| Total Verification Java files | ~37 |
| Battery Swap Service LOC | ~800+ |
| Verification Service LOC | ~1520 |
| Battery Swap Entities | 12 |
| Verification Entities | 4 |
| Battery Swap DTOs | ~15 |
| Verification DTOs | ~16 |
| Battery Swap Enums | 11 |
| Verification Enums | 4 |
| Database migration files | 6 |

---

*Tài liệu này được tạo tự động bằng cách phân tích thực tế codebase, không dựa vào doc.*
