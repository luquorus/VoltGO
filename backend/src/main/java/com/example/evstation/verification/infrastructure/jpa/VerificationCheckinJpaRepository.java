package com.example.evstation.verification.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface VerificationCheckinJpaRepository extends JpaRepository<VerificationCheckinEntity, UUID> {
    
    Optional<VerificationCheckinEntity> findByTaskId(UUID taskId);
    
    boolean existsByTaskId(UUID taskId);
}

