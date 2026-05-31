package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.ChargingSessionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ChargingSessionJpaRepository extends JpaRepository<ChargingSessionEntity, UUID> {

    Optional<ChargingSessionEntity> findByBatterySlotIdAndStatus(UUID batterySlotId, ChargingSessionStatus status);

    List<ChargingSessionEntity> findByBatterySlotIdOrderByStartedAtDesc(UUID batterySlotId);

    @Query("SELECT s FROM ChargingSessionEntity s WHERE s.status = 'CHARGING'")
    List<ChargingSessionEntity> findAllActiveChargingSessions();

    @Query("SELECT s FROM ChargingSessionEntity s WHERE s.status = 'CHARGING' AND s.estimatedFullAt IS NOT NULL AND s.estimatedFullAt <= :now")
    List<ChargingSessionEntity> findCompletedChargingSessions(@Param("now") Instant now);

    @Modifying
    @Query("UPDATE ChargingSessionEntity s SET s.status = :status, s.endPercent = 100, s.endKwh = s.startKwh, s.completedAt = :completedAt WHERE s.id = :id AND s.status = 'CHARGING'")
    int markCompleted(@Param("id") UUID id, @Param("status") ChargingSessionStatus status, @Param("completedAt") Instant completedAt);

    @Modifying
    @Query("UPDATE ChargingSessionEntity s SET s.status = 'CANCELLED', s.completedAt = :completedAt WHERE s.batterySlotId = :slotId AND s.status = 'CHARGING'")
    int cancelBySlotId(@Param("slotId") UUID slotId, @Param("completedAt") Instant completedAt);
}
