package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.PowerType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "charging_port")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChargingPortEntity {
    @Id
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "station_service_id", nullable = false, columnDefinition = "UUID")
    private UUID stationServiceId;

    @Enumerated(EnumType.STRING)
    @Column(name = "power_type", nullable = false)
    private PowerType powerType;

    @Column(name = "power_kw", precision = 10, scale = 2)
    private BigDecimal powerKw;

    @Column(name = "port_count", nullable = false)
    private Integer portCount;
}

