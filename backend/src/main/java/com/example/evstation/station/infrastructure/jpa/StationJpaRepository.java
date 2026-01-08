package com.example.evstation.station.infrastructure.jpa;

import jakarta.persistence.LockModeType;
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
}

