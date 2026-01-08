package com.example.evstation.collaborator.api.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.util.UUID;

@Data
public class CreateContractDTO {
    @NotNull(message = "Collaborator ID is required")
    private UUID collaboratorId;
    
    private String region;
    
    @NotNull(message = "Start date is required")
    private LocalDate startDate;
    
    @NotNull(message = "End date is required")
    private LocalDate endDate;
    
    private String note;
}

