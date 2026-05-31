package com.example.evstation.batteryswap.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StationDeviceJpaRepository extends JpaRepository<StationDeviceEntity, UUID> {

    Optional<StationDeviceEntity> findByDeviceKey(String deviceKey);

    boolean existsByDeviceKey(String deviceKey);

    @Modifying
    @Query("UPDATE StationDeviceEntity d SET d.lastSeenAt = :now WHERE d.stationId = :stationId")
    int touchLastSeen(@Param("stationId") UUID stationId, @Param("now") Instant now);
}
