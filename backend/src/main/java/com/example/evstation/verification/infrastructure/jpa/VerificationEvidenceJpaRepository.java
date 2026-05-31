package com.example.evstation.verification.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VerificationEvidenceJpaRepository extends JpaRepository<VerificationEvidenceEntity, UUID> {

    List<VerificationEvidenceEntity> findByTaskIdOrderBySubmittedAtDesc(UUID taskId);

    Optional<VerificationEvidenceEntity> findFirstByTaskIdOrderBySubmittedAtDesc(UUID taskId);

    Optional<VerificationEvidenceEntity> findByPhotoObjectKey(String photoObjectKey);

    @Query("""
        SELECT COUNT(e) > 0 FROM VerificationEvidenceEntity e
        JOIN VerificationTaskEntity t ON t.id = e.taskId
        WHERE e.photoObjectKey = :photoObjectKey
        AND t.assignedTo = :userId
        """)
    boolean existsByPhotoObjectKeyAndAssignedTo(
            @Param("photoObjectKey") String photoObjectKey,
            @Param("userId") UUID userId);
}
