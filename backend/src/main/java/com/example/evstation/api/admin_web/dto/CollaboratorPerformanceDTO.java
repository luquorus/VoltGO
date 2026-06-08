package com.example.evstation.api.admin_web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CollaboratorPerformanceDTO {
    private UUID collaboratorId;
    private String fullName;
    private long totalTasks;
    private double passRate;
    private double avgCompletionTimeHours;
    private double avgDistanceMeters;
    private double slaComplianceRate;
}
