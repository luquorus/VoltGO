package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.ChangeRequestStatus;
import com.example.evstation.batteryswap.domain.ChangeRequestType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for BatterySwapChangeRequestEntity operations.
 */
@Repository
public interface BatterySwapChangeRequestJpaRepository extends JpaRepository<BatterySwapChangeRequestEntity, UUID> {

    /**
     * Find all change requests for a station.
     */
    List<BatterySwapChangeRequestEntity> findByStationIdOrderByCreatedAtDesc(UUID stationId);

    /**
     * Find all change requests by status.
     */
    List<BatterySwapChangeRequestEntity> findByStatus(ChangeRequestStatus status);

    /**
     * Find all change requests by type.
     */
    List<BatterySwapChangeRequestEntity> findByType(ChangeRequestType type);

    /**
     * Find change request by proposed version ID.
     */
    Optional<BatterySwapChangeRequestEntity> findByProposedVersionId(UUID proposedVersionId);

    /**
     * Find all change requests submitted by a user.
     */
    List<BatterySwapChangeRequestEntity> findBySubmittedByOrderByCreatedAtDesc(UUID submittedBy);

    /**
     * Find change request by station and status.
     */
    List<BatterySwapChangeRequestEntity> findByStationIdAndStatus(UUID stationId, ChangeRequestStatus status);

    /**
     * Find all pending change requests (submitted or in_review).
     */
    @Query("SELECT cr FROM BatterySwapChangeRequestEntity cr WHERE cr.status IN ('SUBMITTED', 'IN_REVIEW') ORDER BY cr.createdAt ASC")
    List<BatterySwapChangeRequestEntity> findPendingRequests();

    /**
     * Count change requests by station and status.
     */
    long countByStationIdAndStatus(UUID stationId, ChangeRequestStatus status);

    /**
     * Check if there's already a pending request for a proposed version.
     */
    boolean existsByProposedVersionIdAndStatusIn(UUID proposedVersionId, List<ChangeRequestStatus> statuses);

    /**
     * Find change requests with high risk score.
     */
    @Query("SELECT cr FROM BatterySwapChangeRequestEntity cr WHERE cr.riskScore >= :threshold ORDER BY cr.riskScore DESC")
    List<BatterySwapChangeRequestEntity> findHighRiskRequests(@Param("threshold") int threshold);

    /**
     * Find change requests by station ordered by creation date.
     */
    @Query("SELECT cr FROM BatterySwapChangeRequestEntity cr WHERE cr.stationId = :stationId ORDER BY cr.createdAt DESC")
    List<BatterySwapChangeRequestEntity> findByStationIdAll(@Param("stationId") UUID stationId);
}
