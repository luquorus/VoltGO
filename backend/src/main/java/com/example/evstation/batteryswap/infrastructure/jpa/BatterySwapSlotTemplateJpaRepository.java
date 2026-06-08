package com.example.evstation.batteryswap.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for BatterySwapSlotTemplateEntity operations.
 */
@Repository
public interface BatterySwapSlotTemplateJpaRepository extends JpaRepository<BatterySwapSlotTemplateEntity, UUID> {

    /**
     * Find all slot templates for a pile template.
     */
    List<BatterySwapSlotTemplateEntity> findByPileTemplateIdOrderBySlotIndex(UUID pileTemplateId);

    /**
     * Find slot template by pile template and slot index.
     */
    Optional<BatterySwapSlotTemplateEntity> findByPileTemplateIdAndSlotIndex(UUID pileTemplateId, Integer slotIndex);

    /**
     * Count slot templates for a pile template.
     */
    long countByPileTemplateId(UUID pileTemplateId);

    /**
     * Delete all slot templates for a pile template.
     */
    void deleteByPileTemplateId(UUID pileTemplateId);
}
