package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.WorkflowStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface StationVersionJpaRepository extends JpaRepository<StationVersionEntity, UUID> {
    
    // Find published version by station ID
    Optional<StationVersionEntity> findByStationIdAndWorkflowStatus(
            UUID stationId, 
            WorkflowStatus workflowStatus
    );

    // Geo search: Find published stations within radius using PostGIS ST_DWithin
    @Query(value = """
        SELECT sv.* FROM station_version sv
        WHERE sv.workflow_status = 'PUBLISHED'
        AND ST_DWithin(
            sv.location::geography,
            ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
            :radiusMeters
        )
        """, nativeQuery = true)
    Page<StationVersionEntity> findPublishedStationsWithinRadius(
            @Param("lat") double lat,
            @Param("lng") double lng,
            @Param("radiusMeters") double radiusMeters,
            Pageable pageable
    );

    // Find published version by station ID with charging ports
    @Query("""
        SELECT sv FROM StationVersionEntity sv
        WHERE sv.stationId = :stationId
        AND sv.workflowStatus = 'PUBLISHED'
        """)
    Optional<StationVersionEntity> findPublishedByStationId(@Param("stationId") UUID stationId);
}

