package com.example.evstation.verification.api.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
public class CreateTaskDTO {
    @NotNull(message = "Station ID is required")
    private UUID stationId;
    
    private UUID changeRequestId;
    
    @Min(value = 1, message = "Priority must be between 1 and 5")
    @Max(value = 5, message = "Priority must be between 1 and 5")
    private Integer priority = 3;
    
    private Instant slaDueAt;
}

