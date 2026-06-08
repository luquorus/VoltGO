package com.example.evstation.api.admin_web.dto;

import com.example.evstation.station.domain.ServiceType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrustOverviewDTO {
    private UUID stationId;
    private String name;
    private String address;
    private Integer trustScore;
    private ServiceType serviceType;
}
