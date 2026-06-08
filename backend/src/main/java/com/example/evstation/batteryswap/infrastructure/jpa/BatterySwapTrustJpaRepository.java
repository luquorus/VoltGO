package com.example.evstation.batteryswap.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for BatterySwapTrustEntity operations.
 */
@Repository
public interface BatterySwapTrustJpaRepository extends JpaRepository<BatterySwapTrustEntity, UUID> {

    /**
     * Find trust record by station ID.
     */
    Optional<BatterySwapTrustEntity> findByStationId(UUID stationId);

    /**
     * Find all trust records ordered by score descending.
     */
    List<BatterySwapTrustEntity> findAllByOrderByScoreDesc();

    /**
     * Find trust records by score range.
     */
    List<BatterySwapTrustEntity> findByScoreBetween(Integer minScore, Integer maxScore);

    /**
     * Find trust records with low scores.
     */
    @Query("SELECT t FROM BatterySwapTrustEntity t WHERE t.score < :threshold ORDER BY t.score ASC")
    List<BatterySwapTrustEntity> findLowTrustRecords(@Param("threshold") int threshold);

    /**
     * Find trust records with high scores.
     */
    @Query("SELECT t FROM BatterySwapTrustEntity t WHERE t.score >= :threshold ORDER BY t.score DESC")
    List<BatterySwapTrustEntity> findHighTrustRecords(@Param("threshold") int threshold);

    /**
     * Find trust records updated after a specific time.
     */
    List<BatterySwapTrustEntity> findByUpdatedAtAfterOrderByUpdatedAtDesc(Instant after);

    /**
     * Find trust records with recent events.
     */
    @Query("SELECT t FROM BatterySwapTrustEntity t WHERE t.lastEventAt IS NOT NULL ORDER BY t.lastEventAt DESC")
    List<BatterySwapTrustEntity> findWithRecentEvents();

    /**
     * Check if a station has a trust record.
     */
    boolean existsByStationId(UUID stationId);

    /**
     * Delete trust record by station ID.
     */
    void deleteByStationId(UUID stationId);

    /**
     * Find trust records by station IDs.
     */
    @Query("SELECT t FROM BatterySwapTrustEntity t WHERE t.stationId IN :stationIds")
    List<BatterySwapTrustEntity> findByStationIds(@Param("stationIds") List<UUID> stationIds);

    /**
     * Calculate average trust score across all records.
     */
    @Query("SELECT AVG(t.score) FROM BatterySwapTrustEntity t")
    Double calculateAverageScore();
}
