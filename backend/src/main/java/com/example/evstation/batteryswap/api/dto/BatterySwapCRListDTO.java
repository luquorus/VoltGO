package com.example.evstation.batteryswap.api.dto;

import com.example.evstation.batteryswap.domain.ChangeRequestStatus;
import com.example.evstation.batteryswap.domain.ChangeRequestType;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class BatterySwapCRListDTO {

    private UUID id;
    private ChangeRequestType type;
    private ChangeRequestStatus status;
    private UUID stationId;
    private String stationName;
    private Integer riskScore;
    private Instant createdAt;
    private Instant submittedAt;
    private UUID submittedBy;
    private String submittedByEmail;
}
