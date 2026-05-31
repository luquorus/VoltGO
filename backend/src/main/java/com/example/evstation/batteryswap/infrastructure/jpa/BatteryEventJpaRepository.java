package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.BatteryEventType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface BatteryEventJpaRepository extends JpaRepository<BatteryEventEntity, UUID> {

    List<BatteryEventEntity> findByBatterySlotIdOrderByCreatedAtDesc(UUID batterySlotId);

    Page<BatteryEventEntity> findByBatterySlotIdOrderByCreatedAtDesc(UUID batterySlotId, Pageable pageable);

    List<BatteryEventEntity> findByBatterySlotIdAndEventTypeOrderByCreatedAtDesc(UUID batterySlotId, BatteryEventType eventType);

    List<BatteryEventEntity> findByCreatedAtBetweenOrderByCreatedAtDesc(Instant from, Instant to);

    List<BatteryEventEntity> findByBatterySlotIdAndCreatedAtBetweenOrderByCreatedAtDesc(
            UUID batterySlotId, Instant from, Instant to);
}
