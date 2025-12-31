package com.example.evstation.station.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "station")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationEntity {
    @Id
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "provider_id", columnDefinition = "UUID")
    private UUID providerId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}

