package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import com.example.evstation.batteryswap.domain.ChargingSessionStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.*;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChargingSessionService {

    private final ChargingSessionJpaRepository chargingSessionRepository;
    private final BatterySlotJpaRepository batterySlotRepository;
    private final SwapPileJpaRepository swapPileRepository;
    private final BatterySwapStationStateJpaRepository stationStateRepository;
    private final BatteryEventService batteryEventService;
    private final BatterySwapBroadcastService broadcastService;
    private final Clock clock;

    @Value("${voltgo.battery-swap.charge-duration-minutes:60}")
    private int chargeDurationMinutes;

    @Transactional
    public ChargingSessionEntity startCharging(UUID slotId, int startPercent, UUID actorId, String actorType) {
        BatterySlotEntity slot = batterySlotRepository.findById(slotId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Slot not found"));

        if (slot.getStatus() != BatterySlotStatus.SWAPPED_OUT &&
                slot.getStatus() != BatterySlotStatus.OCCUPIED) {
            throw new BusinessException(ErrorCode.INVALID_STATE,
                    "Cannot start charging on slot with status: " + slot.getStatus());
        }

        Instant now = Instant.now(clock);
        int chargeMinutesNeeded = (int) Math.ceil((100 - startPercent) * chargeDurationMinutes / 100.0);
        Instant estimatedFullAt = now.plus(chargeMinutesNeeded, ChronoUnit.MINUTES);

        BigDecimal startKwh = slot.getBatteryCapacityKwh() != null
                ? slot.getBatteryCapacityKwh().multiply(BigDecimal.valueOf(startPercent / 100.0))
                : BigDecimal.valueOf(60.0 * startPercent / 100.0);

        ChargingSessionEntity session = ChargingSessionEntity.builder()
                .batterySlotId(slotId)
                .startPercent(startPercent)
                .startKwh(startKwh)
                .status(ChargingSessionStatus.CHARGING)
                .startedAt(now)
                .estimatedFullAt(estimatedFullAt)
                .build();

        session = chargingSessionRepository.save(session);

        slot.setStatus(BatterySlotStatus.CHARGING);
        slot.setBatteryChargePercent(startPercent);
        slot.setChargingStartedAt(now);
        slot.setEstimatedFullAt(estimatedFullAt);
        slot.setUpdatedAt(now);
        batterySlotRepository.save(slot);

        batteryEventService.recordChargingStarted(slotId, startPercent, estimatedFullAt, actorId, actorType);

        UUID stationId = swapPileRepository.findById(slot.getPileId())
                .map(SwapPileEntity::getStationId).orElse(null);
        if (stationId != null) {
            syncAvailableBatteries(stationId, now);
            broadcastService.broadcastSlotUpdate(stationId, slot);
        }

        log.info("[ChargingSession] Started charging slot={}, startPercent={}%, estimatedFullAt={}",
                slotId, startPercent, estimatedFullAt);
        return session;
    }

    @Transactional
    public void updateChargingProgress(UUID slotId, int newPercent, Instant now) {
        BatterySlotEntity slot = batterySlotRepository.findById(slotId).orElse(null);
        if (slot == null) return;

        slot.setBatteryChargePercent(newPercent);
        slot.setUpdatedAt(now);
        batterySlotRepository.save(slot);

        Optional<ChargingSessionEntity> sessionOpt = chargingSessionRepository
                .findByBatterySlotIdAndStatus(slotId, ChargingSessionStatus.CHARGING);

        UUID stationId = swapPileRepository.findById(slot.getPileId())
                .map(SwapPileEntity::getStationId).orElse(null);
        if (stationId != null) {
            broadcastService.broadcastSlotUpdate(stationId, slot);
        }
    }

    @Transactional
    public void completeCharging(UUID slotId, UUID actorId, String actorType) {
        BatterySlotEntity slot = batterySlotRepository.findById(slotId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Slot not found"));

        Instant now = Instant.now(clock);

        Optional<ChargingSessionEntity> sessionOpt = chargingSessionRepository
                .findByBatterySlotIdAndStatus(slotId, ChargingSessionStatus.CHARGING);

        ChargingSessionEntity session = sessionOpt.orElse(null);
        if (session != null) {
            session.setStatus(ChargingSessionStatus.COMPLETED);
            session.setEndPercent(100);
            session.setCompletedAt(now);
            chargingSessionRepository.save(session);
        }

        slot.setStatus(BatterySlotStatus.AVAILABLE);
        slot.setBatteryChargePercent(100);
        slot.setChargingStartedAt(null);
        slot.setEstimatedFullAt(null);
        slot.setUpdatedAt(now);
        batterySlotRepository.save(slot);

        batteryEventService.recordFullyCharged(slotId, 100, actorId, actorType);

        UUID stationId = swapPileRepository.findById(slot.getPileId())
                .map(SwapPileEntity::getStationId).orElse(null);
        if (stationId != null) {
            syncAvailableBatteries(stationId, now);
            broadcastService.broadcastSlotUpdate(stationId, slot);
        }

        log.info("[ChargingSession] Completed charging slot={}", slotId);
    }

    @Transactional
    public void cancelCharging(UUID slotId, UUID actorId, String actorType) {
        BatterySlotEntity slot = batterySlotRepository.findById(slotId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Slot not found"));

        Instant now = Instant.now(clock);

        chargingSessionRepository.findByBatterySlotIdAndStatus(slotId, ChargingSessionStatus.CHARGING)
                .ifPresent(session -> {
                    session.setStatus(ChargingSessionStatus.CANCELLED);
                    session.setCompletedAt(now);
                    chargingSessionRepository.save(session);
                });

        slot.setStatus(BatterySlotStatus.AVAILABLE);
        slot.setChargingStartedAt(null);
        slot.setEstimatedFullAt(null);
        slot.setUpdatedAt(now);
        batterySlotRepository.save(slot);

        UUID stationId = swapPileRepository.findById(slot.getPileId())
                .map(SwapPileEntity::getStationId).orElse(null);
        if (stationId != null) {
            syncAvailableBatteries(stationId, now);
            broadcastService.broadcastSlotUpdate(stationId, slot);
        }

        log.info("[ChargingSession] Cancelled charging for slot={}", slotId);
    }

    @Transactional(readOnly = true)
    public List<ChargingSessionEntity> getActiveChargingSessions() {
        return chargingSessionRepository.findAllActiveChargingSessions();
    }

    @Transactional(readOnly = true)
    public Optional<ChargingSessionEntity> getChargingSession(UUID slotId) {
        return chargingSessionRepository.findByBatterySlotIdAndStatus(slotId, ChargingSessionStatus.CHARGING);
    }

    private void syncAvailableBatteries(UUID stationId, Instant now) {
        try {
            long availableCount = batterySlotRepository
                    .countByStationIdAndStatus(stationId, BatterySlotStatus.AVAILABLE);
            stationStateRepository.syncAvailableBatteries(stationId, (int) availableCount, now);
        } catch (Exception e) {
            log.warn("[ChargingSession] syncAvailableBatteries failed for stationId={}: {}",
                    stationId, e.getMessage());
        }
    }
}
