package com.example.evstation.verification.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "verification_evidence")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VerificationEvidenceEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "task_id", nullable = false, columnDefinition = "UUID")
    private UUID taskId;
    
    @Column(name = "photo_object_key", nullable = false)
    private String photoObjectKey;
    
    @Column(name = "note")
    private String note;
    
    @Column(name = "submitted_at", nullable = false)
    private Instant submittedAt;
    
    @Column(name = "submitted_by", nullable = false, columnDefinition = "UUID")
    private UUID submittedBy;
    
    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (submittedAt == null) {
            submittedAt = Instant.now();
        }
    }
}

