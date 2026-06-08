package com.example.evstation.batteryswap.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for BatterySwapPileTemplateEntity operations.
 */
@Repository
public interface BatterySwapPileTemplateJpaRepository extends JpaRepository<BatterySwapPileTemplateEntity, UUID> {

    /**
     * Find all pile templates for a station version.
     */
    List<BatterySwapPileTemplateEntity> findByStationVersionIdOrderByPileIndex(UUID stationVersionId);

    /**
     * Find pile template by station version and pile index.
     */
    Optional<BatterySwapPileTemplateEntity> findByStationVersionIdAndPileIndex(UUID stationVersionId, Integer pileIndex);

    /**
     * Count pile templates for a station version.
     */
    long countByStationVersionId(UUID stationVersionId);

    /**
     * Delete all pile templates for a station version.
     */
    void deleteByStationVersionId(UUID stationVersionId);

    /**
     * Delete all pile templates and their slot templates for a station version.
     * Slot templates must be deleted first due to FK constraint.
     */
    @Modifying
    @Query("DELETE FROM BatterySwapSlotTemplateEntity s WHERE s.pileTemplate.stationVersion.id = :stationVersionId")
    void deleteSlotTemplatesByStationVersionId(@Param("stationVersionId") UUID stationVersionId);

    @Modifying
    @Query("DELETE FROM BatterySwapPileTemplateEntity p WHERE p.stationVersion.id = :stationVersionId")
    void deletePileTemplatesByStationVersionId(@Param("stationVersionId") UUID stationVersionId);

    /**
     * Find pile template with slot templates eagerly loaded.
     */
    @Query("SELECT p FROM BatterySwapPileTemplateEntity p LEFT JOIN FETCH p.slotTemplates WHERE p.stationVersion.id = :stationVersionId ORDER BY p.pileIndex")
    List<BatterySwapPileTemplateEntity> findByStationVersionIdWithSlots(@Param("stationVersionId") UUID stationVersionId);

    /**
     * Sum of all slots across all piles for a station version.
     */
    @Query("SELECT COALESCE(SUM(p.slotsPerPile), 0) FROM BatterySwapPileTemplateEntity p WHERE p.stationVersion.id = :stationVersionId")
    Integer sumSlotsByStationVersionId(@Param("stationVersionId") UUID stationVersionId);
}
