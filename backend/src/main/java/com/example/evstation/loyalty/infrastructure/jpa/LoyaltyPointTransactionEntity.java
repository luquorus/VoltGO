package com.example.evstation.loyalty.infrastructure.jpa;

import com.example.evstation.loyalty.domain.PointType;
import com.example.evstation.loyalty.domain.PointSource;
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
@Table(name = "loyalty_point_transaction", indexes = {
    @Index(name = "idx_lpt_user_created", columnList = "user_id, created_at DESC")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoyaltyPointTransactionEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "user_id", nullable = false, columnDefinition = "UUID")
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PointType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PointSource source;

    @Column(name = "source_id", columnDefinition = "UUID")
    private UUID sourceId;

    @Column(nullable = false)
    private Integer points;

    @Column(name = "balance_after", nullable = false)
    private Integer balanceAfter;

    @Column
    private String description;

    @Column(columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private Map<String, Object> metadata;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) id = UUID.randomUUID();
        if (createdAt == null) createdAt = Instant.now();
    }
}
