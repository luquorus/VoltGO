package com.example.evstation.batteryswap.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "battery_swap_station_device")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationDeviceEntity {

    @Id
    @Column(name = "station_id", columnDefinition = "UUID")
    private UUID stationId;

    @Column(name = "device_key", nullable = false, unique = true, length = 64)
    private String deviceKey;

    @Column(name = "device_name", length = 100)
    private String deviceName;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "last_seen_at")
    private Instant lastSeenAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
