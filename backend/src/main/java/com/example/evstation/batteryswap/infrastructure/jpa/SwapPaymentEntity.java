package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.SwapPaymentStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "swap_payment")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SwapPaymentEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "reservation_id", nullable = false, columnDefinition = "UUID")
    private UUID reservationId;

    @Column(name = "amount_vnd", nullable = false)
    private Long amountVnd;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private SwapPaymentStatus status = SwapPaymentStatus.PENDING;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "paid_at")
    private Instant paidAt;

    @Column(name = "refunded_at")
    private Instant refundedAt;

    @Column(name = "expired_at")
    private Instant expiredAt;

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        if (id == null) id = UUID.randomUUID();
        if (createdAt == null) createdAt = now;
    }
}
