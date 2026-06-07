package com.example.evstation.loyalty.infrastructure.jpa;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LoyaltyUserProfileJpaRepository extends JpaRepository<LoyaltyUserProfileEntity, UUID> {

    Optional<LoyaltyUserProfileEntity> findByUserId(UUID userId);

    Page<LoyaltyUserProfileEntity> findAllByOrderByCurrentPointsDesc(Pageable pageable);

    @Query("SELECT COUNT(p) FROM LoyaltyUserProfileEntity p WHERE p.lastActivityAt > :since")
    long countActiveUsersSince(@Param("since") Instant since);

    @Query("SELECT COALESCE(SUM(p.lifetimePoints), 0) FROM LoyaltyUserProfileEntity p")
    int sumLifetimePoints();
}
