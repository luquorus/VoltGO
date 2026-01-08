package com.example.evstation.verification.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VerificationReviewJpaRepository extends JpaRepository<VerificationReviewEntity, UUID> {
    
    Optional<VerificationReviewEntity> findByTaskId(UUID taskId);
    
    boolean existsByTaskId(UUID taskId);
    
    // For KPI: count by result and month for a collaborator
    @Query("""
        SELECT r.result, COUNT(r) FROM VerificationReviewEntity r
        JOIN VerificationTaskEntity t ON t.id = r.taskId
        WHERE t.assignedTo = :collaboratorUserId
        AND r.reviewedAt >= :since
        GROUP BY r.result
        """)
    List<Object[]> countByResultForCollaborator(
            @Param("collaboratorUserId") UUID collaboratorUserId,
            @Param("since") Instant since);
    
    // For trust score: find latest review for a station within timeframe
    @Query("""
        SELECT r FROM VerificationReviewEntity r
        JOIN VerificationTaskEntity t ON t.id = r.taskId
        WHERE t.stationId = :stationId
        AND r.reviewedAt >= :since
        ORDER BY r.reviewedAt DESC
        """)
    List<VerificationReviewEntity> findRecentReviewsForStation(
            @Param("stationId") UUID stationId,
            @Param("since") Instant since);
}

