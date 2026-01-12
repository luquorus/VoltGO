package com.example.evstation.collaborator.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.locationtech.jts.geom.Point;

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
    
    @Column(name = "current_location", columnDefinition = "geography(Point, 4326)")
    private Point currentLocation;
    
    @Column(name = "location_updated_at")
    private Instant locationUpdatedAt;
    
    @Column(name = "location_source")
    @Enumerated(EnumType.STRING)
    private LocationSource locationSource;
    
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
    
    /**
     * Get latitude from location point
     */
    public Double getLatitude() {
        return currentLocation != null ? currentLocation.getY() : null;
    }
    
    /**
     * Get longitude from location point
     */
    public Double getLongitude() {
        return currentLocation != null ? currentLocation.getX() : null;
    }
}

