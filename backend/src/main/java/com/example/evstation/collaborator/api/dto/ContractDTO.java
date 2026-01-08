package com.example.evstation.collaborator.api.dto;

import com.example.evstation.collaborator.domain.ContractStatus;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.time.LocalDate;

@Data
@Builder
public class ContractDTO {
    private String id;
    private String collaboratorId;
    private String collaboratorName;
    private String region;
    private LocalDate startDate;
    private LocalDate endDate;
    private ContractStatus status;
    private Instant createdAt;
    private Instant terminatedAt;
    private String note;
    private Boolean isEffectivelyActive;
}

