package com.example.evstation.station.infrastructure.jpa;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface AuditLogJpaRepository extends JpaRepository<AuditLogEntity, UUID> {
    
    List<AuditLogEntity> findByEntityTypeAndEntityIdOrderByCreatedAtDesc(String entityType, UUID entityId);
    
    Page<AuditLogEntity> findByActorIdOrderByCreatedAtDesc(UUID actorId, Pageable pageable);
    
    Page<AuditLogEntity> findByActionOrderByCreatedAtDesc(String action, Pageable pageable);
    
    Page<AuditLogEntity> findByEntityTypeOrderByCreatedAtDesc(String entityType, Pageable pageable);
    
    Page<AuditLogEntity> findByEntityTypeAndEntityIdOrderByCreatedAtDesc(
            String entityType, UUID entityId, Pageable pageable);
    
    Page<AuditLogEntity> findAllByOrderByCreatedAtDesc(Pageable pageable);
    
    @Query("""
        SELECT a FROM AuditLogEntity a 
        WHERE (:entityType IS NULL OR a.entityType = :entityType)
        AND (:entityId IS NULL OR a.entityId = :entityId)
        AND (:from IS NULL OR a.createdAt >= :from)
        AND (:to IS NULL OR a.createdAt <= :to)
        ORDER BY a.createdAt DESC
        """)
    Page<AuditLogEntity> findWithFilters(
            @Param("entityType") String entityType,
            @Param("entityId") UUID entityId,
            @Param("from") Instant from,
            @Param("to") Instant to,
            Pageable pageable);
    
    // Find audit logs related to a station (including its versions and change requests)
    @Query(value = """
        SELECT a.* FROM audit_log a 
        WHERE (a.entity_type = 'STATION' AND a.entity_id = :stationId)
        OR (a.entity_type = 'STATION_VERSION' AND a.entity_id IN (
            SELECT sv.id FROM station_version sv WHERE sv.station_id = :stationId
        ))
        OR (a.entity_type = 'CHANGE_REQUEST' AND a.entity_id IN (
            SELECT cr.id FROM change_request cr 
            WHERE cr.station_id = :stationId 
            OR cr.proposed_station_version_id IN (
                SELECT sv.id FROM station_version sv WHERE sv.station_id = :stationId
            )
        ))
        ORDER BY a.created_at DESC
        """, nativeQuery = true)
    List<AuditLogEntity> findByStationId(@Param("stationId") UUID stationId);
}

