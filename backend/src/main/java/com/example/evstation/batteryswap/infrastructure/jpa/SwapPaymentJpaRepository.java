package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.SwapPaymentStatus;
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
public interface SwapPaymentJpaRepository extends JpaRepository<SwapPaymentEntity, UUID> {

    Optional<SwapPaymentEntity> findByReservationId(UUID reservationId);

    List<SwapPaymentEntity> findByReservationIdOrderByCreatedAtDesc(UUID reservationId);

    @Modifying
    @Query("UPDATE SwapPaymentEntity p SET p.status = :status, p.paidAt = :paidAt WHERE p.reservationId = :reservationId AND p.status = :expectedStatus")
    int markPaid(@Param("reservationId") UUID reservationId,
                 @Param("expectedStatus") SwapPaymentStatus expectedStatus,
                 @Param("status") SwapPaymentStatus newStatus,
                 @Param("paidAt") Instant paidAt);

    @Modifying
    @Query("UPDATE SwapPaymentEntity p SET p.status = :status, p.refundedAt = :refundedAt WHERE p.reservationId = :reservationId AND p.status = 'SUCCESS'")
    int markRefunded(@Param("reservationId") UUID reservationId,
                     @Param("status") SwapPaymentStatus status,
                     @Param("refundedAt") Instant refundedAt);

    @Modifying
    @Query("UPDATE SwapPaymentEntity p SET p.status = :status, p.expiredAt = :expiredAt WHERE p.reservationId = :reservationId AND p.status = 'PENDING'")
    int markExpired(@Param("reservationId") UUID reservationId,
                    @Param("status") SwapPaymentStatus status,
                    @Param("expiredAt") Instant expiredAt);
}
