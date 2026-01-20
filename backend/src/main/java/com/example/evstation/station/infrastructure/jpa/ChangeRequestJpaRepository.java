package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.ChangeRequestStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ChangeRequestJpaRepository extends JpaRepository<ChangeRequestEntity, UUID> {
    
    Page<ChangeRequestEntity> findBySubmittedByOrderByCreatedAtDesc(UUID submittedBy, Pageable pageable);
    
    List<ChangeRequestEntity> findBySubmittedByOrderByCreatedAtDesc(UUID submittedBy);
    
    List<ChangeRequestEntity> findByStationIdOrderByCreatedAtDesc(UUID stationId);
    
    List<ChangeRequestEntity> findByStatusOrderByCreatedAtDesc(ChangeRequestStatus status);
    
    Page<ChangeRequestEntity> findByStatusOrderByCreatedAtDesc(ChangeRequestStatus status, Pageable pageable);
    
    Page<ChangeRequestEntity> findAllByOrderByCreatedAtDesc(Pageable pageable);
    
    List<ChangeRequestEntity> findAllByOrderByCreatedAtDesc();
    
    boolean existsByProposedStationVersionId(UUID proposedStationVersionId);
}

