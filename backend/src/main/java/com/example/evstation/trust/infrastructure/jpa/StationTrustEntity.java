package com.example.evstation.trust.infrastructure.jpa;

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
@Table(name = "station_trust")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationTrustEntity {
    
    @Id
    @Column(name = "station_id", columnDefinition = "UUID")
    private UUID stationId;
    
    @Column(nullable = false)
    private Integer score;
    
    @Column(columnDefinition = "jsonb", nullable = false)
    @JdbcTypeCode(SqlTypes.JSON)
    private Map<String, Object> breakdown;
    
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
    
    @PrePersist
    @PreUpdate
    protected void onUpdate() {
        if (updatedAt == null) {
            updatedAt = Instant.now();
        }
    }
}

