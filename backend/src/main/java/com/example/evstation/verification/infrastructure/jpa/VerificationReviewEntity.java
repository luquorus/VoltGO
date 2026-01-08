package com.example.evstation.verification.infrastructure.jpa;

import com.example.evstation.verification.domain.VerificationResult;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "verification_review")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VerificationReviewEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "task_id", nullable = false, unique = true, columnDefinition = "UUID")
    private UUID taskId;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VerificationResult result;
    
    @Column(name = "admin_note")
    private String adminNote;
    
    @Column(name = "reviewed_at", nullable = false)
    private Instant reviewedAt;
    
    @Column(name = "reviewed_by", nullable = false, columnDefinition = "UUID")
    private UUID reviewedBy;
    
    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (reviewedAt == null) {
            reviewedAt = Instant.now();
        }
    }
}

