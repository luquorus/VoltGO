package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.*;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "station_version")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationVersionEntity {
    @Id
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;

    @Column(name = "version_no", nullable = false)
    private Integer versionNo;

    @Enumerated(EnumType.STRING)
    @Column(name = "workflow_status", nullable = false)
    private WorkflowStatus workflowStatus;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String address;

    // PostGIS geography type - stored as geography(Point,4326)
    // Hibernate Spatial 6.x handles this automatically
    @Column(name = "location", nullable = false, columnDefinition = "geography(Point,4326)")
    private org.locationtech.jts.geom.Point location;

    @Column(name = "operating_hours")
    private String operatingHours;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ParkingType parking;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private VisibilityType visibility;

    @Enumerated(EnumType.STRING)
    @Column(name = "public_status", nullable = false)
    private PublicStatus publicStatus;

    @Column(name = "created_by", nullable = false, columnDefinition = "UUID")
    private UUID createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "published_at")
    private Instant publishedAt;
}

