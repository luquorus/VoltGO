package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.BatterySwapStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BatterySwapReservationJpaRepository extends JpaRepository<BatterySwapReservationEntity, UUID> {
    List<BatterySwapReservationEntity> findByUserIdOrderByReservedAtDesc(UUID userId);

    List<BatterySwapReservationEntity> findByStationIdAndStatusIn(UUID stationId, List<BatterySwapStatus> statuses);

    List<BatterySwapReservationEntity> findByUserIdAndStatusIn(UUID userId, List<BatterySwapStatus> statuses);

    Optional<BatterySwapReservationEntity> findByIdAndUserId(UUID id, UUID userId);

    Page<BatterySwapReservationEntity> findByStationIdOrderByReservedAtDesc(UUID stationId, Pageable pageable);

    Page<BatterySwapReservationEntity> findByStatusOrderByReservedAtDesc(BatterySwapStatus status, Pageable pageable);

    Page<BatterySwapReservationEntity> findByStationIdAndStatusOrderByReservedAtDesc(
            UUID stationId, BatterySwapStatus status, Pageable pageable);

    /**
     * Tìm các reservation hết hạn để job expire xử lý:
     * - Có confirmedArrivalAt: expire nếu confirmedArrivalAt + 15p < now
     * - Không có confirmedArrivalAt: expire nếu reservedSlotAt + 15p < now
     */
    @Query("SELECT r FROM BatterySwapReservationEntity r "
            + "WHERE r.status = com.example.evstation.batteryswap.domain.BatterySwapStatus.RESERVED "
            + "AND ("
            + "  (r.confirmedArrivalAt IS NOT NULL AND r.confirmedArrivalAt < :confirmedCutoff) "
            + "  OR (r.confirmedArrivalAt IS NULL AND r.reservedSlotAt IS NOT NULL AND r.reservedSlotAt < :slotCutoff) "
            + "  OR (r.confirmedArrivalAt IS NULL AND r.reservedSlotAt IS NULL AND r.reservedAt < :reservedCutoff)"
            + ")")
    List<BatterySwapReservationEntity> findReservedExpired(
            @Param("confirmedCutoff") Instant confirmedCutoff,
            @Param("slotCutoff") Instant slotCutoff,
            @Param("reservedCutoff") Instant reservedCutoff);

    Page<BatterySwapReservationEntity> findAllByOrderByReservedAtDesc(Pageable pageable);

    Page<BatterySwapReservationEntity> findByStationIdInAndStatusInOrderByReservedAtDesc(
            List<UUID> stationIds, List<BatterySwapStatus> statuses, Pageable pageable);

    @Query("SELECT r FROM BatterySwapReservationEntity r "
            + "WHERE r.status = com.example.evstation.batteryswap.domain.BatterySwapStatus.RESERVED "
            + "AND r.paymentStatus = com.example.evstation.batteryswap.domain.PaymentStatus.UNPAID "
            + "AND r.reservedAt < :cutoff")
    List<BatterySwapReservationEntity> findUnpaidExpired(@Param("cutoff") Instant cutoff);

    @Query("SELECT r FROM BatterySwapReservationEntity r "
            + "WHERE r.status = com.example.evstation.batteryswap.domain.BatterySwapStatus.SWAPPING "
            + "AND r.swapDeadlineAt IS NOT NULL AND r.swapDeadlineAt < :now")
    List<BatterySwapReservationEntity> findExpiredSwapDeadline(@Param("now") Instant now);

    Optional<BatterySwapReservationEntity> findBySwapCode(String swapCode);
}
