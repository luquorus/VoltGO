package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.station.domain.WorkflowStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for BatterySwapStationVersionEntity operations.
 */
@Repository
public interface BatterySwapStationVersionJpaRepository extends JpaRepository<BatterySwapStationVersionEntity, UUID> {

    /**
     * Find all versions for a station.
     */
    List<BatterySwapStationVersionEntity> findByStationIdOrderByVersionNoDesc(UUID stationId);

    /**
     * Find the latest version for a station.
     */
    Optional<BatterySwapStationVersionEntity> findFirstByStationIdOrderByVersionNoDesc(UUID stationId);

    /**
     * Find published version for a station.
     */
    Optional<BatterySwapStationVersionEntity> findByStationIdAndWorkflowStatus(UUID stationId, WorkflowStatus workflowStatus);

    /**
     * Find version by station and version number.
     */
    Optional<BatterySwapStationVersionEntity> findByStationIdAndVersionNo(UUID stationId, Integer versionNo);

    /**
     * Find all versions with a specific workflow status.
     */
    List<BatterySwapStationVersionEntity> findByWorkflowStatus(WorkflowStatus workflowStatus);

    /**
     * Find the next version number for a station.
     */
    @Query("SELECT COALESCE(MAX(v.versionNo), 0) + 1 FROM BatterySwapStationVersionEntity v WHERE v.stationId = :stationId")
    Integer findNextVersionNo(@Param("stationId") UUID stationId);

    /**
     * Count versions for a station.
     */
    long countByStationId(UUID stationId);

    /**
     * Check if a station has a published version.
     */
    boolean existsByStationIdAndWorkflowStatus(UUID stationId, WorkflowStatus workflowStatus);
}
