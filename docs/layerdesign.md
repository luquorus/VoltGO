<think>
Now I have a comprehensive understanding of the codebase. Let me create a detailed class diagram documentation for both features.
</think>

Tôi đã đọc toàn bộ codebase cần thiết. Giờ tôi sẽ tạo tài liệu class diagram chi tiết.

---

# Class Diagram - VoltGO Features

## PHẦN 1: BATTERY SWAPPING (EV USER MOBILE APP)

### 1.1 Class Diagram Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           EV USER MOBILE APP (Flutter)                            │
│                         apps/ev_user_mobile/lib/src/                               │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │  MODELS (models/)                                                           │ │
│  │                                                                             │ │
│  │  ┌──────────────────────────────┐  ┌────────────────────────────────────┐  │ │
│  │  │  BatterySwapStationModel     │  │  BatterySwapStationDetailModel     │  │ │
│  │  │  ─────────────────────────  │  │  ─────────────────────────────────│  │ │
│  │  │  + stationId: String        │  │  + stationId: String               │  │ │
│  │  │  + name: String?            │◄─┼─►  stationId (lookup detail)       │  │ │
│  │  │  + address: String?         │  │  + name, address, lat, lng         │  │ │
│  │  │  + lat, lng, distanceKm     │  │  + operatingHours: String?         │  │ │
│  │  │  + totalBatteries: int      │  │  + avgChargePowerKw: double        │  │ │
│  │  │  + availableBatteries: int  │  │  + basePriceVnd, totalPiles       │  │ │
│  │  │  + avgChargePowerKw: double │  │  + totalSlots, availableSlots     │  │ │
│  │  │  + basePriceVnd: int        │  │  + piles: List<SwapPileModel>  1──┼──┼──┼──┐│
│  │  │  + totalPiles, availableSlots│  │  └────────────────────────────────┘  │ │
│  │  │  + totalSlots: int          │  └──────────────────────────────────────┘ │ │
│  │  └──────────────────────────────┘  ┌────────────────────────────────────┐  │ │
│  │                                    │  SwapPileModel                    │  │ │
│  │                                    │  ────────────────────────────────  │  │ │
│  │                                    │  + pileId: String                 │  │ │
│  │                                    │  + pileIndex: int                 │  │ │
│  │                                    │  + status: String                 │  │ │
│  │                                    │  + slots: List<BatterySlotModel>1──┼──┼──┼──┼──┤
│  │                                    │  + availableSlots (computed)       │  │ │
│  │                                    │  + chargingSlots (computed)       │  │ │
│  │                                    └────────────────────────────────────┘  │ │
│  │                                    ┌────────────────────────────────────┐  │ │
│  │                                    │  BatterySlotModel                 │  │ │
│  │                                    │  ────────────────────────────────  │  │ │
│  │                                    │  + slotId: String                 │  │ │
│  │                                    │  + slotIndex: int                 │  │ │
│  │                                    │  + batteryId: String?             │  │ │
│  │                                    │  + batteryChargePercent: int      │  │ │
│  │                                    │  + status: BatterySlotStatus      │  │ │
│  │                                    │  + estimatedFullAt: DateTime?     │  │ │
│  │                                    │  + copyWithSlotUpdate()           │  │ │
│  │                                    └────────────────────────────────────┘  │ │
│  │                                    ┌────────────────────────────────────┐  │ │
│  │                                    │  BatterySwapReservationModel       │  │ │
│  │                                    │  ────────────────────────────────  │  │ │
│  │                                    │  + id: String                     │  │ │
│  │                                    │  + stationId, stationName         │  │ │
│  │                                    │  + pileId, pileIndex, slotId     │  │ │
│  │                                    │  + slotBatteryChargePercent: int? │  │ │
│  │                                    │  + slotStatus: String?           │  │ │
│  │                                    │  + status: String                │  │ │
│  │                                    │  + paymentStatus: String         │  │ │
│  │                                    │  + basePriceVnd: int             │  │ │
│  │                                    │  + reservedSlotAt: DateTime?      │  │ │
│  │                                    │  + requestedBatteryPercent: int   │  │ │
│  │                                    │  + batteryCapacityKwh: double    │  │ │
│  │                                    │  + estimatedReadyAt: DateTime?   │  │ │
│  │                                    │  + reservedAt, startedAt,        │  │ │
│  │                                    │    completedAt, cancelledAt       │  │ │
│  │                                    │  + confirmedArrivalAt: DateTime? │  │ │
│  │                                    │  + swapCode: String?             │  │ │
│  │                                    │  + swapDeadlineAt: DateTime?     │  │ │
│  │                                    │  + voucherRedemptionId: String?  │  │ │
│  │                                    │  + discountAmountVnd: int?       │  │ │
│  │                                    └────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │  SERVICES (services/)                                                       │ │
│  │                                                                             │ │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │ │
│  │  │  BatterySwapWebSocketService                                          │   │ │
│  │  │  ──────────────────────────────────────────────────────────────────│   │ │
│  │  │  + wsBaseUrl: String                                                 │   │ │
│  │  │  + getAuthState: Function()                                          │   │ │
│  │  │  + isConnected: bool                                                │   │ │
│  │  │  ──────────────────────────────────────────────────────────────────│   │ │
│  │  │  + connect(): Future<void>                                          │   │ │
│  │  │  + disconnect(): void                                               │   │ │
│  │  │  + subscribeToStation(stationId): Future<void>                     │   │ │
│  │  │  + unsubscribeFromStation(stationId): void                         │   │ │
│  │  │  + addConnectListener(cb), addErrorListener(cb)                    │   │ │
│  │  │  + addSlotUpdateListener(cb), removeSlotUpdateListener(cb)         │   │ │
│  │  │  + onSlotUpdate(): Stream<SlotUpdateEvent>                         │   │ │
│  │  │  + onSwapCode(): Stream<SwapCodeEvent>                            │   │ │
│  │  │  + onSwapCompleted(): Stream<SwapCompletedEvent>                   │   │ │
│  │  │  + getCachedSlot(slotId), getCachedSlots()                        │   │ │
│  │  │  ──────────────────────────────────────────────────────────────────│   │ │
│  │  │  - _channel: WebSocketChannel?                                     │   │ │
│  │  │  - _subscription: StreamSubscription?                               │   │ │
│  │  │  - _connectedStationId: String?                                     │   │ │
│  │  │  - _slotCache: Map<slotId, BatterySlotModel>                       │   │ │
│  │  │  - _slotUpdateController: StreamController<SlotUpdateEvent>        │   │ │
│  │  │  - _swapCodeController: StreamController<SwapCodeEvent>            │   │ │
│  │  │  - _swapCompletedController: StreamController<SwapCompletedEvent>   │   │ │
│  │  │  ──────────────────────────────────────────────────────────────────│   │ │
│  │  │  WebSocket Events:                                                  │   │ │
│  │  │    SlotUpdateEvent { slotId, slotIndex, batteryId,                  │   │ │
│  │  │                    batteryChargePercent, status, estimatedFullAt }   │   │ │
│  │  │    SwapCodeEvent { stationId, slotId, reservationId,               │   │ │
│  │  │                   swapCode, deadlineAt }                           │   │ │
│  │  │    SwapCompletedEvent { stationId, slotId, reservationId, status }  │   │ │
│  │  └──────────────────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │  REPOSITORY (repositories/)                                                │ │
│  │                                                                             │ │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │ │
│  │  │  StationRepository                                                   │   │ │
│  │  │  (uses EvUserMobileApiClient)                                        │   │ │
│  │  │  ──────────────────────────────────────────────────────────────────│   │ │
│  │  │  Battery Swap Methods:                                                │   │ │
│  │  │  + getBatterySwapStations(lat,lng,radiusKm)                        │   │ │
│  │  │    → returns List<BatterySwapStationModel>                          │   │ │
│  │  │  + getBatterySwapStationDetail(stationId)                          │   │ │
│  │  │    → returns BatterySwapStationDetailModel                         │   │ │
│  │  │  + reserveBatterySwap(...) → BatterySwapReservationModel            │   │ │
│  │  │  + payBatterySwap(reservationId) → BatterySwapReservationModel     │   │ │
│  │  │  + confirmArrivalBatterySwap(reservationId) → ReservationModel    │   │ │
│  │  │  + startBatterySwap(reservationId) → ReservationModel              │   │ │
│  │  │  + confirmBatterySwap(reservationId) → ReservationModel            │   │ │
│  │  │  + cancelBatterySwap(reservationId) → ReservationModel             │   │ │
│  │  │  + getMyBatterySwapReservations() → List<ReservationModel>        │   │ │
│  │  │  + getBatterySwapReservation(reservationId) → ReservationModel    │   │ │
│  │  │  + getSwapCode(reservationId) → Map                                 │   │ │
│  │  │  + verifySwap(reservationId, swapCode) → Map                       │   │ │
│  │  │  + getSlotChargingSession(slotId) → Map                            │   │ │
│  │  │  + getSwapTrust(stationId) → Map                                   │   │ │
│  │  └──────────────────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │  PROVIDERS (providers/)                                                     │ │
│  │                                                                             │ │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │ │
│  │  │  BatterySwapState                                                    │   │ │
│  │  │  ────────────────────                                                │   │ │
│  │  │  + stations: List<BatterySwapStationModel>                          │   │ │
│  │  │  + myReservations: List<BatterySwapReservationModel>                │   │ │
│  │  │  + isLoading: bool                                                   │   │ │
│  │  │  + error: ApiError?                                                  │   │ │
│  │  └──────────────────────────────────────────────────────────────────────┘   │ │
│  │                              ▲                                             │   │
│  │                              │ (StateNotifier)                           │   │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │ │
│  │  │  BatterySwapNotifier extends StateNotifier<BatterySwapState>         │   │ │
│  │  │  ──────────────────────────────────────────────────────────────────│   │ │
│  │  │  + loadStations(lat, lng, radiusKm)                                 │   │ │
│  │  │  + loadMyReservations()                                             │   │ │
│  │  │  + reserve(...) → BatterySwapReservationModel                      │   │ │
│  │  │  + pay(reservationId) → ReservationModel                            │   │ │
│  │  │  + confirmArrival(reservationId) → ReservationModel                 │   │ │
│  │  │  + start(reservationId) → ReservationModel                         │   │ │
│  │  │  + confirm(reservationId) → ReservationModel                       │   │ │
│  │  │  + cancel(reservationId) → ReservationModel                        │   │ │
│  │  │  + getReservation(reservationId) → ReservationModel                 │   │ │
│  │  │  + getSwapCode(reservationId) → Map                                 │   │ │
│  │  │  + verifySwap(reservationId, swapCode) → Map                       │   │ │
│  │  │  + getSlotChargingSession(slotId) → Map                            │   │ │
│  │  └──────────────────────────────────────────────────────────────────────┘   │ │
│  │                                                                             │ │
│  │  Provider Instances:                                                         │ │
│  │  • batterySwapProvider: StateNotifierProvider<BatterySwapNotifier,         │   │
│  │                                BatterySwapState>                           │   │
│  │  • batterySwapWsProvider: Provider<BatterySwapWebSocketService>           │   │
│  │  • swapTrustProvider: FutureProvider.family<SwapTrustData, stationId>      │   │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────┘

                                    │
                                    │ REST API / WebSocket
                                    ▼

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              BACKEND (Spring Boot)                                  │
│                  backend/src/main/java/com/example/evstation/                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  BATTERY SWAP DOMAIN                                                         │  │
│  │  batteryswap/domain/                                                         │  │
│  │                                                                              │  │
│  │  ┌────────────────────────────────┐  ┌─────────────────────────────────────┐  │  │
│  │  │  BatterySwapStatus (enum)      │  │  BatterySlotStatus (enum)           │  │  │
│  │  │  ─────────────────────────── │  │  ───────────────────────────────────│  │  │
│  │  │  RESERVED                     │  │  AVAILABLE                         │  │  │
│  │  │  SWAPPING                     │  │  OCCUPIED                         │  │  │
│  │  │  COMPLETED                    │  │  CHARGING                          │  │  │
│  │  │  CANCELLED                    │  │  RESERVED                          │  │  │
│  │  │  EXPIRED                      │  │  SWAPPED_OUT                       │  │  │
│  │  └────────────────────────────────┘  └─────────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────┐  ┌─────────────────────────────────────┐  │  │
│  │  │  PaymentStatus (enum)         │  │  SwapPileStatus (enum)             │  │  │
│  │  │  ─────────────────────────── │  │  ───────────────────────────────────│  │  │
│  │  │  UNPAID, PAID, REFUNDED       │  │  ACTIVE, INACTIVE, MAINTENANCE     │  │  │
│  │  └────────────────────────────────┘  └─────────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────┐                                          │  │
│  │  │  SwapSessionStatus (enum)      │                                          │  │
│  │  │  ─────────────────────────── │                                          │  │
│  │  │  PENDING, SWAPPING,            │                                          │  │
│  │  │  COMPLETED, EXPIRED, CANCELLED│                                          │  │
│  │  └────────────────────────────────┘                                          │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  BATTERY SWAP ENTITIES (infrastructure/jpa/)                                 │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │  │
│  │  │  BatterySwapReservationEntity  (@Entity, table: battery_swap_reservation)│  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  + id: UUID (PK)                                                     │   │  │
│  │  │  + userId: UUID                                                      │   │  │
│  │  │  + stationId: UUID                                                   │   │  │
│  │  │  + pileId: UUID?                                                      │   │  │
│  │  │  + slotId: UUID?                                                      │   │  │
│  │  │  + status: BatterySwapStatus (default: RESERVED)                    │   │  │
│  │  │  + reservedSlotAt: Instant?  (thời điểm hẹn đến)                   │   │  │
│  │  │  + requestedBatteryPercent: int (default: 20%)                     │   │  │
│  │  │  + batteryCapacityKwh: BigDecimal (default: 60)                    │   │  │
│  │  │  + estimatedReadyAt: Instant?                                        │   │  │
│  │  │  + note: String?                                                     │   │  │
│  │  │  + reservedAt: Instant                                               │   │  │
│  │  │  + startedAt: Instant?                                               │   │  │
│  │  │  + completedAt: Instant?                                             │   │  │
│  │  │  + cancelledAt: Instant?                                             │   │  │
│  │  │  + confirmedArrivalAt: Instant?  (thời điểm xác nhận đến)        │   │  │
│  │  │  + swapCode: String?  (mã 4 chữ số)                               │   │  │
│  │  │  + swapDeadlineAt: Instant?  (hết hạn code)                       │   │  │
│  │  │  + basePriceVnd: Long (default: 5000)                             │   │  │
│  │  │  + paymentStatus: PaymentStatus (default: UNPAID)                  │   │  │
│  │  │  + voucherRedemptionId: UUID?                                       │   │  │
│  │  │  + discountAmountVnd: Integer?                                     │   │  │
│  │  │  + updatedAt: Instant                                               │   │  │
│  │  └──────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │  │
│  │  │  SwapPileEntity  (@Entity, table: swap_pile)                         │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  + id: UUID (PK)                                                     │   │  │
│  │  │  + stationId: UUID                                                   │   │  │
│  │  │  + pileIndex: int                                                    │   │  │
│  │  │  + status: SwapPileStatus                                            │   │  │
│  │  │  + createdAt, updatedAt: Instant                                      │   │  │
│  │  │  + slots: List<BatterySlotEntity>  ───(1:N)──▶ BatterySlotEntity   │   │  │
│  │  └──────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │  │
│  │  │  BatterySlotEntity  (@Entity, table: battery_slot)                   │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  + id: UUID (PK)                                                     │   │  │
│  │  │  + pileId: UUID (FK → swap_pile.id)                                  │   │  │
│  │  │  + slotIndex: int (unique: pile_id + slot_index)                    │   │  │
│  │  │  + batteryId: UUID?                                                  │   │  │
│  │  │  + batterySerialNumber: String?                                       │   │  │
│  │  │  + batteryCapacityKwh: BigDecimal (default: 60)                     │   │  │
│  │  │  + batteryChargePercent: int (default: 100)                         │   │  │
│  │  │  + status: BatterySlotStatus (default: AVAILABLE)                  │   │  │
│  │  │  + chargingStartedAt: Instant?  (bắt đầu sạc)                     │   │  │
│  │  │  + estimatedFullAt: Instant?  (ước tính đầy)                      │   │  │
│  │  │  + updatedAt: Instant                                                │   │  │
│  │  └──────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │  │
│  │  │  BatterySwapStationStateEntity  (@Entity, table: battery_swap_station_state)│ │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  + stationId: UUID (PK)                                              │   │  │
│  │  │  + totalBatteries: int (default: 20)                                │   │  │
│  │  │  + availableBatteries: int (default: 10)                            │   │  │
│  │  │  + avgChargePowerKw: BigDecimal (default: 35)                       │   │  │
│  │  │  + updatedAt: Instant                                               │   │  │
│  │  └──────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │  │
│  │  │  SwapSessionEntity  (@Entity, table: swap_session)                  │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  + id: UUID (PK)                                                     │   │  │
│  │  │  + reservationId: UUID                                              │   │  │
│  │  │  + swapCode: String (4 chữ số)                                      │   │  │
│  │  │  + status: SwapSessionStatus                                        │   │  │
│  │  │  + expiresAt: Instant                                               │   │  │
│  │  │  + createdAt, createdBy                                             │   │  │
│  │  └──────────────────────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  BATTERY SWAP SERVICES (application/)                                        │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │  │
│  │  │  BatterySwapService                                                  │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  Core methods:                                                        │   │  │
│  │  │  + getNearbySwapStations(lat, lng, radiusKm)                         │   │  │
│  │  │    → List<BatterySwapStationDTO>  (PostGIS distance query)          │   │  │
│  │  │  + getStationDetail(stationId) → BatterySwapStationDetailDTO        │   │  │
│  │  │  + getStationPiles(stationId) → StationPilesDTO  (simulator display)│  │  │
│  │  │  + listAllSwapStations() → List<BatterySwapStationDTO>              │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  Reservation methods:                                                 │   │  │
│  │  │  + reserve(userId, stationId, ...) → BatterySwapReservationDTO      │   │  │
│  │  │  + pay(userId, reservationId) → BatterySwapReservationDTO           │   │  │
│  │  │  + confirmArrival(userId, reservationId) → BatterySwapReservationDTO │  │  │
│  │  │  + start(userId, reservationId) → BatterySwapReservationDTO          │   │  │
│  │  │  + startAndGenerateCode(userId, reservationId) → ReservationDTO      │   │  │
│  │  │  + confirm(userId, reservationId) → BatterySwapReservationDTO       │   │  │
│  │  │  + cancel(userId, reservationId) → BatterySwapReservationDTO         │   │  │
│  │  │  + getMyReservations(userId) → List<BatterySwapReservationDTO>     │   │  │
│  │  │  + getReservation(userId, reservationId) → BatterySwapReservationDTO│  │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  Scheduler jobs:                                                      │   │  │
│  │  │  + expireStaleReservations()  (cron: slot grace + no-slot grace)    │   │  │
│  │  │  + expireUnpaidReservations()  (cron: payment expiry 10 min)       │   │  │
│  │  │  + expireSwapDeadline()  (cron: session expiry 30 min)              │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  Helpers:                                                            │   │  │
│  │  │  + toReservationDto() → maps entity → DTO with station state        │   │  │
│  │  │  + syncAvailableBatteries(stationId, now)                          │   │  │
│  │  │  + estimateReadyAt(now, reservation)                               │   │  │
│  │  │  + internalStart(), internalConfirm(), internalCancel()            │   │  │
│  │  └──────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │  │
│  │  │  SwapCodeService                                                     │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  + getSwapCode(reservationId, userId) → SwapCodeDTO                  │   │  │
│  │  │  + generateSwapCodeInternal(reservation) → SwapCodeResult(code, expiresAt)│ │  │
│  │  │  + expirePendingSessions()                                          │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  CODE_LENGTH = 4, CODE_VALID_MINUTES = 30                          │   │  │
│  │  │  SecureRandom for numeric code generation                           │   │  │
│  │  └──────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │  │
│  │  │  BatterySwapBroadcastService                                         │   │  │
│  │  │  ───────────────────────────────────────────────────────────────────│   │  │
│  │  │  Central facade routing real-time events to appropriate WebSocket    │   │  │
│  │  │  handlers:                                                           │   │  │
│  │  │  + broadcastSlotUpdate(stationId, slot)                             │   │  │
│  │  │      → BatterySwapWebSocketHandler (auth WS) + SimulatorDisplayWS   │   │  │
│  │  │  + broadcastSwapCode(stationId, ..., swapCode, ...)                 │   │  │
│  │  │      → SimulatorDisplayWebSocketHandler ONLY (display screen)       │   │  │
│  │  │  + broadcastSwapCompleted(stationId, slotId, status)                │   │  │
│  │  │      → both auth WS + display WS                                    │   │  │
│  │  │  + broadcastSwapCancelled(stationId, slotId)                        │   │  │
│  │  │      → display WS only                                              │   │  │
│  │  └──────────────────────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Battery Swap Reservation Status Flow

```
┌──────────┐  reserve()   ┌──────────┐  pay()       ┌───────────┐  confirmArrival()  ┌──────────┐  startAndGenerateCode()  ┌───────────┐  confirm()  ┌───────────┐
│  (null)   │ ─────────────▶│ RESERVED │ ─────────────▶│ RESERVED  │ ──────────────────▶ │ RESERVED │ ─────────────────────────▶ │ SWAPPING  │ ──────────▶ │ COMPLETED │
│           │               │ (UNPAID) │               │ (PAID)    │                    │ (ARRIVED)│                            │           │             │           │
└──────────┘               └──────────┘               └───────────┘                    └──────────┘                            └───────────┘             └───────────┘
                                │                          │                              │                                       │
                                │ cancel()                 │ cancel()                     │ cancel()                              │ cancel()
                                ▼                          ▼                              ▼                                       ▼
                          ┌──────────┐               ┌──────────┐                   ┌──────────┐                          ┌──────────┐
                          │CANCELLED│               │CANCELLED│                   │CANCELLED│                          │CANCELLED│
                          │(REFUND) │               │(REFUND) │                   │(REFUND) │                          │(REFUND) │
                          └──────────┘               └──────────┘                   └──────────┘                          └──────────┘
                                │                          │                              │                                       │
                           expire unpaid                expire stale               expire 15-min hold                  expire swap code
                           (10 min)                  (slot grace 15min /                             (30 min)
                                                     no-slot 30min)

  STATUS ENUM:  BatterySwapStatus = { RESERVED, SWAPPING, COMPLETED, CANCELLED, EXPIRED }
  PAYMENT ENUM: PaymentStatus = { UNPAID, PAID, REFUNDED }

  Slot Battery Lifecycle:
  AVAILABLE → RESERVED (on reserve) → OCCUPIED (on start) → SWAPPED_OUT (on confirm)
  SWAPPED_OUT → CHARGING → AVAILABLE (fully charged)

  Slot Status: BatterySlotStatus = { AVAILABLE, OCCUPIED, CHARGING, RESERVED, SWAPPED_OUT }
```

### 1.3 EV User Swap Flow

```
EV USER APP ──▶ BatterySwapScreen ──▶ BatterySwapNotifier
                                    │
                                    ▼
                            stationRepository
                                    │
                                    ▼
                              REST API calls
                                    │
                                    ▼
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                     EV USER BATTERY SWAP API (/api/ev/battery-swap/)          │
  │                                                                               │
  │  1. GET  /stations          → getNearbySwapStations()                       │
  │  2. GET  /stations/{id}      → getStationDetail()                           │
  │  3. POST /reservations       → reserve()                                     │
  │  4. GET  /reservations/mine  → getMyReservations()                          │
  │  5. GET  /reservations/{id}  → getReservation()                             │
  │  6. POST /reservations/{id}/pay              → pay()                        │
  │  7. POST /reservations/{id}/confirm-arrival  → confirmArrival()             │
  │  8. POST /reservations/{id}/start            → startAndGenerateCode()      │
  │  9. GET  /reservations/{id}/swap-code        → getSwapCode()               │
  │ 10. POST /reservations/{id}/verify-swap      → verifySwap() (collab web)   │
  │ 11. POST /reservations/{id}/cancel           → cancel()                     │
  │ 12. GET  /slots/{slotId}/charging             → getSlotChargingSession()   │
  └─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                           BatterySwapBroadcastService
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
         BatterySwapWSHandler  SimulatorDisplayWS
         (auth EV user WS)    (public display)
                    │               │
                    ▼               ▼
         onSlotUpdate()      Station display
         onSwapCompleted()  screen shows
                            swap code
```

---

## PHẦN 2: VERIFICATION TASK (COLLABORATOR)

### 2.1 Class Diagram Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              BACKEND (Spring Boot)                                  │
│                  backend/src/main/java/com/example/evstation/                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  VERIFICATION DOMAIN (verification/domain/)                                   │  │
│  │                                                                              │  │
│  │  ┌─────────────────────────────────┐  ┌──────────────────────────────────────┐ │  │
│  │  │  VerificationTaskStatus (enum)   │  │  VerificationType (enum)              │ │  │
│  │  │  ───────────────────────────── │  │  ────────────────────────────────────│ │  │
│  │  │  OPEN       (created, unassigned)│ │ │  CHARGING_STATION                   │ │  │
│  │  │  ASSIGNED   (assigned to collab) │  │  BATTERY_SWAP                       │ │  │
│  │  │  CHECKED_IN (collab checked in)  │  │                                      │ │  │
│  │  │  SUBMITTED  (evidence submitted)  │  │                                      │ │  │
│  │  │  REVIEWED   (admin reviewed)     │  │                                      │ │  │
│  │  └─────────────────────────────────┘  └──────────────────────────────────────┘ │  │
│  │  ┌─────────────────────────────────┐                                         │  │
│  │  │  VerificationResult (enum)       │                                         │  │
│  │  │  ───────────────────────────── │                                         │  │
│  │  │  PASS, FAIL                      │                                         │  │
│  │  └─────────────────────────────────┘                                         │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  VERIFICATION ENTITIES (verification/infrastructure/jpa/)                     │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐    │  │
│  │  │  VerificationTaskEntity  (@Entity, table: verification_task)           │    │  │
│  │  │  ──────────────────────────────────────────────────────────────────│    │  │
│  │  │  + id: UUID (PK)                                                     │    │  │
│  │  │  + stationId: UUID  ──────────────────┐                             │    │  │
│  │  │  + changeRequestId: UUID? (charging CR)│                             │    │  │
│  │  │  + batterySwapChangeRequestId: UUID?  │ (battery swap CR)           │    │  │
│  │  │  + priority: int (default: 3)          │                             │    │  │
│  │  │  + slaDueAt: Instant?                  │                             │    │  │
│  │  │  + assignedTo: UUID? (→ UserAccount)  │                             │    │  │
│  │  │  + status: VerificationTaskStatus (default: OPEN)                  │    │  │
│  │  │  + verificationType: VerificationType (default: CHARGING_STATION) │    │  │
│  │  │  + checklistJson: String (JSONB) ──┐  │                             │    │  │
│  │  │  + stationSnapshotJson: String (JSONB)──┼─ Snapshot at creation      │    │  │
│  │  │  + batterySwapStationSnapshot: String (JSONB)─┘ (BATTERY_SWAP)     │    │  │
│  │  │  + createdAt: Instant                                             │    │  │
│  │  └──────────────────────────────────────────────────────────────────────┘    │  │
│  │                                       │                                     │    │
│  │         1:1 ┌─────────────────────────┼─────────────────────────┐            │    │
│  │         ┌────▼───────┐  ┌────────────▼──────────────┐  ┌───────▼────────┐  │    │
│  │         │Verification │  │   VerificationCheckin    │  │Verification    │  │    │
│  │         │EvidenceEntity│  │   Entity               │  │ReviewEntity    │  │    │
│  │         │─────────────│  │   ─────────────────────│  │───────────────│  │    │
│  │         │+ id: UUID   │  │   + id: UUID (PK)      │  │+ id: UUID     │  │    │
│  │         │+ taskId: UUID│  │   + taskId: UUID (UNIQUE)│ │+ taskId: UUID│  │    │
│  │         │+ photoObjectKey│  │   + checkinLat, checkinLng│ │ (UNIQUE) │  │    │
│  │         │  (TEXT)     │  │   + checkedInAt: Instant│  │+ result: Result│ │    │
│  │         │+ note: String?│ │   + distanceM: int    │  │+ adminNote?  │  │    │
│  │         │+ submittedAt │  │   + deviceNote: String?│ │+ reviewedAt  │  │    │
│  │         │+ submittedBy │  │   + actualTotalBatteries?│ │+ reviewedBy  │  │    │
│  │         │  UUID        │  │   + actualAvailableBat?  │ │+ swapStationVerif?│ │    │
│  │         │(1:N for      │  │   + observedAvgChargeKW?│ │+ inventoryAccurate?│ │    │
│  │         │ Evidence)    │  │   + checklistAnswersJson │ │+ resolutionNote?│  │    │
│  │         └─────────────┘  └──────────────────────────┘  └────────────────┘  │    │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐    │  │
│  │  │  CollaboratorProfileEntity  (@Entity, table: collaborator_profile)    │    │  │
│  │  │  ──────────────────────────────────────────────────────────────────│    │  │
│  │  │  + id: UUID (PK)                                                     │    │  │
│  │  │  + userAccountId: UUID (UNIQUE → UserAccount)                      │    │  │
│  │  │  + fullName: String?                                                 │    │  │
│  │  │  + phone: String?                                                     │    │  │
│  │  │  + currentLocation: Point (PostGIS geography)                        │    │  │
│  │  │  + locationUpdatedAt: Instant?                                        │    │  │
│  │  │  + locationSource: LocationSource?                                    │    │  │
│  │  │  + createdAt: Instant                                                │    │  │
│  │  └──────────────────────────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  VERIFICATION DTOs (verification/api/dto/)                                  │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐    │  │
│  │  │  VerificationTaskDTO                                                  │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Fields: id, stationId, stationName, changeRequestId, priority,      │    │  │
│  │  │          slaDueAt, assignedTo, assignedToEmail, status,              │    │  │
│  │  │          verificationType, createdAt, stationServiceTypes,           │    │  │
│  │  │          checklist (List<ChecklistItem>),                           │    │  │
│  │  │          stationSnapshot (StationSnapshotDTO)                        │    │  │
│  │  │  Nested: checkin (CheckinDTO), evidences (List<EvidenceDTO>),      │    │  │
│  │  │           review (ReviewDTO)                                        │    │  │
│  │  └──────────────────────────────────────────────────────────────────────┘    │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐    │  │
│  │  │  BatterySwapVerificationTaskDTO  (extends concept, separate DTO)    │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Same fields as VerificationTaskDTO + battery swap specific:       │    │  │
│  │  │  + batterySwapChangeRequestId: String?                             │    │  │
│  │  │  + snapshotTotalBatteries, snapshotAvgChargePowerKw               │    │  │
│  │  │  + snapshotPileCount, snapshotSlotCount                          │    │  │
│  │  │  + snapshotOperatingHours, snapshotParkingFee                     │    │  │
│  │  │  + CheckinDTO.checkin (extends with actualTotalBatteries,         │    │  │
│  │  │       actualAvailableBatteries, observedAvgChargePowerKw)          │    │  │
│  │  └──────────────────────────────────────────────────────────────────────┘    │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐    │  │
│  │  │  ChecklistItem              │  ChecklistAnswer            │ ChecklistAnswerValue│ │
│  │  │  ──────────────────────── │  ──────────────────────── │ ───────────────────│  │
│  │  │  + id: String              │  + itemId: String         │  YES               │  │
│  │  │  + question: String        │  + question: String        │  NO                │  │
│  │  │  + type: String            │  + type: String           │  UNABLE_TO_VERIFY  │  │
│  │  │  + sourceCode: String      │  + sourceCode: String      │                    │  │
│  │  │                            │  + answer: AnswerValue     │                    │  │
│  │  │                            │  + supplementaryNote?     │                    │  │
│  │  └────────────────────────────┘  └────────────────────────┘                    │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  VERIFICATION SERVICE (VerificationService ~1500 lines)                       │  │
│  │                                                                              │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐    │  │
│  │  │  VerificationService                                                  │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Admin Operations:                                                     │    │  │
│  │  │  + createTask(dto, adminId, role) → VerificationTaskDTO              │    │  │
│  │  │  + assignTask(taskId, dto, adminId, role) → VerificationTaskDTO       │    │  │
│  │  │  + assignTaskByUserId(taskId, collabUserId, adminId, role) → DTO     │    │  │
│  │  │  + getTasksByStatus(status, type, pageable) → Page<DTO>               │    │  │
│  │  │  + getTaskById(taskId) → Optional<DTO>                               │    │  │
│  │  │  + reviewTask(taskId, dto, adminId, role) → VerificationTaskDTO      │    │  │
│  │  │  + deleteTask(taskId, adminId, role)                                 │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Battery Swap Admin Operations:                                        │    │  │
│  │  │  + createBatterySwapVerificationTask(stationId, versionId, ...)     │    │  │
│  │  │  + assignBatterySwapTask(taskId, collabUserId, adminId, role)       │    │  │
│  │  │  + getBatterySwapTasksByStatus(status, pageable)                     │    │  │
│  │  │  + getBatterySwapTaskById(taskId)                                   │    │  │
│  │  │  + reviewBatterySwapTask(taskId, dto, adminId, role)                │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Collaborator Mobile Operations:                                      │    │  │
│  │  │  + getTasksForCollaboratorMobile(userId, statuses) → List<DTO>       │    │  │
│  │  │  + checkIn(taskId, dto, userId) → VerificationTaskDTO               │    │  │
│  │  │  + submitEvidence(taskId, dto, userId) → VerificationTaskDTO        │    │  │
│  │  │  + canCollaboratorViewEvidenceObject(userId, objectKey) → bool      │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Battery Swap Mobile Operations:                                      │    │  │
│  │  │  + getBatterySwapTasksForCollaboratorMobile(userId, statuses)       │    │  │
│  │  │  + batterySwapCheckIn(taskId, dto, userId) → BatterySwapDTO         │    │  │
│  │  │  + batterySwapSubmitEvidence(taskId, dto, userId) → BatterySwapDTO  │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Collaborator Web Operations:                                          │    │  │
│  │  │  + getTasksForCollaboratorWeb(userId, status, priority, ...)       │    │  │
│  │  │  + getTaskHistory(userId, pageable) → Page<DTO>                     │    │  │
│  │  │  + getKpi(userId) → CollaboratorKpiDTO                             │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Battery Swap Web Operations:                                          │    │  │
│  │  │  + getBatterySwapTasksForCollaboratorWeb(userId, status, pageable) │    │  │
│  │  │  + getBatterySwapTaskHistory(userId, pageable)                      │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Policy Methods:                                                      │    │  │
│  │  │  + hasPassedVerificationForCR(changeRequestId) → bool               │    │  │
│  │  │  + hasVerificationTaskForCR(changeRequestId) → bool                │    │  │
│  │  │  ───────────────────────────────────────────────────────────────────│    │  │
│  │  │  Key Business Rules (enforced):                                      │    │  │
│  │  │  • assertNotSelfAssigned(): Cannot assign task to the CR submitter   │    │  │
│  │  │    (applies to both CHARGING and BATTERY_SWAP CRs). Throws 409.      │    │  │
│  │  │  • Check-in distance limit: MAX_CHECKIN_DISTANCE_METERS = 200m       │    │  │
│  │  │    (PostGIS ST_Distance calculation)                                  │    │  │
│  │  │  • requireActiveContract(userId): Collab must have active contract   │    │  │
│  │  │  • validateCheckinAnswers(): All checklist items must be answered,  │    │  │
│  │  │    supplementaryNote required for NO/UNABLE_TO_VERIFY                │    │  │
│  │  │  • Checklist auto-generation from RiskReason codes:                  │    │  │
│  │  │    GPS_CHANGED_100M, PORTS_CHANGED, PRICE_CHANGED,                  │    │  │
│  │  │    OPERATING_HOURS_CHANGED, NEW_STATION, BATTERY_INVENTORY_LOW,     │    │  │
│  │  │    BATTERY_SWAP_STATION_REPORTED, TRUST_SCORE_DROPPED               │    │  │
│  │  │  • Trust recalculation on task review completion                    │    │  │
│  │  └──────────────────────────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  VERIFICATION CONTROLLERS                                                   │  │
│  │                                                                              │  │
│  │  AdminVerificationController (/api/admin/verification-tasks)                 │  │
│  │    POST /              → createTask                                         │  │
│  │    POST /{id}/assign   → assignTask                                         │  │
│  │    GET  /              → getTasksByStatus (paginated)                        │  │
│  │    GET  /{id}          → getTaskById                                        │  │
│  │    POST /{id}/review   → reviewTask                                         │  │
│  │    DELETE /{id}         → deleteTask                                         │  │
│  │    GET  /candidates    → CollaboratorCandidateQueryService.getCandidates    │  │
│  │                                                                              │  │
│  │  CollaboratorWebVerificationController (/api/collab/web/tasks)                │  │
│  │    GET /               → getTasksForCollaboratorWeb                          │  │
│  │    GET /history        → getTaskHistory                                     │  │
│  │    GET /kpi            → getKpi                                            │  │
│  │                                                                              │  │
│  │  CollaboratorMobileVerificationController (/api/collab/mobile/tasks)           │  │
│  │    GET /               → getTasksForCollaboratorMobile (by statuses)        │  │
│  │    POST /{id}/check-in → checkIn                                            │  │
│  │    POST /{id}/evidence → submitEvidence                                      │  │
│  │                                                                              │  │
│  │  AdminBatterySwapVerificationController                                     │  │
│  │    POST /swap-tasks                    → createBatterySwapVerificationTask  │  │
│  │    POST /swap-tasks/{id}/assign         → assignBatterySwapTask             │  │
│  │    GET  /swap-tasks                    → getBatterySwapTasksByStatus        │  │
│  │    GET  /swap-tasks/{id}               → getBatterySwapTaskById            │  │
│  │    POST /swap-tasks/{id}/review        → reviewBatterySwapTask             │  │
│  │                                                                              │  │
│  │  CollaboratorWebBatterySwapVerificationController (/api/collab/battery-swap/verification)│
│  │    GET  /              → getBatterySwapTasksForCollaboratorWeb             │  │
│  │    GET  /history       → getBatterySwapTaskHistory                          │  │
│  │    POST /{id}/check-in → batterySwapCheckIn (web)                          │  │
│  │    POST /{id}/evidence → batterySwapSubmitEvidence (web)                   │  │
│  │                                                                              │  │
│  │  CollaboratorMobileBatterySwapVerificationController                        │  │
│  │    GET  /              → getBatterySwapTasksForCollaboratorMobile          │  │
│  │    POST /{id}/check-in → batterySwapCheckIn                                 │  │
│  │    POST /{id}/evidence → batterySwapSubmitEvidence                          │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Verification Task Lifecycle

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         VERIFICATION TASK LIFECYCLE                               │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ADMIN creates task                          COLLABORATOR acts on task             │
│  ──────────────────────                       ──────────────────────────────────  │
│                                                                                   │
│  ┌─────────┐                               ┌─────────────────────────────────────┐ │
│  │  OPEN   │ ◀── createTask()             │                                     │ │
│  └────┬────┘                               │                                     │ │
│       │ assignTask()                        │                                     │ │
│       │ (admin selects collaborator,        │                                     │ │
│       │  validates not self-assigned,       │                                     │ │
│       │  checks active contract)            │                                     │ │
│       ▼                                     │                                     │ │
│  ┌─────────┐                               │                                     │ │
│  │ASSIGNED │                               │                                     │ │
│  └────┬────┘                               │                                     │ │
│       │ checkIn()                          │  checkIn()                         │ │
│       │ (validate: assigned to user,       │  - lat/lng distance ≤ 200m         │ │
│       │  status=ASSIGNED,                  │  - requireActiveContract()          │ │
│       │  active contract,                  │  - validateCheckinAnswers()         │ │
│       │  distance ≤ 200m,                  │    (all checklist items answered,   │ │
│       │  checklist answers valid)          │     note required for NO/UNABLE)    │ │
│       │                                     │                                     │ │
│       ▼                                     │                                     │ │
│  ┌──────────┐                               │                                     │ │
│  │CHECKED_IN│                               │                                     │ │
│  └────┬─────┘                               │                                     │ │
│       │ submitEvidence()                  │  submitEvidence()                    │ │
│       │ (validate: assigned to user,       │  - photoObjectKey (S3 key)         │ │
│       │  status=CHECKED_IN,                │  - note                              │ │
│       │  active contract)                  │  - submits one evidence photo        │ │
│       │                                     │                                     │ │
│       ▼                                     │                                     │ │
│  ┌──────────┐                               │                                     │ │
│  │ SUBMITTED│                               │                                     │ │
│  └────┬─────┘                               │                                     │ │
│       │ reviewTask()                       │                                     │ │
│       │ (admin reviews: PASS/FAIL,        │                                     │ │
│       │  adminNote, then triggers          │                                     │ │
│       │  trustScoringService.recalculate)  │                                     │ │
│       ▼                                     │                                     │ │
│  ┌──────────┐                              │                                     │ │
│  │ REVIEWED │ ────────────────────────────▶│ NOTIFICATION: TASK_REVIEWED_PASS/FAIL│ │
│  └──────────┘                              └─────────────────────────────────────┘ │
│                                                                                   │
│  AUTO-GENERATED CHECKLIST MAPPING (from RiskReason codes):                        │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │ RiskReason Code               │ Generated Question                           │ │
│  │ ─────────────────────────────│────────────────────────────────────────────── │ │
│  │ GPS_CHANGED_100M              │ Has the station's GPS location changed?        │ │
│  │ PORTS_CHANGED                │ Are the number and config of ports correct?     │ │
│  │ PRICE_CHANGED                │ Is the displayed fare correct?                 │ │
│  │ OPERATING_HOURS_CHANGED      │ Are the operating hours correct?               │ │
│  │ NEW_STATION                  │ Is the new station operating normally?          │ │
│  │ BATTERY_INVENTORY_LOW        │ Does battery inventory match current data?      │ │
│  │ BATTERY_SWAP_STATION_REPORTED│ Is the battery swap station operating?         │ │
│  │ TRUST_SCORE_DROPPED         │ Is the trust score stable?                     │ │
│  │ (default, no CR)            │ Generic: operating, location, info correct?   │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  COLLABORATOR KPI (CollaboratorKpiDTO - monthly period):                          │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │ totalReviewed, passCount, failCount, passRate = passCount/totalReviewed*100  │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Entity Relationships Summary

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         RELATIONSHIP DIAGRAM                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  UserAccountEntity (auth)                                                        │
│       │                                                                          │
│       │ 1:1                                                                          │
│       ▼                                                                          │
│  CollaboratorProfileEntity ────N:1──▶ StationVersionEntity (published)            │
│       │                                    ▲                                      │
│       │                                    │ (PostGIS location for                  │
│       │                                    │  distance calculation)                │
│       │                                    │                                      │
│       │                                    │                                      │
│       │              ┌─────────────────────┼─────────────────────┐               │
│       │              │                     │                     │               │
│       │         ┌────┴────────┐     ┌──────┴──────┐     ┌───────┴───────┐       │
│       │         │Verification │     │  ChangeReq  │     │BatterySwap   │       │
│       │         │TaskEntity  │     │  (charging) │     │ChangeRequest │       │
│       │         │            │     │             │     │(battery swap)│       │
│       │         │+ stationId │◀────│ + stationId │     │              │       │
│       │         │+ changeReq │     │             │     │+ stationId   │       │
│       │         │  Id?       │     └─────────────┘     └───────┬──────┘       │
│       │         │+ batterySwap│                              │               │
│       │         │  ChangeReq │                              │               │
│       │         │  Id?       │                              │               │
│       │         └─────┬──────┘                              │               │
│       │               │                                      │               │
│       │        1:1    │         1:N                 1:1    │               │
│       │    ┌───────────┼───────────┐          ┌───────────┼───────────┐       │
│       │    │           │           │          │           │           │       │
│       │    ▼           ▼           │          ▼           ▼           │       │
│       │ Checkin    Evidence    Review    StationSnapshot              │       │
│       │ Entity     Entities    Entity    (JSONB in TaskEntity)        │       │
│       │            (1:N)                                          │       │
│       │                                                            │       │
│       │                                               ┌────────────┘               │
│       │                                               │                            │
│       │                                               ▼                            │
│       │                                    BatterySwapStationStateEntity          │
│       │                                               │                            │
│       │                                    ┌─────────┼─────────┐                 │
│       │                                    │                   │                 │
│       │                                    ▼                   ▼                 │
│       │                               SwapPileEntity  StationVersionEntity       │
│       │                                    │                                       │
│       │                                    │ 1:N                                   │
│       │                                    ▼                                       │
│       │                               BatterySlotEntity                          │
│       │                                                                             │
│       │                                    STAKEHOLDER ACTIONS:                    │
│       │                                    ──────────────────────                   │
│       │                                    • Admin: createTask, assignTask,       │
│       │                                      reviewTask, deleteTask                │
│       │                                    • Collaborator: checkIn,                │
│       │                                      submitEvidence                        │
│       │                                    • System: trustScoringService.         │
│       │                                      recalculate() on REVIEWED              │
│       └─────────────────────────────────────────────────────────────────────────── │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Candidate Selection Logic

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   COLLABORATOR CANDIDATE SELECTION                                 │
│         (CollaboratorCandidateQueryService for Admin UI)                           │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  Admin opens "Assign Task" dialog → system queries candidates:                   │
│                                                                                   │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  SELECT collaborators WHERE:                                               │   │
│  │    • role = COLLABORATOR                                                  │   │
│  │    • has active ContractEntity (ContractPolicyService.requireActive)       │   │
│  │    • NOT the submitter of the originating ChangeRequest                  │   │
│  │    • NOT already assigned to a pending task at the same station           │   │
│  │                                                                             │   │
│  │  FOR EACH candidate, compute:                                              │   │
│  │    • distanceMeters: PostGIS ST_Distance(collaborator.currentLocation,   │   │
│  │                       stationVersion.location)                             │   │
│  │    • stats: completedTasks, activeTasks, failedOrOverdueTasks (monthly)   │   │
│  │    • isCrSubmitter: whether this collab submitted the CR                   │   │
│  │    • contractActive: whether has effective contract                        │   │
│  │                                                                             │   │
│  │  SORT: by distance ascending, then by active tasks ascending              │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                   │
│  Output: CandidateListResponseDTO (paginated)                                     │
│    - stationLat, stationLng (for map display)                                     │
│    - List<CollaboratorCandidateDTO>:                                             │
│        collaboratorUserId, fullName, phone, contractActive,                      │
│        location, distanceMeters, isCrSubmitter, stats                           │
│                                                                                   │
│  Business Rule: assertNotSelfAssigned()                                          │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  THROWS BusinessException(ErrorCode.CONFLICT) if:                         │   │
│  │    task.changeRequestId != null                                           │   │
│  │    AND changeRequest.submittedBy == collaboratorUserId                     │   │
│  │    (same rule applies for batterySwapChangeRequestId)                     │   │
│  │                                                                             │   │
│  │  Audit log written: BLOCK_SELF_ASSIGN action                               │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## PHẦN 3: TỔNG HỢP - CÁC ENUM CHÍNH

### Enum Maps

```
BATTERY SWAPPING ENUMS:

  BatterySwapStatus (reservation lifecycle)
  ├── RESERVED      — đã đặt chỗ, chưa thanh toán
  ├── SWAPPING      — đang trong quá trình đổi pin
  ├── COMPLETED      — hoàn thành thành công
  ├── CANCELLED      — bị hủy (hoàn tiền nếu đã pay)
  └── EXPIRED        — hết hạn (unpaid, slot grace, code deadline)

  PaymentStatus (payment lifecycle)
  ├── UNPAID         — chưa thanh toán
  ├── PAID           — đã thanh toán
  └── REFUNDED       — đã hoàn tiền

  BatterySlotStatus (slot hardware state)
  ├── AVAILABLE     — pin đầy, sẵn sàng đổi
  ├── OCCUPIED       — đang có người đổi pin
  ├── CHARGING       — đang sạc (pin vừa bị lấy đi)
  ├── RESERVED       — đã được đặt chờ đổi
  └── SWAPPED_OUT    — pin cũ đã lấy ra, chờ sạc lại

  SwapPileStatus
  └── ACTIVE, INACTIVE, MAINTENANCE

  SwapSessionStatus (swap code session)
  └── PENDING, SWAPPING, COMPLETED, EXPIRED, CANCELLED

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERIFICATION TASK ENUMS:

  VerificationTaskStatus (task lifecycle)
  ├── OPEN           — tạo rồi, chưa giao
  ├── ASSIGNED       — đã giao cho collaborator
  ├── CHECKED_IN     — collaborator đã check-in tại trạm
  ├── SUBMITTED      — đã nộp bằng chứng (hình ảnh)
  └── REVIEWED       — admin đã duyệt

  VerificationType
  └── CHARGING_STATION, BATTERY_SWAP

  VerificationResult
  └── PASS, FAIL

  ChecklistAnswerValue
  └── YES, NO, UNABLE_TO_VERIFY
```

---

## PHẦN 4: CONFIGURATION CONSTANTS

```
BATTERY SWAP CONFIG (application.yml):
  voltgo.battery-swap.base-price-vnd: 5000
  voltgo.battery-swap.expire-slot-grace-minutes: 15   (hold timer sau confirmArrival)
  voltgo.battery-swap.expire-no-slot-grace-minutes: 30 (reservation grace)
  voltgo.battery-swap.charge-duration-minutes: 60     (full charge time)
  voltgo.battery-swap.payment-expire-minutes: 10      (payment window)

VERIFICATION CONFIG:
  MAX_CHECKIN_DISTANCE_METERS: 200m  (PostGIS ST_Distance)
  DEFAULT_TASK_PRIORITY: 3
  BATTERY_SWAP_TASK_PRIORITY: 2
  SLA_DEFAULT: 7 days from creation
  KPI_PERIOD: current month (monthly)

SWAP CODE CONFIG (SwapCodeService):
  CODE_LENGTH: 4 digits
  CODE_VALID_MINUTES: 30 minutes
```

---

## PHẦN 5: SEQUENCE DIAGRAMS

### 5.1 Battery Swap — EV User Full Flow

```
┌──────────────┐    ┌─────────────────┐    ┌───────────────┐    ┌────────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  EV User     │    │  BatterySwap    │    │  Station      │    │  BatterySwap       │    │  SwapCodeService │    │  BroadcastService │
│  App (Flutter)│    │  Notifier/     │    │  Repository   │    │  Service (Backend) │    │                  │    │                  │
└──────┬───────┘    └───────┬─────────┘    └───────┬───────┘    └─────────┬──────────┘    └────────┬─────────┘    └────────┬─────────┘
       │                    │                    │                    │                     │                    │
       │  1. Open screen   │                    │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  2. loadStations(lat,lng,15km)       │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │  getBatterySwapStations()             │                     │                    │
       │                    │──────────────────────────────────────▶│                     │                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     GET /api/ev/battery-swap/stations         │                    │
       │                    │                    │─────────────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     PostGIS distance query                 │                    │
       │                    │                    │     Return List<BatterySwapStationDTO>     │                    │
       │                    │                    │◀─────────────────────────────────────────────                    │
       │                    │◀──────────────────────────────────────│                     │                    │
       │◀──────────────────│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  3. Tap station   │                    │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  4. getStationDetail(stationId)      │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │  getBatterySwapStationDetail()        │                     │                    │
       │                    │──────────────────────────────────────▶│                     │                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     GET /api/ev/battery-swap/stations/{id}                    │
       │                    │                    │─────────────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     Load SwapPile + BatterySlot data     │                    │
       │                    │                    │     Return BatterySwapStationDetailDTO   │                    │
       │                    │                    │◀─────────────────────────────────────────────                    │
       │                    │◀──────────────────────────────────────│                     │                    │
       │◀──────────────────│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  5. Tap "Đặt pin"│                    │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  6. reserve(expectedArrival, % pin, pileId, slotId)    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │  reserveBatterySwap() │                    │                     │                    │
       │                    │──────────────────────────────────────▶│                     │                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     POST /api/ev/battery-swap/reservations                   │
       │                    │                    │─────────────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     Validate: no active reservation at same station            │
       │                    │                    │     Find/validate target slot                               │
       │                    │                    │     Update BatterySlot: AVAILABLE → RESERVED               │
       │                    │                    │     Create BatterySwapReservationEntity (UNPAID)           │
       │                    │                    │     syncAvailableBatteries()                               │
       │                    │                    │     writeAudit("SWAP_RESERVE")                           │
       │                    │                    │     Return BatterySwapReservationDTO                       │
       │                    │                    │◀─────────────────────────────────────────────                    │
       │                    │◀──────────────────────────────────────│                     │                    │
       │◀──────────────────│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  [Payment Screen]  │                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  7. pay(reservationId) │                    │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │  payBatterySwap()   │                    │                     │                    │
       │                    │──────────────────────────────────────▶│                     │                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     POST /api/ev/battery-swap/reservations/{id}/pay          │
       │                    │                    │─────────────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     If voucher covers full → auto PAID                       │
       │                    │                    │     Else → simulate payment → PAID                            │
       │                    │                    │     Update PaymentStatus = PAID                              │
       │                    │                    │     writeAudit("SWAP_PAY")                                   │
       │                    │                    │     Return updated reservation DTO                           │
       │                    │                    │◀─────────────────────────────────────────────                    │
       │                    │◀──────────────────────────────────────│                     │                    │
       │◀──────────────────│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  8. confirmArrival(reservationId)    │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │  confirmArrivalBatterySwap()        │                     │                    │
       │                    │──────────────────────────────────────▶│                     │                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     POST /api/ev/battery-swap/reservations/{id}/confirm-arrival│
       │                    │                    │─────────────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     Validate: status = RESERVED                               │
       │                    │                    │     Set confirmedArrivalAt = now()                            │
       │                    │                    │     Start 15-minute hold timer                               │
       │                    │                    │     writeAudit("SWAP_CONFIRM_ARRIVAL")                      │
       │                    │                    │     Return updated DTO                                    │
       │                    │                    │◀─────────────────────────────────────────────                    │
       │                    │◀──────────────────────────────────────│                     │                    │
       │◀──────────────────│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  9. start(reservationId)              │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │  startBatterySwap()│                    │                     │                    │
       │                    │──────────────────────────────────────▶│                     │                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     POST /api/ev/battery-swap/reservations/{id}/start     │
       │                    │                    │─────────────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     Validate: status=RESERVED, payment=PAID, confirmedArrival│
       │                    │                    │     Validate: confirmedArrival + 15min not expired          │
       │                    │                    │                     │                     │                    │
       │                    │                    │     generateSwapCodeInternal()      │                     │
       │                    │                    │──────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     Generate 4-digit code (SecureRandom)                  │
       │                    │                    │     Create SwapSessionEntity (PENDING, 30min expiry)     │
       │                    │                    │     Set reservation.swapCode + swapDeadlineAt              │
       │                    │                    │◀───────────────────────────────────────                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     Update BatterySlot: RESERVED → OCCUPIED               │
       │                    │                    │     Set reservation.status = SWAPPING                     │
       │                    │                    │     Set reservation.startedAt, estimatedReadyAt           │
       │                    │                    │     writeAudit("SWAP_START")                              │
       │                    │                    │                     │                     │                    │
       │                    │                    │     broadcastSwapCode()                                    │
       │                    │                    │──────────────────────────────────────▶                    │
       │                    │                    │                    │          broadcastSwapCode()          │
       │                    │                    │                    │          → SimulatorDisplayWS ONLY     │
       │                    │                    │                    │          (code appears on station screen)│
       │                    │                    │                    │◀───────────────────────────────────────│
       │                    │                    │◀─────────────────────────────────────────────│                    │
       │                    │◀──────────────────────────────────────│                    │                    │
       │◀──────────────────│                    │                    │                    │                    │
       │                    │                    │                    │                     │                    │
       │  [Hiển thị mã     │                    │                    │                     │                    │
       │   4 chữ số]       │                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  [User nhập code   │                    │                    │                     │                    │
       │   vào HW Simulator]│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │                    │  HW Simulator verifies code         │
       │                    │                    │                    │  → Slot becomes AVAILABLE          │
       │                    │                    │                    │  → broadcastSlotUpdate()           │
       │                    │                    │                    │◀────────────────────────────────────────────
       │                    │                    │                    │
       │                    │                    │                    │     broadcastSlotUpdate()           │
       │                    │                    │                    │──────────────────────────────────────▶│
       │                    │                    │                    │          authWS + displayWS           │
       │                    │                    │                    │◀──────────────────────────────────────│
       │                    │                    │                    │                     │                    │
       │  10. confirm(reservationId)             │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │  confirmBatterySwap() │                    │                     │                    │
       │                    │──────────────────────────────────────▶│                     │                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     POST /api/ev/battery-swap/reservations/{id}/confirm│
       │                    │                    │─────────────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │
       │                    │                    │     Validate: status=SWAPPING, hold not expired          │
       │                    │                    │     Validate: slot batteryChargePercent = 100             │
       │                    │                    │     Update BatterySlot: OCCUPIED → SWAPPED_OUT        │
       │                    │                    │     Set batteryChargePercent = requestedBatteryPercent  │
       │                    │                    │     Set chargingStartedAt, estimatedFullAt                │
       │                    │                    │     broadcastSlotUpdate()                                  │
       │                    │                    │                     │                     │                    │
       │                    │                    │     Set reservation.status = COMPLETED                    │
       │                    │                    │     Set completedAt                                       │
       │                    │                    │     Set paymentStatus = PAID                              │
       │                    │                    │     syncAvailableBatteries()                              │
       │                    │                    │                     │                     │                    │
       │                    │                    │     LoyaltyPointService.earnPoints() (BATTERY_SWAP)     │
       │                    │                    │     BadgeService.checkAndAwardBadges() (FIRST_SWAP,      │
       │                    │                    │                                   SWAP_COUNT)          │
       │                    │                    │     ReferralService.onRefereeFirstBookingCompleted()    │
       │                    │                    │     RatingEligibilityService.markEligible()              │
       │                    │                    │     writeAudit("SWAP_CONFIRM")                          │
       │                    │                    │                     │                     │                    │
       │                    │                    │     broadcastSwapCompleted()                             │
       │                    │                    │──────────────────────────────────────▶                    │
       │                    │                    │                    │          authWS + displayWS           │
       │                    │                    │                    │◀───────────────────────────────────────│
       │                    │                    │◀─────────────────────────────────────────────│                    │
       │                    │◀──────────────────────────────────────│                    │                    │
       │◀──────────────────│                    │                    │                    │                    │
       │                    │                    │                    │                     │                    │
       │  [Swap completed!  │                    │                    │                     │                    │
       │   Loyalty points   │                    │                    │                     │                    │
       │   awarded]         │                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  ─────────────────────────────────────────────────────────────────────────────── │
       │  REAL-TIME WEB SOCKET (BatterySwapWebSocketService)                            │
       │  ─────────────────────────────────────────────────────────────────────────────── │
       │                    │                    │                    │                     │                    │
       │  [Background]      │                    │                    │                     │                    │
       │  connect()        │                    │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  WS /ws/battery-swap?token=JWT        │                    │                     │                    │
       │──────────────────────────────────────────────────────────────────────────────────────────▶│
       │                    │                    │                    │                     │                    │
       │  subscribeToStation(stationId)        │                    │                     │                    │
       │───────────────────▶│                    │                    │                     │                    │
       │                    │                    │                    │                     │                    │
       │  WS {type:"subscribe", stationId}      │                    │                     │                    │
       │──────────────────────────────────────────────────────────────────────────────────────────▶│
       │                    │                    │                    │                     │                    │
       │◀═══════════════════│═══════════════════│═══════════════════│════════════════════│════════════════════│
       │  ◀══ SLOT_UPDATE ══│═══════════════════│═══════════════════│════════════════════│════════════════════│
       │                    │                    │                    │                     │                    │
       │  BatterySwapWebSocketService parses message               │                    │                     │                    │
       │  → _slotCache[slotId] updated                             │                    │                     │                    │
       │  → _slotUpdateController.add(SlotUpdateEvent)           │                    │                     │                    │
       │  → UI listens via onSlotUpdate() stream                  │                    │                     │                    │
       │  ◀═════════════════════════════════════════════════════════════════════════════│
       │                    │                    │                    │                     │                    │
       │  ◀══ SWAP_COMPLETED ══│═══════════════════│═══════════════════│════════════════════│════════════════════│
       │  App receives completion event via auth WS                │                    │                     │                    │
       │  → loadMyReservations() refreshes UI                     │                    │                     │                    │
       │◀═════════════════════════════════════════════════════════════════════════════│
```

### 5.2 Verification Task — Collaborator Flow

```
┌──────────────┐    ┌─────────────────┐    ┌───────────────┐    ┌────────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐
│ Collaborator │    │  Collaborator   │    │  Verification │    │  Verification     │    │  Collaborator    │    │  TrustScoring   │    │  Notification  │
│ App (Mobile/ │    │  Mobile API     │    │  Controller   │    │  Service          │    │  CandidateQuery  │    │  Service        │    │  Service       │
│ Web)         │    │  Client        │    │               │    │                    │    │  Service         │    │                  │    │               │
└──────┬───────┘    └───────┬─────────┘    └───────┬───────┘    └─────────┬──────────┘    └────────┬─────────┘    └────────┬─────────┘    └───────┬───────┘
       │                    │                    │                    │                     │                    │                    │
       │  ─────────────────────────────────────────────────────────────────────────────── │
       │  PHASE 1: ADMIN CREATES AND ASSIGNS TASK                                      |
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │                    │                    │                    │                     │                    │                    |
       │  [Admin]          │                    │                    │                     │                    │                    |
       │  1. createTask(stationId, priority, checklist, verificationType)             │
       │───────────────────────────────────────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │     POST /api/admin/verification-tasks              │
       │                    │                    │─────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │     Build station snapshot (JSONB)                 │                    │
       │                    │                    │     Generate checklist from risk reasons            │                    │
       │                    │                    │     (or use provided checklist)                    │                    │
       │                    │                    │     Create VerificationTaskEntity (status=OPEN)   │
       │                    │                    │     writeAudit("CREATE_VERIFICATION_TASK")        │
       │                    │                    │◀─────────────────────────────────────────────    │
       │◀──────────────────────────────────────│                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │  [Admin] Get candidates for assignment                                         │
       │  2. getCandidates(stationId, taskId)                                         │
       │───────────────────────────────────────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │     GET /api/admin/verification-tasks/candidates │
       │                    │                    │─────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Query UserAccount.role=COLLABORATOR              │
       │                    │                    │                    │──────────────────────────────────────▶    │
       │                    │                    │                    │◀──────────────────────────────────────│
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Filter: has active Contract (ContractPolicyService)│
       │                    │                    │                    │──────────────────────────────────────▶    │
       │                    │                    │                    │◀──────────────────────────────────────│
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  For each candidate: compute PostGIS ST_Distance │
       │                    │                    │                    │  from currentLocation → stationVersion.location  │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Return: candidateUserId, fullName, phone,       │
       │                    │                    │                    │  distanceMeters, contractActive, isCrSubmitter, │
       │                    │                    │                    │  stats(completed/active/failed monthly)        │
       │                    │                    │◀─────────────────────────────────────────────│                    │
       │◀──────────────────────────────────────│                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │  [Admin] Assign task to collaborator                                         |
       │  3. assignTask(taskId, collaboratorUserId)                                  |
       │───────────────────────────────────────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │     POST /api/admin/verification-tasks/{id}/assign            │
       │                    │                    │─────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │     Validate: task status = OPEN                    │
       │                    │                    │     Validate: user role = COLLABORATOR             │
       │                    │                    │     Validate: collaborator profile exists          │
       │                    │                    │     Validate: contractPolicyService.requireActive()│
       │                    │                    │                     │                     │                    │                    │
       │                    │                    │     assertNotSelfAssigned()                     │                    │
       │                    │                    │     ────────────────────────────────────────    │
       │                    │                    │     If task.changeRequestId != null:              │
       │                    │                    │       Get CR.submittedBy                          │
       │                    │                    │       If submittedBy == collaboratorUserId:      │
       │                    │                    │         writeAudit("BLOCK_SELF_ASSIGN")           │
       │                    │                    │         THROW BusinessException(CONFLICT)         │
       │                    │                    │     Same for batterySwapChangeRequestId          │
       │                    │                    │                     │                     │                    │                    │
       │                    │                    │     Update task: assignedTo, status=ASSIGNED     │
       │                    │                    │     writeAudit("ASSIGN_VERIFICATION_TASK")        │
       │                    │                    │                     │                     │                    │                    │
       │                    │                    │     notificationService.send(TASK_ASSIGNED)       │
       │                    │                    │─────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │◀──────────────────────────────────│
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │◀─────────────────────────────────────────────│                    │
       │◀──────────────────────────────────────│                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │  PHASE 2: COLLABORATOR CHECKS IN                                            |
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │                    │                    │                    │                     │                    │                    |
       │  4. getMyTasks() (mobile: GET /api/collab/mobile/tasks)                   │
       │───────────────────▶│                    │                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │                    │  getTasksForCollaboratorMobile(userId, [ASSIGNED])    │
       │                    │──────────────────────────────────────▶│                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │     GET /api/collab/mobile/tasks              │
       │                    │                    │─────────────────────────────────────────────▶                    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  taskRepository.findByAssignedToAndStatusIn()    │
       │                    │                    │                    │◀──────────────────────────────────────│
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  buildTaskDTO() (resolve station name,          │
       │                    │                    │                    │  assigned email, parse checklist JSON)         │
       │                    │                    │                    │◀──────────────────────────────────────│
       │                    │◀──────────────────────────────────────│                     │                    │                    │
       │◀──────────────────│                    │                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │  5. checkIn(taskId, lat, lng, checklistAnswers)                            │
       │───────────────────▶│                    │                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │                    │  POST /api/collab/mobile/tasks/{id}/check-in         │
       │                    │──────────────────────────────────────▶│                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Validate: task status = ASSIGNED               │
       │                    │                    │                    │  Validate: task.assignedTo == userId          │
       │                    │                    │                    │  Validate: contractPolicyService.requireActive()│
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Calculate distance (PostGIS ST_Distance)        │
       │                    │                    │                    │  IF distance > 200 meters:                  │
       │                    │                    │                    │    THROW BusinessException(VALIDATION_ERROR)    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Parse checklist JSON from task               │
       │                    │                    │                    │  Validate all checklist items answered        │
       │                    │                    │                    │  IF answer = NO or UNABLE_TO_VERIFY:          │
       │                    │                    │                    │    supplementaryNote must be provided        │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Create VerificationCheckinEntity              │
       │                    │                    │                    │  Update task status = CHECKED_IN             │
       │                    │                    │                    │  writeAudit("CHECKIN_VERIFICATION_TASK")      │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │◀──────────────────────────────────────────│
       │                    │◀──────────────────────────────────────│                     │                    │                    │
       │◀──────────────────│                    │                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │  PHASE 3: COLLABORATOR SUBMITS EVIDENCE                                     |
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │                    │                    │                    │                     │                    │                    │
       │  6. submitEvidence(taskId, photoObjectKey, note)                          │
       │───────────────────▶│                    │                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │                    │  POST /api/collab/mobile/tasks/{id}/evidence        │
       │                    │──────────────────────────────────────▶│                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Validate: task.assignedTo == userId          │
       │                    │                    │                    │  Validate: task status = CHECKED_IN          │
       │                    │                    │                    │  Validate: contractPolicyService.requireActive()│
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Find or create VerificationEvidenceEntity     │
       │                    │                    │                    │  Set: photoObjectKey (S3), note, submittedAt │
       │                    │                    │                    │  Update task status = SUBMITTED              │
       │                    │                    │                    │  writeAudit("SUBMIT_VERIFICATION_EVIDENCE")   │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │◀──────────────────────────────────────────│
       │                    │◀──────────────────────────────────────│                     │                    │                    │
       │◀──────────────────│                    │                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │  PHASE 4: ADMIN REVIEWS TASK                                                |
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │                    │                    │                    │                     │                    │                    │
       │  [Admin]          │                    │                    │                     │                    │                    |
       │  7. reviewTask(taskId, result, adminNote)                                 │
       │───────────────────────────────────────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │     POST /api/admin/verification-tasks/{id}/review           │
       │                    │                    │─────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Validate: task status = SUBMITTED            │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Create VerificationReviewEntity             │
       │                    │                    │                    │  Set: result (PASS/FAIL), adminNote,       │
       │                    │                    │                    │  reviewedAt, reviewedBy (adminId)            │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  Update task status = REVIEWED             │
       │                    │                    │                    │  writeAudit("REVIEW_VERIFICATION_TASK")      │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  trustScoringService.recalculate(stationId) │
       │                    │                    │                    │──────────────────────────────────────▶    │
       │                    │                    │                    │◀──────────────────────────────────────│
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  notificationService.send(                │
       │                    │                    │                    │    TASK_REVIEWED_PASS / TASK_REVIEWED_FAIL│
       │                    │                    │                    │──────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │◀──────────────────────────────────│
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │◀─────────────────────────────────────────────│                    │
       │◀──────────────────────────────────────│                    │                     │                    │                    │
       │                    │                    │                    │                     │                    │                    │
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │  BATTERY SWAP VERIFICATION VARIANT (same flow, battery-swap specific):       |
       │  ─────────────────────────────────────────────────────────────────────────────── |
       │                    │                    │                    │                     │                    │                    │
       │  1b. createBatterySwapVerificationTask(stationId, versionId, assigneeId)    │
       │───────────────────────────────────────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │     POST /api/admin/battery-swap/verification/swap-tasks │
       │                    │                    │─────────────────────────────────────────────▶    │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  SLA due = now + 7 days                     │
       │                    │                    │                    │  Build batterySwapStationSnapshot (JSONB) │
       │                    │                    │                    │  Generate BATTERY_SWAP checklist           │
       │                    │                    │                    │  Create VerificationTaskEntity            │
       │                    │                    │                    │    (verificationType=BATTERY_SWAP,         │
       │                    │                    │                    │     priority=2)                          │
       │                    │                    │                    │                     │                    │                    │
       │                    │                    │                    │  batterySwapCheckIn() also captures:     │
       │                    │                    │                    │    actualTotalBatteries,               │
       │                    │                    │                    │    actualAvailableBatteries,             │
       │                    │                    │                    │    observedAvgChargePowerKw               │
       │                    │                    │                    │◀──────────────────────────────────────────│
```

### 5.3 Auto-Expiration & Scheduled Jobs

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                     SCHEDULED JOBS (BatterySwapService)                         │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────┐    ┌────────────────────────┐    ┌────────────────────┐ │
│  │  Spring Scheduler │    │  BatterySwapService    │    │  Database         │ │
│  │  (Cron jobs)    │    │                        │    │                    │ │
│  └────────┬────────┘    └───────────┬────────────┘    └────────┬───────────┘ │
│           │                          │                          │               │
│           │  cron: every 1 min       │                          │               │
│           │──────────────────────────▶│                          │               │
│           │                          │                          │               │
│           │                          │  expireStaleReservations()│              │
│           │                          │──────────────────────────────────────▶   │
│           │                          │                          │               │
│           │                          │  SELECT reservations WHERE:              │
│           │                          │    status = RESERVED                     │
│           │                          │    AND (                               │
│           │                          │      (slot held > slotGraceMinutes)  OR│
│           │                          │      (no slot held > noSlotGraceMins)  │
│           │                          │    )                                   │
│           │                          │◀──────────────────────────────────────│   │
│           │                          │                          │               │
│           │                          │  For each stale:                      │
│           │                          │    status → EXPIRED                   │
│           │                          │    releaseOne battery                  │
│           │                          │    syncAvailableBatteries()            │
│           │                          │    writeAudit("SWAP_EXPIRED")        │
│           │                          │                          │               │
│           │                          │  expireUnpaidReservations()            │
│           │                          │──────────────────────────────────────▶   │
│           │                          │                          │               │
│           │                          │  SELECT reservations WHERE:            │
│           │                          │    status = RESERVED                   │
│           │                          │    AND paymentStatus = UNPAID          │
│           │                          │    AND reservedAt < (now - paymentExpMin)│
│           │                          │◀──────────────────────────────────────│   │
│           │                          │                          │               │
│           │                          │  expireSwapDeadline()                  │
│           │                          │──────────────────────────────────────▶   │
│           │                          │                          │               │
│           │                          │  SELECT swap_sessions WHERE:          │
│           │                          │    status = PENDING                     │
│           │                          │    AND expiresAt < now                 │
│           │                          │◀──────────────────────────────────────│   │
│           │                          │                          │               │
│           │                          │  expirePendingSessions() (SwapCodeService)│
│           │                          │──────────────────────────────────────▶   │
│           │                          │                          │               │
│           │                          │  SwapCodeService:                     │
│           │                          │    session.status → EXPIRED            │
│           │                          │    reservation.status → EXPIRED       │
│           │                          │    slot: RESERVED → AVAILABLE         │
│           │                          │    syncAvailableBatteries()            │
│           │                          │    writeAudit("SWAP_DEADLINE_EXPIRED")│
│           │                          │◀──────────────────────────────────────│   │
│           └──────────────────────────┘                          │               │
│                                                                                 │
└────────────────────────────────────────────────────────────────────────────────┘
```