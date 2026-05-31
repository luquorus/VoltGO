package com.example.evstation.batteryswap.application;

import com.example.evstation.api.ev_user_mobile.dto.SwapCodeDTO;
import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import com.example.evstation.batteryswap.domain.BatterySwapStatus;
import com.example.evstation.batteryswap.domain.PaymentStatus;
import com.example.evstation.batteryswap.domain.SwapSessionStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapReservationEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapReservationJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapSessionEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapSessionJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class SwapCodeService {

    private static final int CODE_LENGTH = 4;
    private static final int CODE_VALID_MINUTES = 30;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final SwapSessionJpaRepository swapSessionRepository;
    private final BatterySwapReservationJpaRepository reservationRepository;
    private final BatterySlotJpaRepository batterySlotRepository;
    private final SwapPileJpaRepository swapPileRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final Clock clock;
    private final BatteryEventService batteryEventService;
    private final BatterySwapBroadcastService broadcastService;

    /**
     * Returns the active swap code for a reservation (for EV user).
     */
    @Transactional(readOnly = true)
    public SwapCodeDTO getSwapCode(UUID reservationId, UUID userId) {
        BatterySwapReservationEntity reservation = reservationRepository.findByIdAndUserId(reservationId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Reservation not found"));

        if (reservation.getSwapCode() == null || reservation.getSwapCode().isBlank()) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "No swap code generated yet");
        }

        String stationName = stationVersionRepository.findPublishedByStationId(reservation.getStationId())
                .map(s -> s.getName()).orElse(null);

        Integer pileIndex = reservation.getPileId() != null
                ? swapPileRepository.findById(reservation.getPileId())
                        .map(p -> p.getPileIndex()).orElse(null)
                : null;

        Integer slotIndex = reservation.getSlotId() != null
                ? batterySlotRepository.findById(reservation.getSlotId())
                        .map(s -> s.getSlotIndex()).orElse(null)
                : null;

        return SwapCodeDTO.builder()
                .reservationId(reservation.getId())
                .swapCode(reservation.getSwapCode())
                .expiresAt(reservation.getSwapDeadlineAt())
                .deadlineAt(reservation.getSwapDeadlineAt())
                .stationName(stationName)
                .pileIndex(pileIndex)
                .slotIndex(slotIndex)
                .build();
    }

    /**
     * Generate swap code without broadcasting. Returns code + expiry.
     * Used internally by BatterySwapService when user starts a swap.
     */
    @Transactional
    public SwapCodeResult generateSwapCodeInternal(BatterySwapReservationEntity reservation) {
        validateForSwapCodeGeneration(reservation);

        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(CODE_VALID_MINUTES, ChronoUnit.MINUTES);
        String code = generateNumericCode();

        SwapSessionEntity session = SwapSessionEntity.builder()
                .reservationId(reservation.getId())
                .swapCode(code)
                .status(SwapSessionStatus.PENDING)
                .expiresAt(expiresAt)
                .createdAt(now)
                .createdBy(null)
                .build();
        swapSessionRepository.save(session);

        reservation.setSwapCode(code);
        reservation.setSwapDeadlineAt(expiresAt);
        reservation.setUpdatedAt(now);
        reservationRepository.save(reservation);

        return new SwapCodeResult(code, expiresAt);
    }

    private void validateForSwapCodeGeneration(BatterySwapReservationEntity reservation) {
        if (reservation.getStatus() != BatterySwapStatus.RESERVED) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Only RESERVED reservations can generate swap code. Current status: " + reservation.getStatus());
        }

        if (reservation.getPaymentStatus() != PaymentStatus.PAID) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Payment must be completed before generating swap code. Current status: " + reservation.getPaymentStatus());
        }

        if (reservation.getConfirmedArrivalAt() == null) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "User must confirm arrival before generating swap code");
        }

        Instant swapWindowEnd = reservation.getConfirmedArrivalAt().plus(15, ChronoUnit.MINUTES);
        if (Instant.now(clock).isAfter(swapWindowEnd)) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Swap window has expired. 15 minutes have passed since confirmation.");
        }

        Optional<SwapSessionEntity> existingSession = swapSessionRepository.findByReservationId(reservation.getId());
        if (existingSession.isPresent() && existingSession.get().getStatus() == SwapSessionStatus.PENDING) {
            return;
        }
    }

    /**
     * Expire sessions that have passed their deadline.
     */
    @Transactional
    public void expirePendingSessions() {
        Instant now = Instant.now(clock);
        List<SwapSessionEntity> expired = swapSessionRepository.findExpiredSessions(SwapSessionStatus.PENDING, now);
        for (SwapSessionEntity session : expired) {
            session.setStatus(SwapSessionStatus.EXPIRED);
            swapSessionRepository.save(session);

            reservationRepository.findById(session.getReservationId()).ifPresent(res -> {
                if (res.getStatus() == BatterySwapStatus.RESERVED) {
                    res.setStatus(BatterySwapStatus.EXPIRED);
                    res.setUpdatedAt(now);
                    res.setCancelledAt(now);
                    reservationRepository.save(res);

                    batterySlotRepository.updateStatus(
                            res.getSlotId(), BatterySlotStatus.RESERVED,
                            BatterySlotStatus.AVAILABLE, now);
                }
            });
            log.info("[SwapCode] Expired session {} for reservation {}", session.getId(), session.getReservationId());
        }
    }

    public record SwapCodeResult(String code, Instant expiresAt) {}

    private String generateNumericCode() {
        int code = RANDOM.nextInt((int) Math.pow(10, CODE_LENGTH));
        return String.format("%0" + CODE_LENGTH + "d", code);
    }
}
