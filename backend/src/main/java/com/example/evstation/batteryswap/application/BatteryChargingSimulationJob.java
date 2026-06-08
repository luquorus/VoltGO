package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapStationStateJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapStationStateEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Simulation job that auto-charges battery slots from 0% to 100%.
 * Runs every N seconds (configurable via voltgo.battery-swap.charge-simulation-interval-ms).
 * For each CHARGING or SWAPPED_OUT slot, calculates current charge % based on elapsed time
 * and charge power, then flips to AVAILABLE when it reaches 100%.
 * Finally syncs availableBatteries counters on station state.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BatteryChargingSimulationJob {

    private static final int FULLY_CHARGED_PERCENT = 100;

    private final BatterySlotJpaRepository slotRepository;
    private final SwapPileJpaRepository pileRepository;
    private final BatterySwapStationStateJpaRepository stateRepository;

    @Value("${voltgo.battery-swap.charge-simulation-interval-ms:30000}")
    private long simulationIntervalMs;

    @Value("${voltgo.battery-swap.default-charge-duration-minutes:30}")
    private int defaultChargeDurationMinutes;

    @Scheduled(fixedDelayString = "${voltgo.battery-swap.charge-simulation-interval-ms:30000}")
    public void run() {
        try {
            simulateChargingCycle();
        } catch (Exception e) {
            log.error("BatteryChargingSimulationJob failed", e);
        }
    }

    @Transactional
    public void simulateChargingCycle() {
        Instant now = Instant.now();
        List<BatterySlotStatus> activeStatuses = List.of(
                BatterySlotStatus.CHARGING,
                BatterySlotStatus.SWAPPED_OUT
        );

        List<BatterySlotEntity> activeSlots = slotRepository.findByChargingStatuses(activeStatuses);

        if (activeSlots.isEmpty()) {
            return;
        }

        log.debug("BatteryChargingSimulationJob: found {} active charging slots", activeSlots.size());

        // Collect all pile IDs to look up their avg charge power
        List<UUID> pileIds = activeSlots.stream()
                .map(BatterySlotEntity::getPileId)
                .distinct()
                .toList();

        List<SwapPileEntity> piles = pileRepository.findAllById(pileIds);
        Map<UUID, UUID> pileStationMap = piles.stream()
                .collect(Collectors.toMap(SwapPileEntity::getId, SwapPileEntity::getStationId));

        // Group slots by station to look up station state once per station
        Map<UUID, List<BatterySlotEntity>> slotsByStation = activeSlots.stream()
                .collect(Collectors.groupingBy(slot -> pileStationMap.getOrDefault(slot.getPileId(), slot.getPileId())));

        int fullyChargedCount = 0;

        for (BatterySlotEntity slot : activeSlots) {
            if (slot.getChargingStartedAt() == null) {
                slot.setChargingStartedAt(now);
            }

            // Get charge power from station state
            UUID stationId = pileStationMap.getOrDefault(slot.getPileId(), slot.getPileId());
            var stateOpt = stateRepository.findById(stationId);
            BigDecimal chargePowerKw = stateOpt
                    .map(BatterySwapStationStateEntity::getAvgChargePowerKw)
                    .filter(p -> p != null)
                    .orElse(new BigDecimal("7.0"));

            // Calculate charge time based on actual power and capacity
            BigDecimal batteryCapacityKwh = slot.getBatteryCapacityKwh() != null
                    ? slot.getBatteryCapacityKwh()
                    : new BigDecimal("60.0");

            // hours to full = capacity (kWh) / power (kW)
            double hoursToFull = batteryCapacityKwh.divide(chargePowerKw, 4, RoundingMode.HALF_UP).doubleValue();
            double minutesToFull = hoursToFull * 60.0;

            // Elapsed time since charging started
            Duration elapsed = Duration.between(slot.getChargingStartedAt(), now);
            double elapsedMinutes = elapsed.isNegative() ? 0 : elapsed.toMinutes();

            // % charged = min(elapsed / minutesToFull, 1.0) * 100
            double percentCharged = minutesToFull > 0
                    ? Math.min(elapsedMinutes / minutesToFull * 100.0, FULLY_CHARGED_PERCENT)
                    : FULLY_CHARGED_PERCENT;

            int newPercent = BigDecimal.valueOf(percentCharged)
                    .setScale(0, RoundingMode.HALF_UP)
                    .intValue();

            // Clamp
            newPercent = Math.max(0, Math.min(FULLY_CHARGED_PERCENT, newPercent));
            slot.setBatteryChargePercent(newPercent);
            slot.setUpdatedAt(now);

            if (newPercent >= FULLY_CHARGED_PERCENT) {
                slot.setStatus(BatterySlotStatus.AVAILABLE);
                slot.setEstimatedFullAt(null);
                fullyChargedCount++;
                log.debug("Slot {} fully charged -> AVAILABLE", slot.getId());
            }
        }

        // Bulk save all updated slots
        slotRepository.saveAll(activeSlots);

        // Sync availableBatteries for all affected stations
        if (fullyChargedCount > 0) {
            for (UUID stationId : slotsByStation.keySet()) {
                long availableCount = slotRepository.countByStationIdAndStatus(
                        stationId, BatterySlotStatus.AVAILABLE);
                stateRepository.syncAvailableBatteries(stationId, (int) availableCount, now);
                log.debug("Synced availableBatteries={} for station {}", availableCount, stationId);
            }
        }

        log.info("BatteryChargingSimulationJob: processed {} slots, {} newly fully charged",
                activeSlots.size(), fullyChargedCount);
    }
}
