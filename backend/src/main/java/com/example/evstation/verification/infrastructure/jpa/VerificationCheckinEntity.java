package com.example.evstation.verification.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "verification_checkin")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VerificationCheckinEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "task_id", nullable = false, unique = true, columnDefinition = "UUID")
    private UUID taskId;
    
    @Column(name = "checkin_lat", nullable = false, precision = 10, scale = 7)
    private BigDecimal checkinLat;
    
    @Column(name = "checkin_lng", nullable = false, precision = 10, scale = 7)
    private BigDecimal checkinLng;
    
    @Column(name = "checked_in_at", nullable = false)
    private Instant checkedInAt;
    
    @Column(name = "distance_m", nullable = false)
    private Integer distanceM;
    
    @Column(name = "device_note")
    private String deviceNote;
    
    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (checkedInAt == null) {
            checkedInAt = Instant.now();
        }
    }
}

