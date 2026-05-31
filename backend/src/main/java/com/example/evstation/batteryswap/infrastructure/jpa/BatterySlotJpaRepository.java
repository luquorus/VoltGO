package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BatterySlotJpaRepository extends JpaRepository<BatterySlotEntity, UUID> {

    List<BatterySlotEntity> findByPileIdOrderBySlotIndexAsc(UUID pileId);

    List<BatterySlotEntity> findByPileIdAndStatus(UUID pileId, BatterySlotStatus status);

    Optional<BatterySlotEntity> findByPileIdAndSlotIndex(UUID pileId, Integer slotIndex);

    int countByPileIdAndStatus(UUID pileId, BatterySlotStatus status);

    @Query("SELECT s.pileId, COUNT(s) FROM BatterySlotEntity s "
            + "WHERE s.pileId IN :pileIds AND s.status = :status "
            + "GROUP BY s.pileId")
    List<Object[]> countAvailableByPileIds(
            @Param("pileIds") List<UUID> pileIds,
            @Param("status") BatterySlotStatus status);

    @Modifying
    @Query("UPDATE BatterySlotEntity s "
            + "SET s.status = :newStatus, s.updatedAt = :now "
            + "WHERE s.id = :slotId AND s.status = :expectedStatus")
    int updateStatus(@Param("slotId") UUID slotId,
                     @Param("expectedStatus") BatterySlotStatus expectedStatus,
                     @Param("newStatus") BatterySlotStatus newStatus,
                     @Param("now") Instant now);

    @Query("SELECT COUNT(s) FROM BatterySlotEntity s "
            + "WHERE s.pileId IN (SELECT p.id FROM SwapPileEntity p WHERE p.stationId = :stationId) "
            + "AND s.status = :status")
    long countAvailableByStationId(@Param("stationId") UUID stationId,
                                   @Param("status") BatterySlotStatus status);

    @Query("SELECT COUNT(s) FROM BatterySlotEntity s "
            + "WHERE s.pileId IN (SELECT p.id FROM SwapPileEntity p WHERE p.stationId = :stationId) "
            + "AND s.status = :status")
    long countByStationIdAndStatus(@Param("stationId") UUID stationId,
                                   @Param("status") BatterySlotStatus status);

    /**
     * Tìm tất cả slot đang sạc (CHARGING hoặc SWAPPED_OUT) để simulation job tính % pin.
     */
    @Query("SELECT s FROM BatterySlotEntity s "
            + "WHERE s.status IN (:chargingStatuses)")
    List<BatterySlotEntity> findByChargingStatuses(@Param("chargingStatuses") List<BatterySlotStatus> statuses);

    @Modifying
    @Query("UPDATE BatterySlotEntity s "
            + "SET s.status = :newStatus, s.batteryChargePercent = :chargePercent, "
            + "s.chargingStartedAt = :chargingStartedAt, "
            + "s.estimatedFullAt = :estimatedFullAt, s.updatedAt = :now "
            + "WHERE s.id = :slotId AND s.status = :expectedStatus")
    int updateStatusWithCharging(@Param("slotId") UUID slotId,
                                @Param("expectedStatus") BatterySlotStatus expectedStatus,
                                @Param("newStatus") BatterySlotStatus newStatus,
                                @Param("chargePercent") int chargePercent,
                                @Param("chargingStartedAt") Instant chargingStartedAt,
                                @Param("estimatedFullAt") Instant estimatedFullAt,
                                @Param("now") Instant now);

    /**
     * Bulk-update charging percent cho các slot CHARGING/SWAPPED_OUT.
     * Chỉ update những slot đã đạt đến 100%.
     */
    @Modifying
    @Query("UPDATE BatterySlotEntity s "
            + "SET s.status = 'AVAILABLE', s.batteryChargePercent = 100, "
            + "s.estimatedFullAt = NULL, s.updatedAt = :now "
            + "WHERE s.status IN (:chargingStatuses) AND s.batteryChargePercent >= 100")
    int finalizeChargedSlots(@Param("chargingStatuses") List<BatterySlotStatus> statuses,
                             @Param("now") Instant now);

    /**
     * Tìm tất cả slot theo stationId thông qua pileId.
     */
    @Query("SELECT s FROM BatterySlotEntity s "
            + "WHERE s.pileId IN (SELECT p.id FROM SwapPileEntity p WHERE p.stationId = :stationId) "
            + "ORDER BY s.pileId, s.slotIndex ASC")
    List<BatterySlotEntity> findByStationId(@Param("stationId") UUID stationId);

    /**
     * Tìm tất cả slot theo stationId và status.
     */
    @Query("SELECT s FROM BatterySlotEntity s "
            + "WHERE s.pileId IN (SELECT p.id FROM SwapPileEntity p WHERE p.stationId = :stationId) "
            + "AND s.status = :status")
    List<BatterySlotEntity> findByStationIdAndStatus(
            @Param("stationId") UUID stationId,
            @Param("status") BatterySlotStatus status);
}
