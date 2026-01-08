package com.example.evstation.payment.infrastructure.jpa;

import com.example.evstation.payment.domain.PaymentIntentStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "payment_intent", indexes = {
    @Index(name = "idx_payment_intent_booking_id", columnList = "booking_id"),
    @Index(name = "idx_payment_intent_status", columnList = "status"),
    @Index(name = "idx_payment_intent_created_at", columnList = "created_at")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PaymentIntentEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "booking_id", nullable = false, unique = true, columnDefinition = "UUID")
    private UUID bookingId;
    
    @Column(nullable = false)
    private Integer amount;
    
    @Column(nullable = false)
    @Builder.Default
    private String currency = "VND";
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private PaymentIntentStatus status = PaymentIntentStatus.CREATED;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
    
    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}

