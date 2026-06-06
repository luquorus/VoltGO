package com.example.evstation.batteryswap.application;

import com.example.evstation.api.ev_user_mobile.dto.BatterySwapReservationDTO;
import com.example.evstation.api.ev_user_mobile.dto.BatterySwapStationDTO;
import com.example.evstation.api.ev_user_mobile.dto.BatterySwapStationDetailDTO;
import com.example.evstation.api.ev_user_mobile.dto.BatterySlotDTO;
import com.example.evstation.api.ev_user_mobile.dto.SwapPileDTO;
import com.example.evstation.api.public_api.dto.StationPilesDTO;
import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import com.example.evstation.batteryswap.domain.BatterySwapStatus;
import com.example.evstation.batteryswap.domain.PaymentStatus;
import com.example.evstation.batteryswap.domain.SwapPileStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapReservationEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapReservationJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapStationStateEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapStationStateJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.loyalty.application.BadgeService;
import com.example.evstation.loyalty.application.LoyaltyPointService;
import com.example.evstation.loyalty.application.RatingEligibilityService;
import com.example.evstation.loyalty.domain.BadgeCriteriaType;
import com.example.evstation.loyalty.domain.EligibilityType;
import com.example.evstation.loyalty.domain.PointSource;
import com.example.evstation.station.domain.ServiceType;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationServiceEntity;
import com.example.evstation.station.infrastructure.jpa.StationServiceJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionEntity;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class BatterySwapService {

    private static final String AUDIT_ENTITY_TYPE = "BATTERY_SWAP_RESERVATION";
    private static final UUID SYSTEM_ACTOR_ID = new UUID(0L, 0L);

    private final BatterySwapReservationJpaRepository reservationRepository;
    private final BatterySwapStationStateJpaRepository stationStateRepository;
    private final SwapPileJpaRepository swapPileRepository;
    private final BatterySlotJpaRepository batterySlotRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final StationServiceJpaRepository stationServiceRepository;
    private final EntityManager entityManager;
    private final Clock clock;
    private final SwapStationStateApplyService swapStationStateApplyService;
    private final SwapCodeService swapCodeService;
    private final AuditLogJpaRepository auditLogRepository;
    private final BatterySwapBroadcastService broadcastService;
    private final LoyaltyPointService loyaltyPointService;
    private final RatingEligibilityService ratingEligibilityService;
    private final BadgeService badgeService;

    @Value("${voltgo.battery-swap.base-price-vnd:5000}")
    private long configuredBasePriceVnd;

    @Value("${voltgo.battery-swap.expire-slot-grace-minutes:15}")
    private long expireSlotGraceMinutes;

    @Value("${voltgo.battery-swap.expire-no-slot-grace-minutes:30}")
    private long expireNoSlotGraceMinutes;

    @Value("${voltgo.battery-swap.charge-duration-minutes:60}")
    private int chargeDurationMinutes;

    @Value("${voltgo.battery-swap.payment-expire-minutes:10}")
    private int paymentExpireMinutes;

    private static final List<BatterySwapStatus> ACTIVE_SWAP_RESERVATION_STATUSES = List.of(
            BatterySwapStatus.RESERVED,
            BatterySwapStatus.SWAPPING);

    @Transactional
    public List<BatterySwapStationDTO> getNearbySwapStations(double lat, double lng, double radiusKm) {
        String sql = """
                SELECT sv.station_id,
                       sv.name,
                       sv.address,
                       ST_Y(CAST(sv.location AS geometry)) as lat,
                       ST_X(CAST(sv.location AS geometry)) as lng,
                       CAST(ST_Distance(
                             CAST(sv.location AS geography),
                             CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography)
                       ) AS DOUBLE PRECISION) / 1000.0 as distance_km
                FROM station_version sv
                JOIN station_service ss ON ss.station_version_id = sv.id
                WHERE sv.workflow_status = 'PUBLISHED'
                  AND ss.service_type = 'BATTERY_SWAP'
                  AND ST_DWithin(
                        CAST(sv.location AS geography),
                        CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
                        :radiusMeters
                  )
                ORDER BY distance_km ASC
                """;
        Query query = entityManager.createNativeQuery(sql);
        query.setParameter("lat", lat);
        query.setParameter("lng", lng);
        query.setParameter("radiusMeters", radiusKm * 1000.0);
        @SuppressWarnings("unchecked")
        List<Object[]> rows = query.getResultList();

        List<BatterySwapStationDTO> results = new ArrayList<>();
        for (Object[] row : rows) {
            UUID stationId = (UUID) row[0];
            stationVersionRepository.findPublishedByStationId(stationId)
                    .ifPresent(swapStationStateApplyService::applyForVersion);
            BatterySwapStationStateEntity state = stationStateRepository.findById(stationId).orElse(null);
            if (state == null) {
                continue;
            }

            List<SwapPileEntity> piles = swapPileRepository.findByStationIdOrderByPileIndexAsc(stationId);
            int totalSlots = piles.stream().mapToInt(p -> p.getSlots().size()).sum();
            long availableSlots = piles.stream()
                    .flatMap(p -> p.getSlots().stream())
                    .filter(s -> s.getStatus() == BatterySlotStatus.AVAILABLE)
                    .count();

            int availableBatteries = (int) availableSlots;

            results.add(BatterySwapStationDTO.builder()
                    .stationId(stationId)
                    .name(Objects.toString(row[1], null))
                    .address(Objects.toString(row[2], null))
                    .lat(((Number) row[3]).doubleValue())
                    .lng(((Number) row[4]).doubleValue())
                    .distanceKm(Math.round(((Number) row[5]).doubleValue() * 10.0) / 10.0)
                    .totalBatteries(state.getTotalBatteries())
                    .availableBatteries(availableBatteries)
                    .avgChargePowerKw(state.getAvgChargePowerKw())
                    .basePriceVnd(configuredBasePriceVnd)
                    .totalPiles(piles.size())
                    .availableSlots((int) availableSlots)
                    .totalSlots(totalSlots)
                    .build());
        }
        return results;
    }

    @Transactional(readOnly = true)
    public BatterySwapStationDetailDTO getStationDetail(UUID stationId) {
        StationVersionEntity version = stationVersionRepository.findPublishedByStationId(stationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Published station not found"));
        requireBatterySwapSupported(version.getId());
        swapStationStateApplyService.applyForVersion(version);

        List<SwapPileEntity> piles = swapPileRepository.findByStationIdOrderByPileIndexAsc(stationId);
        if (piles.isEmpty()) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "No swap piles configured for this station");
        }

        List<SwapPileDTO> pileDtos = piles.stream().map(p -> {
            List<BatterySlotDTO> slotDtos = p.getSlots().stream().map(s -> BatterySlotDTO.builder()
                    .slotId(s.getId())
                    .slotIndex(s.getSlotIndex())
                    .batteryId(s.getBatteryId())
                    .batteryChargePercent(s.getBatteryChargePercent())
                    .status(s.getStatus())
                    .estimatedFullAt(s.getEstimatedFullAt())
                    .updatedAt(s.getUpdatedAt())
                    .build())
                    .collect(Collectors.toList());

            return SwapPileDTO.builder()
                    .pileId(p.getId())
                    .pileIndex(p.getPileIndex())
                    .status(p.getStatus())
                    .slots(slotDtos)
                    .build();
        }).collect(Collectors.toList());

        long totalSlots = pileDtos.stream().mapToInt(p -> p.getSlots().size()).sum();
        long availableSlots = pileDtos.stream()
                .flatMap(p -> p.getSlots().stream())
                .filter(s -> s.getStatus() == BatterySlotStatus.AVAILABLE)
                .count();
        int availableBatteries = (int) availableSlots;

        BatterySwapStationStateEntity state = stationStateRepository.findById(stationId).orElse(null);

        return BatterySwapStationDetailDTO.builder()
                .stationId(stationId)
                .name(version.getName())
                .address(version.getAddress())
                .lat(version.getLocation().getY())
                .lng(version.getLocation().getX())
                .operatingHours(version.getOperatingHours())
                .avgChargePowerKw(state != null ? state.getAvgChargePowerKw() : BigDecimal.valueOf(35.0))
                .basePriceVnd(configuredBasePriceVnd)
                .totalPiles(piles.size())
                .totalSlots((int) totalSlots)
                .availableSlots((int) availableSlots)
                .availableBatteries(availableBatteries)
                .piles(pileDtos)
                .build();
    }

    /**
     * Returns station piles and slots for the hardware simulator display screen.
     * Public endpoint — no authentication required.
     */
    @Transactional(readOnly = true)
    public StationPilesDTO getStationPiles(UUID stationId) {
        stationVersionRepository.findPublishedByStationId(stationId)
                .ifPresent(swapStationStateApplyService::applyForVersion);

        List<SwapPileEntity> piles = swapPileRepository.findByStationIdOrderByPileIndexAsc(stationId);
        String stationName = stationVersionRepository.findPublishedByStationId(stationId)
                .map(StationVersionEntity::getName).orElse(null);

        List<StationPilesDTO.PileDTO> pileDtos = piles.stream().map(p -> {
            List<StationPilesDTO.SlotDTO> slotDtos = p.getSlots().stream().map(s ->
                    StationPilesDTO.SlotDTO.builder()
                            .slotId(s.getId())
                            .slotIndex(s.getSlotIndex())
                            .batteryId(s.getBatteryId())
                            .batteryChargePercent(s.getBatteryChargePercent())
                            .status(s.getStatus())
                            .estimatedFullAt(s.getEstimatedFullAt())
                            .updatedAt(s.getUpdatedAt())
                            .build()
            ).collect(Collectors.toList());

            return StationPilesDTO.PileDTO.builder()
                    .pileId(p.getId())
                    .pileIndex(p.getPileIndex())
                    .status(p.getStatus())
                    .slots(slotDtos)
                    .build();
        }).collect(Collectors.toList());

        return StationPilesDTO.builder()
                .stationId(stationId)
                .stationName(stationName)
                .piles(pileDtos)
                .build();
    }

    /**
     * Returns all published battery swap stations (for public display / simulator).
     */
    @Transactional(readOnly = true)
    public List<BatterySwapStationDTO> listAllSwapStations() {
        String sql = """
                SELECT sv.station_id,
                       sv.name,
                       sv.address,
                       ST_Y(CAST(sv.location AS geometry)) as lat,
                       ST_X(CAST(sv.location AS geometry)) as lng
                FROM station_version sv
                JOIN station_service ss ON ss.station_version_id = sv.id AND ss.service_type = 'BATTERY_SWAP'
                WHERE sv.workflow_status = 'PUBLISHED'
                ORDER BY sv.name ASC
                """;
        @SuppressWarnings("unchecked")
        List<Object[]> rows = entityManager.createNativeQuery(sql).getResultList();

        List<BatterySwapStationDTO> results = new ArrayList<>();
        for (Object[] row : rows) {
            UUID stationId = (UUID) row[0];
            stationVersionRepository.findPublishedByStationId(stationId)
                    .ifPresent(swapStationStateApplyService::applyForVersion);
            BatterySwapStationStateEntity state = stationStateRepository.findById(stationId).orElse(null);
            if (state == null) continue;

            List<SwapPileEntity> piles = swapPileRepository.findByStationIdOrderByPileIndexAsc(stationId);
            int totalSlots = piles.stream().mapToInt(p -> p.getSlots().size()).sum();
            long availableSlots = piles.stream()
                    .flatMap(p -> p.getSlots().stream())
                    .filter(s -> s.getStatus() == BatterySlotStatus.AVAILABLE)
                    .count();

            results.add(BatterySwapStationDTO.builder()
                    .stationId(stationId)
                    .name(Objects.toString(row[1], null))
                    .address(Objects.toString(row[2], null))
                    .lat(row[3] != null ? ((Number) row[3]).doubleValue() : null)
                    .lng(row[4] != null ? ((Number) row[4]).doubleValue() : null)
                    .distanceKm(0.0)
                    .totalBatteries(state.getTotalBatteries())
                    .availableBatteries((int) availableSlots)
                    .avgChargePowerKw(state.getAvgChargePowerKw())
                    .basePriceVnd(configuredBasePriceVnd)
                    .totalPiles(piles.size())
                    .availableSlots((int) availableSlots)
                    .totalSlots(totalSlots)
                    .build());
        }
        return results;
    }

    @Transactional
    public BatterySwapReservationDTO reserve(UUID userId, UUID stationId, Instant expectedArrivalAt,
                                             Integer requestedBatteryPercent,
                                             BigDecimal batteryCapacityKwh, UUID pileId, UUID slotId, String note) {
        StationVersionEntity stationVersion = stationVersionRepository.findPublishedByStationId(stationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Published station not found"));
        requireBatterySwapSupported(stationVersion.getId());
        swapStationStateApplyService.applyForVersion(stationVersion);

        Instant now = Instant.now(clock);

        List<BatterySwapReservationEntity> activeForUser = reservationRepository
                .findByUserIdAndStatusIn(userId, ACTIVE_SWAP_RESERVATION_STATUSES);
        if (activeForUser.stream().anyMatch(r -> r.getStationId().equals(stationId))) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "You already have an active reservation at this station");
        }

        BatterySlotEntity targetSlot;
        final UUID pileIdFinal = pileId;
        if (slotId != null) {
            targetSlot = batterySlotRepository.findById(slotId)
                    .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Slot not found"));
            if (!targetSlot.getPileId().equals(pileId)) {
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Slot does not belong to the specified pile");
            }
            List<SwapPileEntity> stationPiles = swapPileRepository.findByStationIdOrderByPileIndexAsc(stationId);
            boolean belongsToStation = stationPiles.stream()
                    .anyMatch(p -> p.getId().equals(pileIdFinal));
            if (!belongsToStation) {
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Pile does not belong to this station");
            }
            if (targetSlot.getStatus() == BatterySlotStatus.AVAILABLE) {
            } else if (targetSlot.getStatus() == BatterySlotStatus.CHARGING
                    || targetSlot.getStatus() == BatterySlotStatus.SWAPPED_OUT) {
                if (targetSlot.getEstimatedFullAt() != null
                        && targetSlot.getEstimatedFullAt().isAfter(expectedArrivalAt)) {
                    throw new BusinessException(ErrorCode.SLOT_UNAVAILABLE,
                            "Selected slot will not be fully charged by your arrival time. "
                                    + "Please choose a different slot or a later arrival time.");
                }
            } else {
                throw new BusinessException(ErrorCode.SLOT_UNAVAILABLE,
                        "Selected slot is not available. Status: " + targetSlot.getStatus());
            }
        } else {
            List<SwapPileEntity> piles = swapPileRepository.findByStationIdOrderByPileIndexAsc(stationId);
            if (piles.isEmpty()) {
                throw new BusinessException(ErrorCode.SLOT_UNAVAILABLE, "No swap piles configured for this station");
            }
            targetSlot = null;
            UUID selectedPileId = null;
            outer:
            for (SwapPileEntity pile : piles) {
                if (pile.getStatus() != SwapPileStatus.ACTIVE) continue;
                for (BatterySlotEntity slot : pile.getSlots()) {
                    if (slot.getStatus() == BatterySlotStatus.AVAILABLE) {
                        targetSlot = slot;
                        selectedPileId = pile.getId();
                        break outer;
                    }
                    if ((slot.getStatus() == BatterySlotStatus.CHARGING
                            || slot.getStatus() == BatterySlotStatus.SWAPPED_OUT)
                            && slot.getEstimatedFullAt() != null
                            && !slot.getEstimatedFullAt().isAfter(expectedArrivalAt)) {
                        targetSlot = slot;
                        selectedPileId = pile.getId();
                        break outer;
                    }
                }
            }
            if (targetSlot == null) {
                throw new BusinessException(ErrorCode.SLOT_UNAVAILABLE,
                        "No battery available at this station by your arrival time");
            }
            pileId = selectedPileId;
        }

        int updated = batterySlotRepository.updateStatus(
                targetSlot.getId(), BatterySlotStatus.AVAILABLE, BatterySlotStatus.RESERVED, now);
        if (updated == 0) {
            throw new BusinessException(ErrorCode.SLOT_UNAVAILABLE, "Slot was taken by another user, please retry");
        }

        SwapPileEntity pile = swapPileRepository.findById(pileId).orElseThrow();

        BatterySwapReservationEntity reservation = BatterySwapReservationEntity.builder()
                .userId(userId)
                .stationId(stationId)
                .pileId(pileId)
                .slotId(targetSlot.getId())
                .status(BatterySwapStatus.RESERVED)
                .reservedSlotAt(expectedArrivalAt)
                .requestedBatteryPercent(requestedBatteryPercent == null ? 20 : requestedBatteryPercent)
                .batteryCapacityKwh(batteryCapacityKwh == null ? BigDecimal.valueOf(60.0) : batteryCapacityKwh)
                .note(note)
                .reservedAt(now)
                .updatedAt(now)
                .basePriceVnd(configuredBasePriceVnd)
                .paymentStatus(PaymentStatus.UNPAID)
                .build();
        try {
            reservation = reservationRepository.save(reservation);
        } catch (RuntimeException e) {
            batterySlotRepository.updateStatus(targetSlot.getId(), BatterySlotStatus.RESERVED, BatterySlotStatus.AVAILABLE, now);
            entityManager.flush();
            throw e;
        }

        syncAvailableBatteries(stationId, now);

        BatterySwapStationStateEntity stationState = stationStateRepository.findById(stationId).orElseThrow();
        writeAudit(userId, "EV_USER", "SWAP_RESERVE", reservation.getId(),
                Map.of("stationId", stationId.toString(), "pileId", pileId.toString(),
                        "slotId", targetSlot.getId().toString(), "status", BatterySwapStatus.RESERVED.name()));
        return toReservationDto(reservation, stationState, pile.getPileIndex(), resolveStationName(stationId));
    }

    @Transactional
    public BatterySwapReservationDTO start(UUID userId, UUID reservationId) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Swap reservation not found"));
        return internalStart(reservation, userId, "EV_USER");
    }

    /**
     * Start swap: validates conditions, generates swap code, broadcasts to simulator,
     * and transitions status to SWAPPING. User sees the code on the display
     * and enters it on the app to confirm the swap.
     */
    @Transactional
    public BatterySwapReservationDTO startAndGenerateCode(UUID userId, UUID reservationId) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Swap reservation not found"));

        if (reservation.getStatus() != BatterySwapStatus.RESERVED) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Only RESERVED reservation can start swapping. Current: " + reservation.getStatus());
        }
        if (reservation.getPaymentStatus() != PaymentStatus.PAID) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Payment is required before starting swap");
        }
        if (reservation.getConfirmedArrivalAt() == null) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Please confirm arrival first using 'I'm here' button");
        }

        Instant now = Instant.now(clock);
        Instant expiry = reservation.getConfirmedArrivalAt().plus(15, ChronoUnit.MINUTES);
        if (now.isAfter(expiry)) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Hold time expired. Reservation is no longer valid.");
        }

        SwapCodeService.SwapCodeResult codeResult = swapCodeService.generateSwapCodeInternal(reservation);

        if (reservation.getSlotId() != null) {
            int updated = batterySlotRepository.updateStatus(
                    reservation.getSlotId(), BatterySlotStatus.RESERVED, BatterySlotStatus.OCCUPIED, now);
            if (updated == 0) {
                log.warn("startAndGenerateCode: slot {} already changed status", reservation.getSlotId());
            }
        }

        reservation.setStatus(BatterySwapStatus.SWAPPING);
        reservation.setSwapCode(codeResult.code());
        reservation.setSwapDeadlineAt(codeResult.expiresAt());
        reservation.setStartedAt(now);
        reservation.setEstimatedReadyAt(estimateReadyAt(now, reservation));
        reservation.setUpdatedAt(now);
        reservation = reservationRepository.save(reservation);

        swapStationStateApplyService.applyForVersion(
                stationVersionRepository.findPublishedByStationId(reservation.getStationId()).orElse(null));
        try {
            broadcastService.broadcastSwapCode(
                    reservation.getStationId(),
                    reservation.getSlotId(),
                    codeResult.code(),
                    codeResult.expiresAt(),
                    reservation.getPileId(),
                    reservation.getSlotId());
        } catch (Exception e) {
            log.warn("[startAndGenerateCode] Failed to broadcast swap code: {}", e.getMessage());
        }

        writeAudit(userId, "EV_USER", "SWAP_START", reservation.getId(),
                Map.of("stationId", reservation.getStationId().toString(),
                        "swapCode", codeResult.code()));

        BatterySwapStationStateEntity stationState = stationStateRepository.findById(reservation.getStationId())
                .orElse(null);
        SwapPileEntity pile = reservation.getPileId() != null
                ? swapPileRepository.findById(reservation.getPileId()).orElse(null) : null;
        int pileIndex = pile != null ? pile.getPileIndex() : null;
        return toReservationDto(reservation, stationState, pileIndex, resolveStationName(reservation.getStationId()));
    }

    @Transactional
    public BatterySwapReservationDTO confirm(UUID userId, UUID reservationId) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Swap reservation not found"));
        return internalConfirm(reservation, userId, "EV_USER");
    }

    /**
     * User confirms they have arrived at the station.
     * Starts the 15-minute hold timer.
     */
    @Transactional
    public BatterySwapReservationDTO confirmArrival(UUID userId, UUID reservationId) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Swap reservation not found"));
        if (reservation.getStatus() != BatterySwapStatus.RESERVED) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Only reserved reservations can confirm arrival");
        }
        Instant now = Instant.now(clock);
        reservation.setConfirmedArrivalAt(now);
        reservation.setUpdatedAt(now);
        reservation = reservationRepository.save(reservation);
        writeAudit(userId, "EV_USER", "SWAP_CONFIRM_ARRIVAL", reservationId,
                Map.of("stationId", reservation.getStationId().toString()));
        SwapPileEntity pile = reservation.getPileId() != null
                ? swapPileRepository.findById(reservation.getPileId()).orElse(null) : null;
        return toReservationDto(reservation,
                stationStateRepository.findById(reservation.getStationId()).orElse(null),
                pile != null ? pile.getPileIndex() : null,
                resolveStationName(reservation.getStationId()));
    }

    @Transactional
    public BatterySwapReservationDTO pay(UUID userId, UUID reservationId) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Swap reservation not found"));
        if (reservation.getPaymentStatus() == PaymentStatus.PAID) {
            return toReservationDtoWithPileIndex(reservation, "EV_USER");
        }
        if (reservation.getPaymentStatus() == PaymentStatus.REFUNDED) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Payment was refunded");
        }
        if (reservation.getStatus() == BatterySwapStatus.COMPLETED ||
                reservation.getStatus() == BatterySwapStatus.CANCELLED ||
                reservation.getStatus() == BatterySwapStatus.EXPIRED) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Cannot pay for a completed/cancelled/expired reservation");
        }
        Instant now = Instant.now(clock);
        reservation.setPaymentStatus(PaymentStatus.PAID);
        reservation.setUpdatedAt(now);
        reservation = reservationRepository.save(reservation);
        writeAudit(userId, "EV_USER", "SWAP_PAY", reservation.getId(),
                Map.of("stationId", reservation.getStationId().toString(), "amount", String.valueOf(reservation.getBasePriceVnd())));
        return toReservationDtoWithPileIndex(reservation, "EV_USER");
    }

    private BatterySwapReservationDTO toReservationDtoWithPileIndex(
            BatterySwapReservationEntity reservation, String actorRole) {
        BatterySwapStationStateEntity state = stationStateRepository.findById(reservation.getStationId()).orElse(null);
        SwapPileEntity pile = reservation.getPileId() != null
                ? swapPileRepository.findById(reservation.getPileId()).orElse(null) : null;
        return toReservationDto(reservation, state,
                pile != null ? pile.getPileIndex() : null,
                resolveStationName(reservation.getStationId()));
    }

    @Transactional
    public BatterySwapReservationDTO cancel(UUID userId, UUID reservationId) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Swap reservation not found"));
        return internalCancel(reservation, userId, "EV_USER");
    }

    @Transactional(readOnly = true)
    public List<BatterySwapReservationDTO> getMyReservations(UUID userId) {
        return reservationRepository.findByUserIdOrderByReservedAtDesc(userId)
                .stream()
                .map(r -> {
                    SwapPileEntity pile = r.getPileId() != null
                            ? swapPileRepository.findById(r.getPileId()).orElse(null) : null;
                    return toReservationDto(r,
                            stationStateRepository.findById(r.getStationId()).orElse(null),
                            pile != null ? pile.getPileIndex() : null,
                            resolveStationName(r.getStationId()));
                })
                .toList();
    }

    @Transactional
    public void expireStaleReservations() {
        Instant now = Instant.now(clock);
        Instant slotCutoff = now.minus(expireSlotGraceMinutes, ChronoUnit.MINUTES);
        Instant confirmedCutoff = now.minus(expireSlotGraceMinutes, ChronoUnit.MINUTES);
        Instant reservedCutoff = now.minus(expireNoSlotGraceMinutes, ChronoUnit.MINUTES);
        List<BatterySwapReservationEntity> stale =
                reservationRepository.findReservedExpired(slotCutoff, confirmedCutoff, reservedCutoff);
        for (BatterySwapReservationEntity r : stale) {
            if (r.getStatus() != BatterySwapStatus.RESERVED) {
                continue;
            }
            r.setStatus(BatterySwapStatus.EXPIRED);
            r.setUpdatedAt(now);
            reservationRepository.save(r);
            int released = stationStateRepository.releaseOne(r.getStationId(), now);
            if (released == 0) {
                log.warn("expireStaleReservations: releaseOne returned 0 for station {}", r.getStationId());
            }
            entityManager.flush();
            writeAudit(SYSTEM_ACTOR_ID, "SYSTEM", "SWAP_EXPIRED", r.getId(),
                    Map.of("stationId", r.getStationId().toString()));
        }
    }

    @Transactional
    public void expireUnpaidReservations() {
        Instant now = Instant.now(clock);
        Instant cutoff = now.minus(paymentExpireMinutes, ChronoUnit.MINUTES);
        List<BatterySwapReservationEntity> unpaidExpired =
                reservationRepository.findUnpaidExpired(cutoff);
        for (BatterySwapReservationEntity r : unpaidExpired) {
            if (r.getStatus() != BatterySwapStatus.RESERVED
                    || r.getPaymentStatus() != PaymentStatus.UNPAID) {
                continue;
            }
            r.setStatus(BatterySwapStatus.EXPIRED);
            r.setUpdatedAt(now);
            reservationRepository.save(r);
            int released = stationStateRepository.releaseOne(r.getStationId(), now);
            if (released == 0) {
                log.warn("expireUnpaidReservations: releaseOne returned 0 for station {}", r.getStationId());
            }
            entityManager.flush();
            writeAudit(SYSTEM_ACTOR_ID, "SYSTEM", "SWAP_EXPIRED_UNPAID", r.getId(),
                    Map.of("stationId", r.getStationId().toString()));
        }
    }

    private BatterySwapReservationDTO internalStart(BatterySwapReservationEntity reservation,
                                                    UUID actorId, String actorRole) {
        if (reservation.getStatus() != BatterySwapStatus.RESERVED) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Only RESERVED reservation can start swapping");
        }
        if (reservation.getPaymentStatus() != PaymentStatus.PAID) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Payment is required before starting swap");
        }
        if (reservation.getConfirmedArrivalAt() == null) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Please confirm arrival first using 'I'm here' button");
        }
        Instant now = Instant.now(clock);

        Instant expiry = reservation.getConfirmedArrivalAt().plus(15, ChronoUnit.MINUTES);
        if (now.isAfter(expiry)) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Hold time expired. Reservation is no longer valid.");
        }

        BatterySlotEntity slot = reservation.getSlotId() != null
                ? batterySlotRepository.findById(reservation.getSlotId()).orElse(null) : null;
        if (slot == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "Slot not found");
        }

        if (reservation.getSlotId() != null) {
            int updated = batterySlotRepository.updateStatus(
                    reservation.getSlotId(), BatterySlotStatus.RESERVED, BatterySlotStatus.OCCUPIED, now);
            if (updated == 0) {
                log.warn("internalStart: slot {} already changed status", reservation.getSlotId());
            }
        }

        reservation.setStatus(BatterySwapStatus.SWAPPING);
        reservation.setStartedAt(now);
        reservation.setEstimatedReadyAt(estimateReadyAt(now, reservation));
        reservation = reservationRepository.save(reservation);
        BatterySwapStationStateEntity stationState = stationStateRepository.findById(reservation.getStationId())
                .orElseThrow();
        SwapPileEntity pile = reservation.getPileId() != null
                ? swapPileRepository.findById(reservation.getPileId()).orElse(null) : null;
        int pileIndex = pile != null ? pile.getPileIndex() : null;
        writeAudit(actorId, actorRole, "SWAP_START", reservation.getId(),
                Map.of("stationId", reservation.getStationId().toString()));
        return toReservationDto(reservation, stationState, pileIndex, resolveStationName(reservation.getStationId()));
    }

    private BatterySwapReservationDTO internalConfirm(BatterySwapReservationEntity reservation,
                                                    UUID actorId, String actorRole) {
        if (reservation.getStatus() != BatterySwapStatus.SWAPPING) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Only SWAPPING reservation can be confirmed");
        }
        Instant now = Instant.now(clock);

        if (reservation.getConfirmedArrivalAt() != null) {
            Instant expiry = reservation.getConfirmedArrivalAt().plus(15, ChronoUnit.MINUTES);
            if (now.isAfter(expiry)) {
                throw new BusinessException(ErrorCode.INVALID_STATE,
                        "Hold time expired. Reservation is no longer valid.");
            }
        }

        BatterySlotEntity slot = reservation.getSlotId() != null
                ? batterySlotRepository.findById(reservation.getSlotId()).orElse(null) : null;
        if (slot == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "Slot not found");
        }
        if (slot.getBatteryChargePercent() < 100) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Battery is not fully charged yet. Current: " + slot.getBatteryChargePercent() + "%");
        }

        int startPercent = reservation.getRequestedBatteryPercent() != null
                ? reservation.getRequestedBatteryPercent()
                : 0;
        int chargeMinutesNeeded = (int) Math.ceil((100 - startPercent) * chargeDurationMinutes / 100.0);
        Instant estimatedFullAt = now.plus(chargeMinutesNeeded, ChronoUnit.MINUTES);
        int updated = batterySlotRepository.updateStatusWithCharging(
                reservation.getSlotId(),
                BatterySlotStatus.OCCUPIED,
                BatterySlotStatus.SWAPPED_OUT,
                startPercent,
                now,
                estimatedFullAt,
                now);
        if (updated == 0) {
            log.warn("confirm: slot {} already changed status", reservation.getSlotId());
        } else {
            slot.setStatus(BatterySlotStatus.SWAPPED_OUT);
            slot.setBatteryChargePercent(startPercent);
            slot.setChargingStartedAt(now);
            slot.setEstimatedFullAt(estimatedFullAt);
            broadcastService.broadcastSlotUpdate(reservation.getStationId(), slot);
        }
        entityManager.flush();

        reservation.setStatus(BatterySwapStatus.COMPLETED);
        reservation.setCompletedAt(now);
        reservation.setPaymentStatus(PaymentStatus.PAID);
        reservation = reservationRepository.save(reservation);

        syncAvailableBatteries(reservation.getStationId(), now);

        // Loyalty: award points for completed battery swap
        UUID loyaltyUserId = reservation.getUserId();
        loyaltyPointService.earnPoints(loyaltyUserId, PointSource.BATTERY_SWAP, reservation.getId(),
                String.format("Completed battery swap at station %s", reservation.getStationId()));
        loyaltyPointService.incrementSwapCount(loyaltyUserId);
        badgeService.checkAndAwardBadges(loyaltyUserId, BadgeCriteriaType.FIRST_SWAP, 1);
        var profileOpt = loyaltyPointService.getProfile(loyaltyUserId);
        profileOpt.ifPresent(p -> badgeService.checkAndAwardBadges(loyaltyUserId, BadgeCriteriaType.SWAP_COUNT, p.getTotalSwaps()));

        // Loyalty: mark station as eligible for rating
        ratingEligibilityService.markEligible(
                loyaltyUserId, reservation.getStationId(), reservation.getId(),
                EligibilityType.SWAP_USAGE, now);

        BatterySwapStationStateEntity stationState = stationStateRepository.findById(reservation.getStationId())
                .orElseThrow();
        SwapPileEntity pile = reservation.getPileId() != null
                ? swapPileRepository.findById(reservation.getPileId()).orElse(null) : null;
        int pileIndex = pile != null ? pile.getPileIndex() : null;
        writeAudit(actorId, actorRole, "SWAP_CONFIRM", reservation.getId(),
                Map.of("stationId", reservation.getStationId().toString(), "paymentStatus", "PAID"));
        return toReservationDto(reservation, stationState, pileIndex, resolveStationName(reservation.getStationId()));
    }

    private BatterySwapReservationDTO internalCancel(BatterySwapReservationEntity reservation,
                                                     UUID actorId, String actorRole) {
        if (reservation.getStatus() == BatterySwapStatus.COMPLETED || reservation.getStatus() == BatterySwapStatus.CANCELLED) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Reservation already completed or cancelled");
        }
        if (reservation.getStatus() == BatterySwapStatus.EXPIRED) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Reservation already expired");
        }
        Instant now = Instant.now(clock);

        if (reservation.getSlotId() != null) {
            BatterySlotStatus currentStatus = reservation.getStatus() == BatterySwapStatus.SWAPPING
                    ? BatterySlotStatus.OCCUPIED : BatterySlotStatus.RESERVED;
            int updated = batterySlotRepository.updateStatus(
                    reservation.getSlotId(), currentStatus, BatterySlotStatus.AVAILABLE, now);
            if (updated == 0) {
                log.warn("cancel: slot {} already changed status", reservation.getSlotId());
            }
        }

        reservation.setStatus(BatterySwapStatus.CANCELLED);
        reservation.setCancelledAt(now);
        if (reservation.getPaymentStatus() == PaymentStatus.PAID) {
            reservation.setPaymentStatus(PaymentStatus.REFUNDED);
        }
        reservation = reservationRepository.save(reservation);
        syncAvailableBatteries(reservation.getStationId(), now);
        broadcastService.broadcastSwapCancelled(reservation.getStationId(), reservation.getSlotId());
        BatterySwapStationStateEntity stationState = stationStateRepository.findById(reservation.getStationId())
                .orElseThrow();
        SwapPileEntity pile = reservation.getPileId() != null
                ? swapPileRepository.findById(reservation.getPileId()).orElse(null) : null;
        int pileIndex = pile != null ? pile.getPileIndex() : null;
        writeAudit(actorId, actorRole, "SWAP_CANCEL", reservation.getId(),
                Map.of("stationId", reservation.getStationId().toString(),
                        "paymentStatus", reservation.getPaymentStatus().name()));
        return toReservationDto(reservation, stationState, pileIndex, resolveStationName(reservation.getStationId()));
    }

    private Instant estimateReadyAt(Instant now, BatterySwapReservationEntity reservation) {
        double neededKwh = reservation.getBatteryCapacityKwh().doubleValue()
                * (100 - reservation.getRequestedBatteryPercent()) / 100.0;
        BatterySwapStationStateEntity state = stationStateRepository.findById(reservation.getStationId())
                .orElseThrow();
        double avgPowerKw = Math.max(10.0, state.getAvgChargePowerKw().doubleValue());
        long chargeMinutes = (long) Math.ceil((neededKwh / avgPowerKw) * 60.0);
        return now.plus(chargeMinutes, ChronoUnit.MINUTES);
    }

    private void requireBatterySwapSupported(UUID stationVersionId) {
        List<StationServiceEntity> services = stationServiceRepository.findByStationVersionId(stationVersionId);
        boolean supported = services.stream().anyMatch(s -> s.getServiceType() == ServiceType.BATTERY_SWAP);
        if (!supported) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Station does not support battery swap");
        }
    }

    private String resolveStationName(UUID stationId) {
        return stationVersionRepository.findPublishedByStationId(stationId)
                .map(StationVersionEntity::getName)
                .orElse(null);
    }

    private BatterySwapReservationDTO toReservationDto(BatterySwapReservationEntity reservation,
                                                       BatterySwapStationStateEntity stationState,
                                                       Integer pileIndex,
                                                       String stationName) {
        BatterySwapReservationDTO.StationStateDTO stateDto = null;
        if (stationState != null) {
            stateDto = BatterySwapReservationDTO.StationStateDTO.builder()
                    .totalBatteries(stationState.getTotalBatteries())
                    .availableBatteries(stationState.getAvailableBatteries())
                    .avgChargePowerKw(stationState.getAvgChargePowerKw())
                    .build();
        }

        Integer slotIndex = null;
        Integer slotBatteryChargePercent = null;
        String slotStatus = null;
        if (reservation.getSlotId() != null) {
            Optional<BatterySlotEntity> slotOpt = batterySlotRepository.findById(reservation.getSlotId());
            slotIndex = slotOpt.map(BatterySlotEntity::getSlotIndex).orElse(null);
            slotBatteryChargePercent = slotOpt.map(BatterySlotEntity::getBatteryChargePercent).orElse(null);
            slotStatus = slotOpt.map(s -> s.getStatus().name()).orElse(null);
        }

        return BatterySwapReservationDTO.builder()
                .id(reservation.getId())
                .stationId(reservation.getStationId())
                .stationName(stationName)
                .pileId(reservation.getPileId())
                .pileIndex(pileIndex)
                .slotId(reservation.getSlotId())
                .slotIndex(slotIndex)
                .slotBatteryChargePercent(slotBatteryChargePercent)
                .slotStatus(slotStatus)
                .status(reservation.getStatus())
                .paymentStatus(reservation.getPaymentStatus())
                .basePriceVnd(reservation.getBasePriceVnd())
                .reservedSlotAt(reservation.getReservedSlotAt())
                .requestedBatteryPercent(reservation.getRequestedBatteryPercent())
                .batteryCapacityKwh(reservation.getBatteryCapacityKwh())
                .estimatedReadyAt(reservation.getEstimatedReadyAt())
                .reservedAt(reservation.getReservedAt())
                .startedAt(reservation.getStartedAt())
                .completedAt(reservation.getCompletedAt())
                .cancelledAt(reservation.getCancelledAt())
                .confirmedArrivalAt(reservation.getConfirmedArrivalAt())
                .note(reservation.getNote())
                .swapCode(reservation.getSwapCode())
                .swapDeadlineAt(reservation.getSwapDeadlineAt())
                .stationState(stateDto)
                .build();
    }

    void syncAvailableBatteries(UUID stationId, Instant now) {
        long availableCount = batterySlotRepository
                .countByStationIdAndStatus(stationId, BatterySlotStatus.AVAILABLE);
        stationStateRepository.syncAvailableBatteries(stationId, (int) availableCount, now);
    }

    @Transactional
    public void expireSwapDeadline() {
        Instant now = Instant.now(clock);
        List<BatterySwapReservationEntity> expired =
                reservationRepository.findExpiredSwapDeadline(now);
        for (BatterySwapReservationEntity r : expired) {
            if (r.getStatus() != BatterySwapStatus.RESERVED &&
                    r.getStatus() != BatterySwapStatus.SWAPPING) {
                continue;
            }
            r.setStatus(BatterySwapStatus.EXPIRED);
            r.setUpdatedAt(now);
            r.setCancelledAt(now);
            reservationRepository.save(r);

            if (r.getSlotId() != null) {
                batterySlotRepository.updateStatus(
                        r.getSlotId(), BatterySlotStatus.RESERVED,
                        BatterySlotStatus.AVAILABLE, now);
            }

            syncAvailableBatteries(r.getStationId(), now);
            writeAudit(SYSTEM_ACTOR_ID, "SYSTEM", "SWAP_DEADLINE_EXPIRED", r.getId(),
                    Map.of("stationId", r.getStationId().toString(),
                            "swapDeadline", r.getSwapDeadlineAt() != null ? r.getSwapDeadlineAt().toString() : "null"));
        }
    }

    @Transactional(readOnly = true)
    public BatterySwapReservationDTO getReservation(UUID userId, UUID reservationId) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Reservation not found"));
        BatterySwapStationStateEntity state = stationStateRepository.findById(reservation.getStationId()).orElse(null);
        SwapPileEntity pile = reservation.getPileId() != null
                ? swapPileRepository.findById(reservation.getPileId()).orElse(null) : null;
        Integer pileIndex = pile != null ? pile.getPileIndex() : null;
        return toReservationDto(reservation, state, pileIndex, resolveStationName(reservation.getStationId()));
    }

    private void writeAudit(UUID actorId, String actorRole, String action, UUID entityId, Map<String, Object> metadata) {
        AuditLogEntity logEntity = AuditLogEntity.builder()
                .actorId(actorId)
                .actorRole(actorRole)
                .action(action)
                .entityType(AUDIT_ENTITY_TYPE)
                .entityId(entityId)
                .metadata(metadata == null ? Map.of() : metadata)
                .createdAt(Instant.now(clock))
                .build();
        auditLogRepository.save(logEntity);
    }
}
