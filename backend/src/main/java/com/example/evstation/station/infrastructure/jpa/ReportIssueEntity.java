package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.IssueCategory;
import com.example.evstation.station.domain.IssueStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "report_issue", indexes = {
    @Index(name = "idx_report_issue_station_id", columnList = "station_id"),
    @Index(name = "idx_report_issue_status", columnList = "status"),
    @Index(name = "idx_report_issue_reporter_id", columnList = "reporter_id")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportIssueEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;
    
    @Column(name = "reporter_id", nullable = false, columnDefinition = "UUID")
    private UUID reporterId;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private IssueCategory category;
    
    @Column(nullable = false, columnDefinition = "TEXT")
    private String description;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private IssueStatus status = IssueStatus.OPEN;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @Column(name = "decided_at")
    private Instant decidedAt;
    
    @Column(name = "admin_note")
    private String adminNote;
    
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

