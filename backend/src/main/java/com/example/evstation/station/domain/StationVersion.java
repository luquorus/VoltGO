package com.example.evstation.station.domain;

import java.time.Instant;
import java.util.UUID;

public class StationVersion {
    private final UUID id;
    private final UUID stationId;
    private final int versionNo;
    private final WorkflowStatus workflowStatus;
    private final String name;
    private final String address;
    private final double latitude;
    private final double longitude;
    private final String operatingHours;
    private final ParkingType parking;
    private final VisibilityType visibility;
    private final PublicStatus publicStatus;
    private final UUID createdBy;
    private final Instant createdAt;
    private final Instant publishedAt;

    public StationVersion(
            UUID id,
            UUID stationId,
            int versionNo,
            WorkflowStatus workflowStatus,
            String name,
            String address,
            double latitude,
            double longitude,
            String operatingHours,
            ParkingType parking,
            VisibilityType visibility,
            PublicStatus publicStatus,
            UUID createdBy,
            Instant createdAt,
            Instant publishedAt) {
        this.id = id;
        this.stationId = stationId;
        this.versionNo = versionNo;
        this.workflowStatus = workflowStatus;
        this.name = name;
        this.address = address;
        this.latitude = latitude;
        this.longitude = longitude;
        this.operatingHours = operatingHours;
        this.parking = parking;
        this.visibility = visibility;
        this.publicStatus = publicStatus;
        this.createdBy = createdBy;
        this.createdAt = createdAt;
        this.publishedAt = publishedAt;
    }

    public boolean isPublished() {
        return workflowStatus == WorkflowStatus.PUBLISHED;
    }

    public UUID getId() {
        return id;
    }

    public UUID getStationId() {
        return stationId;
    }

    public int getVersionNo() {
        return versionNo;
    }

    public WorkflowStatus getWorkflowStatus() {
        return workflowStatus;
    }

    public String getName() {
        return name;
    }

    public String getAddress() {
        return address;
    }

    public double getLatitude() {
        return latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public String getOperatingHours() {
        return operatingHours;
    }

    public ParkingType getParking() {
        return parking;
    }

    public VisibilityType getVisibility() {
        return visibility;
    }

    public PublicStatus getPublicStatus() {
        return publicStatus;
    }

    public UUID getCreatedBy() {
        return createdBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getPublishedAt() {
        return publishedAt;
    }
}

