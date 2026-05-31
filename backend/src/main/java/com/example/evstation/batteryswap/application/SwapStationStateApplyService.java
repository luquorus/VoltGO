package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import com.example.evstation.batteryswap.domain.SwapPileStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapStationStateEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapStationStateJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileJpaRepository;
import com.example.evstation.station.domain.ServiceType;
import com.example.evstation.station.infrastructure.jpa.StationServiceEntity;
import com.example.evstation.station.infrastructure.jpa.StationServiceJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Áp cấu hình BATTERY_SWAP từ station_service (theo version vừa publish)
 * vào battery_swap_station_state — analog của ChargerUnitCreationService cho charging.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SwapStationStateApplyService {

    private static final int SLOTS_PER_PILE = 6;

    private final BatterySwapStationStateJpaRepository stationStateRepository;
    private final StationServiceJpaRepository stationServiceRepository;
    private final SwapPileJpaRepository swapPileRepository;
    private final BatterySlotJpaRepository batterySlotRepository;

    /**
     * Áp cấu hình swap (totalBatteries, avgChargePowerKw) từ services của một version
     * vào battery_swap_station_state. Gọi khi version chuyển sang PUBLISHED.
     *
     * Nếu version không có service BATTERY_SWAP nào: giữ nguyên (không xoá state cũ
     * vì có thể đang phục vụ; admin có thể cần xử lý thủ công nếu thay đổi loại trạm).
     */
    @Transactional
    public void applyForVersion(StationVersionEntity stationVersion) {
        var stationId = stationVersion.getStationId();
        List<StationServiceEntity> services = stationServiceRepository
                .findByStationVersionId(stationVersion.getId());

        Optional<StationServiceEntity> swapService = services.stream()
                .filter(s -> s.getServiceType() == ServiceType.BATTERY_SWAP)
                .findFirst();

        if (swapService.isEmpty()) {
            log.debug("Version {} has no BATTERY_SWAP service, skip state apply", stationVersion.getId());
            return;
        }

        StationServiceEntity service = swapService.get();
        Integer total = service.getTotalBatteries();
        BigDecimal avgPower = service.getAvgChargePowerKw();
        if (total == null || total <= 0 || avgPower == null || avgPower.signum() <= 0) {
            log.warn("Swap service {} on version {} has invalid config (total={}, avgPower={}); skip apply",
                    service.getId(), stationVersion.getId(), total, avgPower);
            return;
        }

        Optional<BatterySwapStationStateEntity> existing = stationStateRepository.findById(stationId);
        Instant now = Instant.now();
        if (existing.isEmpty()) {
            BatterySwapStationStateEntity state = BatterySwapStationStateEntity.builder()
                    .stationId(stationId)
                    .totalBatteries(total)
                    .availableBatteries(0) // all slots start in CHARGING, not available
                    .avgChargePowerKw(avgPower)
                    .updatedAt(now)
                    .build();
            stationStateRepository.save(state);
            log.info("Created battery_swap_station_state for station={} (total={}, available={}, avgPower={})",
                    stationId, total, state.getAvailableBatteries(), avgPower);
        } else {
            BatterySwapStationStateEntity state = existing.get();
            state.setTotalBatteries(total);
            state.setAvgChargePowerKw(avgPower);
            if (state.getAvailableBatteries() > total) {
                state.setAvailableBatteries(total);
            }
            state.setUpdatedAt(now);
            stationStateRepository.save(state);
            log.info("Updated battery_swap_station_state for station={} (total={}, available={}, avgPower={})",
                    stationId, total, state.getAvailableBatteries(), avgPower);
        }

        // Create swap piles and slots based on totalBatteries
        // totalBatteries defines total slots; we create piles of 6 slots each
        int numPiles = (int) Math.ceil((double) total / SLOTS_PER_PILE);
        List<SwapPileEntity> existingPiles = swapPileRepository.findByStationIdOrderByPileIndexAsc(stationId);
        int existingPileCount = existingPiles.size();

        if (existingPileCount == 0) {
            // First time publishing: create piles and slots
            for (int i = 0; i < numPiles; i++) {
                SwapPileEntity pile = SwapPileEntity.builder()
                        .stationId(stationId)
                        .pileIndex(i + 1)
                        .status(SwapPileStatus.ACTIVE)
                        .createdAt(now)
                        .updatedAt(now)
                        .slots(new ArrayList<>())
                        .build();

                int slotsInThisPile = Math.min(SLOTS_PER_PILE, total - (i * SLOTS_PER_PILE));
                for (int j = 0; j < slotsInThisPile; j++) {
                    BatterySlotEntity slot = BatterySlotEntity.builder()
                            .slotIndex(j)
                            .batteryChargePercent(0)   // starts empty, needs charging
                            .status(BatterySlotStatus.CHARGING)
                            .chargingStartedAt(now)     // begins charging immediately
                            .updatedAt(now)
                            .build();
                    pile.addSlot(slot);
                }
                swapPileRepository.save(pile);
            }
            log.info("Created {} swap piles for station={}", numPiles, stationId);
        }
    }
}
