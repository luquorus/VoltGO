package com.example.evstation.loyalty.infrastructure.jpa;

import com.example.evstation.loyalty.domain.RedemptionStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "voucher_redemption", indexes = {
    @Index(name = "idx_vr_user_status", columnList = "user_id, status"),
    @Index(name = "idx_vr_expires", columnList = "status, expires_at")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VoucherRedemptionEntity {

    @Id
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "user_id", nullable = false, columnDefinition = "UUID")
    private UUID userId;

    @Column(name = "voucher_definition_id", nullable = false, columnDefinition = "UUID")
    private UUID voucherDefinitionId;

    @Column(name = "voucher_code", unique = true, nullable = false)
    private String voucherCode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private RedemptionStatus status = RedemptionStatus.REDEEMED;

    @Column(name = "points_spent", nullable = false)
    private Integer pointsSpent;

    @Column(name = "redeemed_at", nullable = false)
    private Instant redeemedAt;

    @Column(name = "used_at")
    private Instant usedAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private Map<String, Object> metadata;

    @Column(name = "booking_id", columnDefinition = "UUID")
    private UUID bookingId;

    @Column(name = "service_type")
    private String serviceType;

    @PrePersist
    protected void onCreate() {
        if (id == null) id = UUID.randomUUID();
        if (redeemedAt == null) redeemedAt = Instant.now();
    }
}
