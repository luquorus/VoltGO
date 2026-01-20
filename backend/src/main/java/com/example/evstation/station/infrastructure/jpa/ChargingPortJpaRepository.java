package com.example.evstation.station.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ChargingPortJpaRepository extends JpaRepository<ChargingPortEntity, UUID> {
    
    // Find charging ports by station service IDs
    @Query("""
        SELECT cp FROM ChargingPortEntity cp
        WHERE cp.stationServiceId IN :serviceIds
        ORDER BY cp.powerType, cp.powerKw DESC NULLS LAST
        """)
    List<ChargingPortEntity> findByStationServiceIds(@Param("serviceIds") List<UUID> serviceIds);

    // Find charging ports by station version ID (through station_service)
    @Query("""
        SELECT cp FROM ChargingPortEntity cp
        JOIN StationServiceEntity ss ON cp.stationServiceId = ss.id
        WHERE ss.stationVersionId = :stationVersionId
        ORDER BY cp.powerType, cp.powerKw DESC NULLS LAST
        """)
    List<ChargingPortEntity> findByStationVersionId(@Param("stationVersionId") UUID stationVersionId);
    
    // Find charging ports by station service ID
    List<ChargingPortEntity> findByStationServiceId(UUID stationServiceId);
}

