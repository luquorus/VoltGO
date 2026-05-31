package com.example.evstation.batteryswap.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.UUID;

@Repository
public interface BatterySwapStationStateJpaRepository extends JpaRepository<BatterySwapStationStateEntity, UUID> {

    /**
     * Atomic decrement availableBatteries (chỉ thành công nếu > 0).
     * Trả về 1 nếu thành công, 0 nếu hết pin -> caller raise 409.
     */
    @Modifying
    @Query("UPDATE BatterySwapStationStateEntity s "
            + "SET s.availableBatteries = s.availableBatteries - 1, s.updatedAt = :now "
            + "WHERE s.stationId = :stationId AND s.availableBatteries > 0")
    int reserveOne(@Param("stationId") UUID stationId, @Param("now") Instant now);

    /**
     * Atomic increment availableBatteries (chặn vượt total). Trả về 1 nếu update.
     */
    @Modifying
    @Query("UPDATE BatterySwapStationStateEntity s "
            + "SET s.availableBatteries = s.availableBatteries + 1, s.updatedAt = :now "
            + "WHERE s.stationId = :stationId AND s.availableBatteries < s.totalBatteries")
    int releaseOne(@Param("stationId") UUID stationId, @Param("now") Instant now);

    /**
     * Đồng bộ số lượng AVAILABLE slots vào availableBatteries của station state.
     * Gọi khi simulation job chuyển slot sang AVAILABLE.
     */
    @Modifying
    @Query("UPDATE BatterySwapStationStateEntity s "
            + "SET s.availableBatteries = :availableBatteries, s.updatedAt = :now "
            + "WHERE s.stationId = :stationId")
    int syncAvailableBatteries(@Param("stationId") UUID stationId,
                               @Param("availableBatteries") int availableBatteries,
                               @Param("now") Instant now);
}
