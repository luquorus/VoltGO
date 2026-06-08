package com.example.evstation.verification.infrastructure.jpa;

import com.example.evstation.verification.domain.VerificationTaskStatus;
import com.example.evstation.verification.domain.VerificationType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VerificationTaskJpaRepository extends JpaRepository<VerificationTaskEntity, UUID> {
    
    List<VerificationTaskEntity> findByStatusOrderByCreatedAtDesc(VerificationTaskStatus status);
    
    Page<VerificationTaskEntity> findByStatusOrderByCreatedAtDesc(VerificationTaskStatus status, Pageable pageable);
    
    List<VerificationTaskEntity> findByAssignedToOrderByCreatedAtDesc(UUID assignedTo);
    
    Page<VerificationTaskEntity> findByAssignedToOrderByCreatedAtDesc(UUID assignedTo, Pageable pageable);
    
    // For collaborator mobile: get tasks assigned to them with specific statuses
    @Query("""
        SELECT t FROM VerificationTaskEntity t 
        WHERE t.assignedTo = :assignedTo 
        AND t.status IN :statuses
        ORDER BY t.priority ASC, t.slaDueAt ASC NULLS LAST, t.createdAt DESC
        """)
    List<VerificationTaskEntity> findByAssignedToAndStatusIn(
            @Param("assignedTo") UUID assignedTo,
            @Param("statuses") List<VerificationTaskStatus> statuses);
    
    // For collaborator web: get all tasks ordered
    Page<VerificationTaskEntity> findByAssignedToOrderByPriorityAscSlaDueAtAscCreatedAtDesc(
            UUID assignedTo, Pageable pageable);
    
    // For collaborator web: filter by status only
    Page<VerificationTaskEntity> findByAssignedToAndStatusOrderByPriorityAscSlaDueAtAscCreatedAtDesc(
            UUID assignedTo, VerificationTaskStatus status, Pageable pageable);
    
    // For collaborator web: history (reviewed tasks)
    @Query("""
        SELECT t FROM VerificationTaskEntity t 
        WHERE t.assignedTo = :assignedTo 
        AND t.status = 'REVIEWED'
        ORDER BY t.createdAt DESC
        """)
    Page<VerificationTaskEntity> findReviewedByAssignedTo(@Param("assignedTo") UUID assignedTo, Pageable pageable);
    
    // Find task by change request ID
    Optional<VerificationTaskEntity> findByChangeRequestId(UUID changeRequestId);
    
    // Check if high-risk CR has passed verification
    @Query("""
        SELECT COUNT(t) > 0 FROM VerificationTaskEntity t
        JOIN VerificationReviewEntity r ON r.taskId = t.id
        WHERE t.changeRequestId = :changeRequestId
        AND r.result = 'PASS'
        """)
    boolean hasPassedVerification(@Param("changeRequestId") UUID changeRequestId);
    
    List<VerificationTaskEntity> findByStationIdOrderByCreatedAtDesc(UUID stationId);
    
    Page<VerificationTaskEntity> findAllByOrderByCreatedAtDesc(Pageable pageable);
    
    // For candidate query: get all tasks assigned to a user
    List<VerificationTaskEntity> findByAssignedTo(UUID assignedTo);

    @Query("""
            SELECT DISTINCT t.stationId FROM VerificationTaskEntity t
            WHERE t.assignedTo = :assignedTo AND t.status IN :statuses
            """)
    List<UUID> findDistinctStationIdsByAssignedToAndStatusIn(
            @Param("assignedTo") UUID assignedTo,
            @Param("statuses") List<VerificationTaskStatus> statuses);

    // ========== Battery Swap Verification Queries ==========

    List<VerificationTaskEntity> findByStationIdAndVerificationTypeOrderByCreatedAtDesc(
            UUID stationId, VerificationType type);

    Page<VerificationTaskEntity> findByVerificationTypeOrderByCreatedAtDesc(VerificationType type, Pageable pageable);

    Page<VerificationTaskEntity> findByVerificationTypeAndStatusOrderByCreatedAtDesc(
            VerificationType type, VerificationTaskStatus status, Pageable pageable);

    List<VerificationTaskEntity> findByAssignedToAndVerificationTypeOrderByCreatedAtDesc(
            UUID assignedTo, VerificationType type);

    Page<VerificationTaskEntity> findByAssignedToAndVerificationTypeOrderByPriorityAscSlaDueAtAscCreatedAtDesc(
            UUID assignedTo, VerificationType type, Pageable pageable);

    Page<VerificationTaskEntity> findByAssignedToAndVerificationTypeAndStatusOrderByPriorityAscSlaDueAtAscCreatedAtDesc(
            UUID assignedTo, VerificationType type, VerificationTaskStatus status, Pageable pageable);

    @Query("""
        SELECT t FROM VerificationTaskEntity t
        WHERE t.assignedTo = :assignedTo
        AND t.verificationType = :type
        AND t.status IN :statuses
        ORDER BY t.priority ASC, t.slaDueAt ASC NULLS LAST, t.createdAt DESC
        """)
    List<VerificationTaskEntity> findByAssignedToAndVerificationTypeAndStatusIn(
            @Param("assignedTo") UUID assignedTo,
            @Param("type") VerificationType type,
            @Param("statuses") List<VerificationTaskStatus> statuses);

    @Query("""
        SELECT t FROM VerificationTaskEntity t
        WHERE t.assignedTo = :assignedTo
        AND t.verificationType = :type
        AND t.status = 'REVIEWED'
        ORDER BY t.createdAt DESC
        """)
    Page<VerificationTaskEntity> findReviewedByAssignedToAndVerificationType(
            @Param("assignedTo") UUID assignedTo,
            @Param("type") VerificationType type,
            Pageable pageable);
}

