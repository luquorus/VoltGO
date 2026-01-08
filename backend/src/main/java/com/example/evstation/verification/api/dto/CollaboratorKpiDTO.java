package com.example.evstation.verification.api.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class CollaboratorKpiDTO {
    private Integer totalReviewed;
    private Integer passCount;
    private Integer failCount;
    private Double passRate;
    private String period; // e.g., "2026-01" for monthly
}

