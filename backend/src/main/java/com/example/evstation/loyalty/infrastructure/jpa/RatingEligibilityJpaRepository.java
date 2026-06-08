package com.example.evstation.loyalty.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.evstation.loyalty.domain.EligibilityType;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RatingEligibilityJpaRepository extends JpaRepository<RatingEligibilityEntity, UUID> {

    List<RatingEligibilityEntity> findByUserIdAndIsRatedFalse(UUID userId);

    Optional<RatingEligibilityEntity> findByUserIdAndStationIdAndSourceTypeAndSourceId(
            UUID userId, UUID stationId, EligibilityType sourceType, UUID sourceId);

    boolean existsByUserIdAndStationIdAndSourceTypeAndSourceId(
            UUID userId, UUID stationId, EligibilityType sourceType, UUID sourceId);

    @Query("SELECT COUNT(r) FROM RatingEligibilityEntity r WHERE r.userId = :userId AND r.createdAt > :since")
    long countTodayByUserId(@Param("userId") UUID userId, @Param("since") Instant since);
}
