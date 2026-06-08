package com.example.evstation.loyalty.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ReferralJpaRepository extends JpaRepository<ReferralEntity, UUID> {

    Optional<ReferralEntity> findByReferrerIdAndReferralCode(UUID referrerId, String referralCode);

    Optional<ReferralEntity> findByRefereeId(UUID refereeId);

    boolean existsByRefereeId(UUID refereeId);
}
