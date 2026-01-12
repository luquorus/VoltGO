package com.example.evstation.booking.infrastructure.jpa;

import com.example.evstation.booking.domain.ChargerUnitStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ChargerUnitJpaRepository extends JpaRepository<ChargerUnitEntity, UUID> {
    
    /**
     * Find all active charger units for a station
     */
    List<ChargerUnitEntity> findByStationIdAndStatusOrderByLabel(UUID stationId, ChargerUnitStatus status);
    
    /**
     * Find all charger units for a station (any status)
     */
    List<ChargerUnitEntity> findByStationIdOrderByLabel(UUID stationId);
    
    /**
     * Find charger unit by ID and station ID (for authorization check)
     */
    Optional<ChargerUnitEntity> findByIdAndStationId(UUID id, UUID stationId);
    
    /**
     * Find charger units by station and power type
     */
    @Query("""
        SELECT cu FROM ChargerUnitEntity cu 
        WHERE cu.stationId = :stationId 
        AND cu.status = :status
        AND cu.powerType = :powerType
        AND (:minPowerKw IS NULL OR cu.powerKw >= :minPowerKw)
        ORDER BY cu.label
        """)
    List<ChargerUnitEntity> findByStationIdAndPowerType(
            @Param("stationId") UUID stationId,
            @Param("status") ChargerUnitStatus status,
            @Param("powerType") com.example.evstation.station.domain.PowerType powerType,
            @Param("minPowerKw") java.math.BigDecimal minPowerKw);
}

