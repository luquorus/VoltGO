package com.example.evstation.batteryswap.application;

import com.example.evstation.api.ev_user_mobile.dto.SwapSessionDTO;
import com.example.evstation.api.ev_user_mobile.dto.SwapVerifyRequestDTO;
import com.example.evstation.api.ev_user_mobile.dto.ChargingSessionDTO;
import com.example.evstation.batteryswap.domain.*;
import com.example.evstation.batteryswap.infrastructure.jpa.*;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.loyalty.application.BadgeService;
import com.example.evstation.loyalty.application.LoyaltyPointService;
import com.example.evstation.loyalty.application.RatingEligibilityService;
import com.example.evstation.loyalty.domain.BadgeCriteriaType;
import com.example.evstation.loyalty.domain.EligibilityType;
import com.example.evstation.loyalty.domain.PointSource;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class SwapSessionService {

    private final SwapSessionJpaRepository swapSessionRepository;
    private final BatterySwapReservationJpaRepository reservationRepository;
    private final SwapPaymentJpaRepository paymentRepository;
    private final BatterySlotJpaRepository batterySlotRepository;
    private final ChargingSessionJpaRepository chargingSessionRepository;
    private final SwapPileJpaRepository swapPileRepository;
    private final BatterySwapStationStateJpaRepository stationStateRepository;
    private final ChargingSessionService chargingSessionService;
    private final Clock clock;
    private final BatteryEventService batteryEventService;
    private final BatterySwapBroadcastService broadcastService;
    private final LoyaltyPointService loyaltyPointService;
    private final RatingEligibilityService ratingEligibilityService;
    private final BadgeService badgeService;

    @Value("${voltgo.battery-swap.charge-duration-minutes:60}")
    private int chargeDurationMinutes;

    /**
     * EV User verifies swap code and confirms swap completion.
     */
    @Transactional
    public SwapSessionDTO confirmSwapCompletion(UUID reservationId, UUID userId, String swapCode) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Reservation not found"));

        SwapSessionEntity session = swapSessionRepository.findByReservationId(reservationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Swap session not found"));

        Instant now = Instant.now(clock);

        if (session.getStatus() == SwapSessionStatus.COMPLETED) {
            return toSessionDto(session);
        }

        if (session.getStatus() == SwapSessionStatus.EXPIRED ||
                session.getStatus() == SwapSessionStatus.CANCELLED) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Swap session is " + session.getStatus().name() + ". Cannot complete.");
        }

        if (!session.getSwapCode().equals(swapCode)) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Invalid swap code");
        }

        if (now.isAfter(session.getExpiresAt())) {
            session.setStatus(SwapSessionStatus.EXPIRED);
            swapSessionRepository.save(session);
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Swap code has expired. Cannot complete.");
        }

        completeSwap(reservation, session, userId);

        return toSessionDto(session);
    }

    /**
     * Returns the charging session for a slot (used by EV user to track progress).
     */
    @Transactional(readOnly = true)
    public ChargingSessionDTO getSlotChargingSession(UUID slotId) {
        ChargingSessionEntity session = chargingSessionRepository
                .findByBatterySlotIdAndStatus(slotId, ChargingSessionStatus.CHARGING)
                .orElse(null);

        if (session == null) {
            return null;
        }

        return ChargingSessionDTO.builder()
                .sessionId(session.getId())
                .batterySlotId(session.getBatterySlotId())
                .startPercent(session.getStartPercent())
                .endPercent(session.getEndPercent())
                .status(session.getStatus().name())
                .startedAt(session.getStartedAt())
                .estimatedFullAt(session.getEstimatedFullAt())
                .completedAt(session.getCompletedAt())
                .build();
    }

    private void completeSwap(BatterySwapReservationEntity reservation,
                              SwapSessionEntity session, UUID actorId) {
        Instant now = Instant.now(clock);

        BatterySlotEntity slot = batterySlotRepository.findById(reservation.getSlotId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Slot not found"));

        int userBatteryPercent = reservation.getRequestedBatteryPercent() != null
                ? reservation.getRequestedBatteryPercent() : 0;

        slot.setStatus(BatterySlotStatus.SWAPPED_OUT);
        slot.setBatteryChargePercent(userBatteryPercent);
        slot.setChargingStartedAt(now);
        int chargeMinutesNeeded = (int) Math.ceil((100 - userBatteryPercent) * chargeDurationMinutes / 100.0);
        Instant estimatedFullAt = now.plus(chargeMinutesNeeded, ChronoUnit.MINUTES);
        slot.setEstimatedFullAt(estimatedFullAt);
        slot.setUpdatedAt(now);
        batterySlotRepository.save(slot);

        chargingSessionService.startCharging(slot.getId(), userBatteryPercent, actorId, "USER");

        reservation.setStatus(BatterySwapStatus.COMPLETED);
        reservation.setCompletedAt(now);
        reservation.setUpdatedAt(now);
        reservationRepository.save(reservation);

        session.setStatus(SwapSessionStatus.COMPLETED);
        session.setCompletedAt(now);
        swapSessionRepository.save(session);

        broadcastService.broadcastSwapCompleted(reservation.getStationId(), slot.getId(), "COMPLETED");
        broadcastService.broadcastSlotUpdate(reservation.getStationId(), slot);

        batterySwapServiceSyncAvailable(reservation.getStationId());

        // Loyalty: award points for completed battery swap
        loyaltyPointService.earnPoints(reservation.getUserId(), PointSource.BATTERY_SWAP, reservation.getId(),
                String.format("Completed battery swap at station %s", reservation.getStationId()));
        loyaltyPointService.incrementSwapCount(reservation.getUserId());
        badgeService.checkAndAwardBadges(reservation.getUserId(), BadgeCriteriaType.FIRST_SWAP, 1);
        var profile = loyaltyPointService.getProfile(reservation.getUserId());
        profile.ifPresent(p -> badgeService.checkAndAwardBadges(reservation.getUserId(), BadgeCriteriaType.SWAP_COUNT, p.getTotalSwaps()));

        // Loyalty: mark station as eligible for rating
        ratingEligibilityService.markEligible(
                reservation.getUserId(), reservation.getStationId(), reservation.getId(),
                EligibilityType.SWAP_USAGE, Instant.now(clock));

        log.info("[SwapSession] Swap completed for reservation={}, slot={}, newChargingPercent={}%",
                reservation.getId(), slot.getId(), userBatteryPercent);
    }

    private void batterySwapServiceSyncAvailable(UUID stationId) {
        long availableCount = batterySlotRepository
                .countByStationIdAndStatus(stationId, BatterySlotStatus.AVAILABLE);
        stationStateRepository.syncAvailableBatteries(stationId, (int) availableCount, Instant.now(clock));
    }

    private SwapSessionDTO toSessionDto(SwapSessionEntity session) {
        return SwapSessionDTO.builder()
                .sessionId(session.getId())
                .reservationId(session.getReservationId())
                .swapCode(session.getSwapCode())
                .status(session.getStatus().name())
                .expiresAt(session.getExpiresAt())
                .startedAt(session.getStartedAt())
                .completedAt(session.getCompletedAt())
                .build();
    }
}
