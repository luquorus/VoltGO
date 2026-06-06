package com.example.evstation.loyalty.infrastructure.jpa;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.evstation.loyalty.domain.RatingStatus;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StationRatingJpaRepository extends JpaRepository<StationRatingEntity, UUID> {

    Page<StationRatingEntity> findByStationIdOrderByCreatedAtDesc(UUID stationId, Pageable pageable);

    List<StationRatingEntity> findByUserIdOrderByCreatedAtDesc(UUID userId);

    @Query("SELECT COUNT(r) FROM StationRatingEntity r WHERE r.userId = :userId AND r.createdAt > :since")
    long countTodayByUserId(@Param("userId") UUID userId, @Param("since") Instant since);

    Optional<StationRatingEntity> findByIdAndStatus(UUID id, RatingStatus status);

    @Query("SELECT r.rating, COUNT(r) FROM StationRatingEntity r WHERE r.stationId = :stationId AND r.status = :status GROUP BY r.rating")
    List<Object[]> countByStationIdGroupByRating(@Param("stationId") UUID stationId, @Param("status") RatingStatus status);

    @Query("SELECT AVG(r.rating) FROM StationRatingEntity r WHERE r.stationId = :stationId AND r.status = :status")
    Double avgRatingByStationId(@Param("stationId") UUID stationId, @Param("status") RatingStatus status);

    @Query("SELECT COUNT(r) FROM StationRatingEntity r WHERE r.stationId = :stationId AND r.status = :status")
    long countActiveByStationId(@Param("stationId") UUID stationId, @Param("status") RatingStatus status);
}
