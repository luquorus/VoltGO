package com.example.evstation.collaborator.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "collaborator_profile")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CollaboratorProfileEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "user_account_id", nullable = false, unique = true, columnDefinition = "UUID")
    private UUID userAccountId;
    
    @Column(name = "full_name")
    private String fullName;
    
    @Column(name = "phone")
    private String phone;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}

