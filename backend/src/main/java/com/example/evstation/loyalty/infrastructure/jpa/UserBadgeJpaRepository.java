package com.example.evstation.loyalty.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface UserBadgeJpaRepository extends JpaRepository<UserBadgeEntity, UUID> {

    List<UserBadgeEntity> findByUserId(UUID userId);

    boolean existsByUserIdAndBadgeId(UUID userId, UUID badgeId);
}
