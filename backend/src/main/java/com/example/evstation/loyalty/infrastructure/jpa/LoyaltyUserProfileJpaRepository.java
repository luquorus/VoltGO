package com.example.evstation.loyalty.infrastructure.jpa;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface LoyaltyUserProfileJpaRepository extends JpaRepository<LoyaltyUserProfileEntity, UUID> {

    Optional<LoyaltyUserProfileEntity> findByUserId(UUID userId);

    Page<LoyaltyUserProfileEntity> findAllByOrderByCurrentPointsDesc(Pageable pageable);
}
