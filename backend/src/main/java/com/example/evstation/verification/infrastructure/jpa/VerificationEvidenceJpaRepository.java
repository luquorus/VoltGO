package com.example.evstation.verification.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface VerificationEvidenceJpaRepository extends JpaRepository<VerificationEvidenceEntity, UUID> {
    
    List<VerificationEvidenceEntity> findByTaskIdOrderBySubmittedAtDesc(UUID taskId);
    
    List<VerificationEvidenceEntity> findBySubmittedByOrderBySubmittedAtDesc(UUID submittedBy);
    
    /**
     * Find evidence by photo object key.
     * Used for security check when generating presigned view URLs.
     */
    java.util.Optional<VerificationEvidenceEntity> findByPhotoObjectKey(String photoObjectKey);
}

