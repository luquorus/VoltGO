package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.ServiceType;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StationJpaRepository extends JpaRepository<StationEntity, UUID> {
    List<StationEntity> findByProviderId(UUID providerId);
    
    /**
     * Find station by ID with pessimistic write lock.
     * This ensures serialization of publish operations for the same station,
     * preventing concurrent publish that could violate unique constraint.
     * 
     * Lock is acquired even if no published version exists to ensure
     * atomic publish operation and prevent race conditions.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM StationEntity s WHERE s.id = :id")
    Optional<StationEntity> findByIdForUpdate(@Param("id") UUID id);
    
    /**
     * Find all stations that have a published version with a specific service type.
     * Joins through StationVersion and StationService to filter correctly.
     */
    @Query("""
        SELECT DISTINCT s FROM StationEntity s
        JOIN StationVersionEntity sv ON sv.stationId = s.id AND sv.workflowStatus = 'PUBLISHED'
        JOIN StationServiceEntity ss ON ss.stationVersionId = sv.id
        WHERE ss.serviceType = :serviceType
        """)
    Page<StationEntity> findByServiceType(@Param("serviceType") ServiceType serviceType, Pageable pageable);
}

