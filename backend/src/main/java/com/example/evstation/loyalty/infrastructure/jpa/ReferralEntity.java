package com.example.evstation.loyalty.infrastructure.jpa;

import com.example.evstation.loyalty.domain.ReferralStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "referral",
    uniqueConstraints = @UniqueConstraint(name = "uk_referral_code", columnNames = {"referrer_id", "referral_code"})
)
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReferralEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "referrer_id", nullable = false, columnDefinition = "UUID")
    private UUID referrerId;

    @Column(name = "referee_id", columnDefinition = "UUID")
    private UUID refereeId;

    @Column(name = "referral_code", nullable = false)
    private String referralCode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ReferralStatus status = ReferralStatus.PENDING;

    @Column(name = "referred_at", nullable = false)
    private Instant referredAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) id = UUID.randomUUID();
        if (referredAt == null) referredAt = Instant.now();
    }
}
