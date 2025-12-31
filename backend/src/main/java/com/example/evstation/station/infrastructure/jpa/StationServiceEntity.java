package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.ServiceType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Entity
@Table(name = "station_service")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationServiceEntity {
    @Id
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "station_version_id", nullable = false, columnDefinition = "UUID")
    private UUID stationVersionId;

    @Enumerated(EnumType.STRING)
    @Column(name = "service_type", nullable = false)
    private ServiceType serviceType;
}

