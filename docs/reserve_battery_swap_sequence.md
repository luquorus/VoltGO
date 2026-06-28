# Reserve Battery Swap Service - Sequence Diagram

## PlantUML Source

```plantuml
@startuml ReserveBatterySwapSequence
!theme plain

title Reserve Battery Swap - Sequence Diagram\n(Use Case: EV User reserves a battery swap slot)

header VoltGO Backend
footer Page %page% of %total%

actor "EV User\n(App)" as User
participant "EvBatterySwapController" as Controller
participant "BatterySwapService" as Service
participant "StationVersionJpaRepository" as StationVersionRepo
participant "SwapStationStateApplyService" as StateApplySvc
participant "BatterySwapReservationJpaRepository" as ReservationRepo
participant "SwapPileJpaRepository" as PileRepo
participant "BatterySlotJpaRepository" as SlotRepo
participant "BatterySwapStationStateJpaRepository" as StateRepo
participant "AuditLogJpaRepository" as AuditRepo
participant "BatterySwapBroadcastService" as BroadcastSvc
database "PostgreSQL\n(battery_swap_reservation)" as DB

== 1. RESERVE BATTERY SWAP ==

User -> Controller: POST /api/ev/battery-swap/reservations\n{BatterySwapReserveRequestDTO}
note right: stationId, expectedArrivalAt,\nrequestedBatteryPercent, pileId, slotId

Controller -> Service: reserve(userId, stationId, expectedArrivalAt,\nrequestedBatteryPercent, batteryCapacityKwh, pileId, slotId, note)

group Validation Phase
    Service -> StationVersionRepo: findPublishedByStationId(stationId)
    StationVersionRepo --> Service: StationVersionEntity?
    alt Station not found
        Service --> User: 404 NOT_FOUND\n"Published station not found"
    end

    Service -> Service: requireBatterySwapSupported(stationVersionId)
    note right: Check station_service has BATTERY_SWAP service

    Service -> StateApplySvc: applyForVersion(stationVersion)
    StateApplySvc -> StateApplySvc: Sync station state if needed
end

group Check Existing Reservation
    Service -> ReservationRepo: findByUserIdAndStatusIn(userId, [RESERVED, SWAPPING])
    ReservationRepo --> Service: List<BatterySwapReservationEntity>

    alt User already has active reservation at this station
        Service --> User: 400 VALIDATION_ERROR\n"You already have an active reservation at this station"
    end
end

group Slot Selection

    alt User specified slotId and pileId
        Service -> SlotRepo: findById(slotId)
        SlotRepo --> Service: BatterySlotEntity?

        Service -> Service: Validate slot belongs to pile\nValidate pile belongs to station

        alt Slot not AVAILABLE
            Service -> Service: Check if CHARGING/SWAPPED_OUT\nand estimatedFullAt > expectedArrivalAt
            alt Slot will not be ready
                Service --> User: 400 SLOT_UNAVAILABLE\n"Selected slot will not be fully charged..."
            else Slot not available
                Service --> User: 400 SLOT_UNAVAILABLE\n"Selected slot is not available"
            end
        end
    else Auto-select slot
        Service -> PileRepo: findByStationIdOrderByPileIndexAsc(stationId)
        PileRepo --> Service: List<SwapPileEntity>

        loop For each pile (ACTIVE only)
            loop For each slot in pile
                alt Slot AVAILABLE
                    Service -> Service: targetSlot = slot, break
                else Slot CHARGING/SWAPPED_OUT and estimatedFullAt <= expectedArrivalAt
                    Service -> Service: targetSlot = slot, break
                end
            end
        end

        alt No slot available
            Service --> User: 400 SLOT_UNAVAILABLE\n"No battery available at this station..."
        end
    end
end

group Atomic Slot Reservation
    Service -> SlotRepo: updateStatus(targetSlot.id, AVAILABLE, RESERVED, now)
    SlotRepo -> DB: UPDATE battery_slot SET status='RESERVED'\nWHERE id=? AND status='AVAILABLE'
    DB --> SlotRepo: updatedRows (1 = success, 0 = conflict)

    alt Slot already taken (race condition)
        SlotRepo --> Service: 0 rows updated
        Service --> User: 400 SLOT_UNAVAILABLE\n"Slot was taken by another user, please retry"
    end
end

group Create Reservation Entity
    Service -> Service: Build BatterySwapReservationEntity
    note right
        - status = RESERVED
        - paymentStatus = UNPAID
        - reservedAt = now
        - basePriceVnd = 5000 (configurable)
    end note

    Service -> ReservationRepo: save(reservation)
    ReservationRepo -> DB: INSERT battery_swap_reservation (...)
    DB --> ReservationRepo: BatterySwapReservationEntity (with ID)
    ReservationRepo --> Service: BatterySwapReservationEntity
end

group Sync & Broadcast
    Service -> StateApplySvc: applyForVersion(stationVersion)

    Service -> Service: syncAvailableBatteries(stationId, now)
    Service -> StateRepo: syncAvailableBatteries(stationId, count, now)
    StateRepo -> DB: UPDATE battery_swap_station_state\nSET available_batteries=?

    Service -> BroadcastSvc: broadcastSlotUpdate(stationId, slot)
    BroadcastSvc -> BroadcastSvc: Send to auth WS + display WS
end

group Audit Logging
    Service -> AuditRepo: writeAudit(userId, "EV_USER", "SWAP_RESERVE", reservationId, metadata)
    AuditRepo -> DB: INSERT audit_log (...)
end

Service -> Service: toReservationDto(reservation, stationState, pileIndex, stationName)

Controller <-- Service: BatterySwapReservationDTO
User <-- Controller: 200 OK\n{BatterySwapReservationDTO}

== 2. CONFIRM ARRIVAL ==

User -> Controller: POST /api/ev/battery-swap/reservations/{id}/confirm-arrival

Controller -> Service: confirmArrival(userId, reservationId)
Service -> ReservationRepo: findByIdAndUserId(reservationId, userId)

alt Reservation not found
    Service --> User: 404 NOT_FOUND
end

Service -> Service: Validate status == RESERVED
alt Invalid state
    Service --> User: 400 INVALID_STATE
end

Service -> ReservationRepo: reservation.setConfirmedArrivalAt(now)\n.save()
ReservationRepo -> DB: UPDATE battery_swap_reservation\nSET confirmed_arrival_at=?, updated_at=?

Service -> AuditRepo: writeAudit(userId, "EV_USER", "SWAP_CONFIRM_ARRIVAL", reservationId, metadata)

Service --> Controller: BatterySwapReservationDTO
User <-- Controller: 200 OK

note right of User
    15-minute hold timer starts here
end note

== 3. PAYMENT ==

User -> Controller: POST /api/ev/battery-swap/reservations/{id}/pay

Controller -> Service: pay(userId, reservationId)
Service -> ReservationRepo: findByIdAndUserId(reservationId, userId)

alt Already paid
    Service --> Controller: Return existing DTO
end

alt Status is COMPLETED/CANCELLED/EXPIRED
    Service --> User: 400 INVALID_STATE
end

group Voucher Check
    alt voucherRedemptionId != null && discountAmountVnd >= basePriceVnd
        Service -> Service: paymentStatus = PAID (free swap)
    else
        Service -> Service: paymentStatus = PAID (simulated payment)
    end
end

Service -> ReservationRepo: save(reservation)
ReservationRepo -> DB: UPDATE battery_swap_reservation SET payment_status='PAID'

Service -> AuditRepo: writeAudit(userId, "EV_USER", "SWAP_PAY", reservationId, metadata)

Service --> Controller: BatterySwapReservationDTO
User <-- Controller: 200 OK

== 4. START SWAP (Generate Code) ==

User -> Controller: POST /api/ev/battery-swap/reservations/{id}/start

Controller -> Service: startAndGenerateCode(userId, reservationId)
Service -> ReservationRepo: findByIdAndUserId(reservationId, userId)

Service -> Service: Validate business rules
note right
    - status == RESERVED
    - paymentStatus == PAID
    - confirmedArrivalAt != null
    - now <= confirmedArrivalAt + 15 min
end note

alt Validation failed
    Service --> User: 400 INVALID_STATE
end

group Generate Swap Code
    Service -> Service: generateNumericCode() → "1234"
    note right: 4-digit numeric code, SecureRandom

    Service -> Service: expiresAt = now + 30 minutes
end

group Create Swap Session
    Service -> ReservationRepo: reservation.setSwapCode(code)\n.setSwapDeadlineAt(expiresAt)
    Service -> ReservationRepo: save(reservation)

    note right: SwapSessionEntity created with PENDING status
end

group Update Slot Status
    Service -> SlotRepo: updateStatus(slotId, RESERVED, OCCUPIED, now)
    SlotRepo -> DB: UPDATE battery_slot SET status='OCCUPIED'
end

Service -> BroadcastSvc: broadcastSwapCode(stationId, slotId, code, expiresAt, pileId, slotId)
note right: Sent to SIMULATOR DISPLAY only (public WS)

Service -> StateApplySvc: applyForVersion(stationVersion)

Service -> AuditRepo: writeAudit(userId, "EV_USER", "SWAP_START", reservationId, metadata)

Service --> Controller: BatterySwapReservationDTO\n(with swapCode field)
User <-- Controller: 200 OK

note right of User
    User sees code on physical station display
    User enters code in app to confirm swap
end note

== 5. VERIFY SWAP COMPLETION ==

User -> Controller: POST /api/ev/battery-swap/reservations/{id}/verify-swap\n{swapCode: "1234"}

Controller -> Service: confirmSwapCompletion(reservationId, userId, swapCode)
Service -> ReservationRepo: findByIdAndUserId(reservationId, userId)

Service -> Service: Load SwapSessionEntity

alt Invalid code
    Service --> User: 400 VALIDATION_ERROR\n"Invalid swap code"
end

alt Code expired
    Service --> User: 400 INVALID_STATE\n"Swap code has expired"
end

group Complete Swap Process
    Service -> SlotRepo: slot.setStatus(SWAPPED_OUT)\n.setBatteryChargePercent(requestedBatteryPercent)\n.setChargingStartedAt(now)
    Service -> SlotRepo: save(slot)

    Service -> Service: Calculate estimatedFullAt\n= now + chargeMinutesNeeded

    Service -> ReservationRepo: reservation.setStatus(COMPLETED)\n.setCompletedAt(now)
    Service -> ReservationRepo: save(reservation)
end

group Loyalty Integration
    Service -> Service: loyaltyPointService.earnPoints(userId, BATTERY_SWAP, ...)
    Service -> Service: loyaltyPointService.incrementSwapCount(userId)
    Service -> Service: badgeService.checkAndAwardBadges(userId, FIRST_SWAP, 1)
    Service -> Service: badgeService.checkAndAwardBadges(userId, SWAP_COUNT, totalSwaps)
    Service -> Service: referralService.onRefereeFirstBookingCompleted(userId)
    Service -> Service: ratingEligibilityService.markEligible(...)
end

Service -> BroadcastSvc: broadcastSwapCompleted(stationId, slotId, "COMPLETED")
Service -> BroadcastSvc: broadcastSlotUpdate(stationId, slot)

Service -> Service: syncAvailableBatteries(stationId)

Service --> Controller: SwapSessionDTO
User <-- Controller: 200 OK

== 6. CANCEL RESERVATION ==

User -> Controller: POST /api/ev/battery-swap/reservations/{id}/cancel

Controller -> Service: cancel(userId, reservationId)
Service -> ReservationRepo: findByIdAndUserId(reservationId, userId)

alt Already COMPLETED/CANCELLED/EXPIRED
    Service --> User: 400 INVALID_STATE
end

group Release Slot
    Service -> SlotRepo: updateStatus(slotId, currentStatus, AVAILABLE, now)
    SlotRepo -> DB: UPDATE battery_slot SET status='AVAILABLE'
end

Service -> ReservationRepo: reservation.setStatus(CANCELLED)\n.setCancelledAt(now)\n.setPaymentStatus(REFUNDED if was PAID)
Service -> ReservationRepo: save(reservation)

Service -> Service: syncAvailableBatteries(stationId)
Service -> BroadcastSvc: broadcastSwapCancelled(stationId, slotId)
Service -> AuditRepo: writeAudit(userId, "EV_USER", "SWAP_CANCEL", reservationId, metadata)

Service --> Controller: BatterySwapReservationDTO
User <-- Controller: 200 OK

== 7. AUTO EXPIRE (Scheduled Job) ==

schedule "Every 1 minute" as ExpireJob

ExpireJob -> Service: expireStaleReservations()
Service -> ReservationRepo: findReservedExpired(cutoffTimes)
note right: Finds RESERVED with expired hold time

loop For each stale reservation
    Service -> ReservationRepo: setStatus(EXPIRED).save()
    Service -> StateRepo: releaseOne(stationId, now)
    Service -> AuditRepo: writeAudit(SYSTEM_ACTOR, "SYSTEM", "SWAP_EXPIRED", ...)
end

ExpireJob -> Service: expireUnpaidReservations()
Service -> ReservationRepo: findUnpaidExpired(cutoff)
note right: Finds UNPAID reservations > 10 min

ExpireJob -> Service: expireSwapDeadline()
Service -> ReservationRepo: findExpiredSwapDeadline(now)
note right: Finds SWAPPING with expired swap deadline

ExpireJob -> Service: swapCodeService.expirePendingSessions()
note right: Marks SwapSession as EXPIRED\nand reservation as EXPIRED

@enduml
```

---

## Biểu đồ PlantUML dạng ASCII (để preview nhanh)

```
┌─────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│   User   │     │  EvBatterySwapController │     │  BatterySwapService  │
└────┬────┘     └──────────┬───────────┘     └──────────┬──────────┘
     │                     │                            │
     │ POST /reservations  │                            │
     │────────────────────>│                            │
     │                     │ reserve()                 │
     │                     │──────────────────────────>│
     │                     │                            │
     │                     │  findPublishedByStationId()│
     │                     │<───────────────────────────│
     │                     │                            │
     │                     │  findByUserIdAndStatusIn() │
     │                     │──────────────────────────>│
     │                     │<───────────────────────────│
     │                     │                            │
     │                     │  updateStatus(AVAILABLE→RESERVED)
     │                     │──────────────────────────>│
     │                     │<───────────────────────────│
     │                     │                            │
     │                     │  ReservationRepo.save()    │
     │                     │──────────────────────────>│
     │                     │<───────────────────────────│
     │                     │                            │
     │                     │  syncAvailableBatteries()  │
     │                     │──────────────────────────>│
     │                     │                            │
     │                     │  broadcastSlotUpdate()      │
     │                     │──────────────────────────>│
     │                     │                            │
     │                     │  writeAudit()              │
     │                     │──────────────────────────>│
     │                     │                            │
     │  200 OK DTO         │                            │
     │<────────────────────│                            │
     │                     │                            │
```

---

## State Transitions trong Sequence

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RESERVATION LIFECYCLE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  [1] RESERVE                                                                │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    │
│  │ User selects     │───▶│ Service:          │───▶│ DB: battery_swap_   │    │
│  │ station, slot    │    │ 1. Validate       │    │ reservation created│    │
│  │ (or auto)       │    │ 2. Check existing │    │ status=RESERVED    │    │
│  └─────────────────┘    │ 3. Atomic lock    │    │ payment=UNPAID     │    │
│                         │ 4. Create entity   │    └────────────────────┘    │
│                         └──────────────────┘                               │
│                                                                              │
│  [2] CONFIRM ARRIVAL                                                         │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    │
│  │ User clicks      │───▶│ Update confirmed │───▶│ 15-min hold timer   │    │
│  │ "I'm here"       │    │ _arrival_at=NOW  │    │ starts              │    │
│  └─────────────────┘    └──────────────────┘    └────────────────────┘    │
│                                                                              │
│  [3] PAY                                                                    │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    │
│  │ User pays        │───▶│ payment_status   │───▶│ Ready to start      │    │
│  │ (or voucher)     │    │ = PAID           │    │ swap               │    │
│  └─────────────────┘    └──────────────────┘    └────────────────────┘    │
│                                                                              │
│  [4] START                                                                  │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    │
│  │ User clicks      │───▶│ Generate 4-digit │───▶│ Broadcast to        │    │
│  │ "Start swap"     │    │ swap_code        │    │ simulator display   │    │
│  └─────────────────┘    │ expiresAt+30min  │    └────────────────────┘    │
│                        └──────────────────┘                               │
│                        slot status=                                       │
│                        RESERVED→OCCUPIED                                   │
│                                                                              │
│  [5] VERIFY COMPLETION                                                      │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    │
│  │ User enters      │───▶│ Validate code    │───▶│ Update:            │    │
│  │ swap_code in app │    │ Check not expired│    │ - slot=SWAPPED_OUT│    │
│  └─────────────────┘    └──────────────────┘    │ - reservation=    │    │
│                                                   │   COMPLETED       │    │
│                                                   │ - Award loyalty   │    │
│                                                   │   points/badges   │    │
│                                                   └────────────────────┘    │
│                                                                              │
│  [6] CANCEL (anytime before COMPLETED)                                       │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    │
│  │ User cancels     │───▶│ Release slot      │───▶│ Refund if PAID     │    │
│  │ reservation      │    │ to AVAILABLE      │    │ status=CANCELLED   │    │
│  └─────────────────┘    └──────────────────┘    └────────────────────┘    │
│                                                                              │
│  [7] AUTO EXPIRE (scheduled)                                                │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    │
│  │ @Scheduled job   │───▶│ Find expired      │───▶│ Mark EXPIRED       │    │
│  │ every 1 minute   │    │ reservations      │    │ Release slots      │    │
│  └─────────────────┘    └──────────────────┘    └────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Thông tin File

- **File**: `docs/reserve_battery_swap_sequence.md`
- **Generated**: 2026-06-28
- **Source Code Analysis**: Based on `BatterySwapService.java`, `EvBatterySwapController.java`, and related entities
- **Tool**: PlantUML (VS Code Extension: PlantUML, or render at plantuml.com)
