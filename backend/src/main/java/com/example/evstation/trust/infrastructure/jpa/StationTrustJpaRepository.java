package com.example.evstation.trust.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface StationTrustJpaRepository extends JpaRepository<StationTrustEntity, UUID> {
    List<StationTrustEntity> findAll();
    
    /**
     * Find all trust records for stations that have a specific service type.
     * Joins through StationVersion and StationService to filter correctly.
     * Only returns trust for CHARGING stations (trust is not tracked for BATTERY_SWAP).
     */
    @Query("""
        SELECT st FROM StationTrustEntity st
        JOIN StationVersionEntity sv ON sv.stationId = st.stationId AND sv.workflowStatus = 'PUBLISHED'
        JOIN StationServiceEntity ss ON ss.stationVersionId = sv.id
        WHERE ss.serviceType = 'CHARGING'
        """)
    List<StationTrustEntity> findAllForChargingStations();
}

