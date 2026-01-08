package com.example.evstation.collaborator.infrastructure.jpa;

import com.example.evstation.collaborator.domain.ContractStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "contract")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ContractEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "collaborator_id", nullable = false, columnDefinition = "UUID")
    private UUID collaboratorId;
    
    @Column(name = "region")
    private String region;
    
    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;
    
    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ContractStatus status = ContractStatus.ACTIVE;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @Column(name = "terminated_at")
    private Instant terminatedAt;
    
    @Column(name = "note")
    private String note;
    
    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
    
    /**
     * Check if this contract is effectively active on a given date.
     * Contract is active when: status=ACTIVE and date is between start_date and end_date (inclusive)
     */
    public boolean isEffectivelyActive(LocalDate date) {
        return status == ContractStatus.ACTIVE 
                && !date.isBefore(startDate) 
                && !date.isAfter(endDate);
    }
}

