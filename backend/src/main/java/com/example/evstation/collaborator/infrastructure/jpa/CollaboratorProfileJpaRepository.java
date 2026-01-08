package com.example.evstation.collaborator.infrastructure.jpa;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface CollaboratorProfileJpaRepository extends JpaRepository<CollaboratorProfileEntity, UUID> {
    
    Optional<CollaboratorProfileEntity> findByUserAccountId(UUID userAccountId);
    
    boolean existsByUserAccountId(UUID userAccountId);
    
    Page<CollaboratorProfileEntity> findAllByOrderByCreatedAtDesc(Pageable pageable);
}

