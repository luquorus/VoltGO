package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.domain.BatteryEventType;
import com.example.evstation.batteryswap.infrastructure.jpa.BatteryEventEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatteryEventJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class BatteryEventService {

    private final BatteryEventJpaRepository batteryEventRepository;

    @Transactional
    public void recordEvent(UUID slotId, BatteryEventType eventType,
                            String oldState, String newState,
                            Integer oldPercent, Integer newPercent,
                            Map<String, Object> metadata,
                            UUID actorId, String actorType) {
        BatteryEventEntity event = BatteryEventEntity.builder()
                .batterySlotId(slotId)
                .eventType(eventType)
                .oldState(oldState)
                .newState(newState)
                .oldPercent(oldPercent)
                .newPercent(newPercent)
                .metadata(metadata)
                .createdAt(Instant.now())
                .createdBy(actorId)
                .actorType(actorType)
                .build();
        batteryEventRepository.save(event);
        log.debug("[Event] slotId={} event={} actor={}", slotId, eventType, actorType);
    }

    @Transactional
    public void recordSlotInsertion(UUID slotId, UUID batteryId, String batterySerial,
                                   int batteryPercent, UUID actorId, String actorType) {
        recordEvent(slotId, BatteryEventType.BATTERY_INSERTED,
                null, "OCCUPIED",
                null, batteryPercent,
                Map.of("batteryId", batteryId.toString(),
                        "batterySerial", batterySerial != null ? batterySerial : "",
                        "batteryPercent", batteryPercent),
                actorId, actorType);
    }

    @Transactional
    public void recordSlotRemoval(UUID slotId, UUID batteryId, int batteryPercent,
                                 String batterySerial, UUID actorId, String actorType) {
        recordEvent(slotId, BatteryEventType.BATTERY_REMOVED,
                "OCCUPIED", "AVAILABLE",
                batteryPercent, 0,
                Map.of("batteryId", batteryId != null ? batteryId.toString() : "null",
                        "batterySerial", batterySerial != null ? batterySerial : ""),
                actorId, actorType);
    }

    @Transactional
    public void recordChargingStarted(UUID slotId, int startPercent, Instant estimatedFullAt,
                                     UUID actorId, String actorType) {
        recordEvent(slotId, BatteryEventType.CHARGING_STARTED,
                null, "CHARGING",
                0, startPercent,
                Map.of("estimatedFullAt", estimatedFullAt.toString(),
                        "startPercent", startPercent),
                actorId, actorType);
    }

    @Transactional
    public void recordFullyCharged(UUID slotId, int finalPercent,
                                  UUID actorId, String actorType) {
        recordEvent(slotId, BatteryEventType.FULLY_CHARGED,
                "CHARGING", "AVAILABLE",
                finalPercent - 1, finalPercent,
                Map.of("finalPercent", finalPercent),
                actorId, actorType);
    }

    @Transactional
    public void recordStatusChange(UUID slotId, String oldStatus, String newStatus,
                                  UUID actorId, String actorType) {
        recordEvent(slotId, BatteryEventType.STATUS_CHANGED,
                oldStatus, newStatus,
                null, null,
                Map.of(),
                actorId, actorType);
    }

    public List<BatteryEventEntity> getSlotHistory(UUID slotId, int limit) {
        return batteryEventRepository.findByBatterySlotIdOrderByCreatedAtDesc(slotId)
                .stream().limit(limit).toList();
    }
}
