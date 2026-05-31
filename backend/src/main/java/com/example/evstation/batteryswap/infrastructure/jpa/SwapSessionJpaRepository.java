package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.SwapSessionStatus;
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
public interface SwapSessionJpaRepository extends JpaRepository<SwapSessionEntity, UUID> {

    Optional<SwapSessionEntity> findByReservationId(UUID reservationId);

    Optional<SwapSessionEntity> findBySwapCode(String swapCode);

    List<SwapSessionEntity> findByReservationIdOrderByCreatedAtDesc(UUID reservationId);

    List<SwapSessionEntity> findByStatusOrderByCreatedAtDesc(SwapSessionStatus status);

    @Query("SELECT s FROM SwapSessionEntity s WHERE s.status = :status AND s.expiresAt < :now")
    List<SwapSessionEntity> findExpiredSessions(@Param("status") SwapSessionStatus status, @Param("now") Instant now);

    @Modifying
    @Query("UPDATE SwapSessionEntity s SET s.status = :newStatus WHERE s.reservationId = :reservationId AND s.status = :expectedStatus")
    int updateStatus(@Param("reservationId") UUID reservationId,
                     @Param("expectedStatus") SwapSessionStatus expectedStatus,
                     @Param("newStatus") SwapSessionStatus newStatus);

    @Modifying
    @Query("UPDATE SwapSessionEntity s SET s.status = 'COMPLETED', s.completedAt = :completedAt, s.completedBy = :completedBy WHERE s.swapCode = :swapCode AND s.status = 'PENDING' AND s.expiresAt >= :now")
    int completeByCode(@Param("swapCode") String swapCode,
                       @Param("completedAt") Instant completedAt,
                       @Param("completedBy") UUID completedBy,
                       @Param("now") Instant now);
}
