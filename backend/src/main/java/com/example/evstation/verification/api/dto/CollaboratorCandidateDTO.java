package com.example.evstation.verification.api.dto;

import com.example.evstation.collaborator.api.dto.CollaboratorLocationDTO;
import lombok.Builder;
import lombok.Data;

/**
 * DTO for collaborator candidate in the candidates list for task assignment.
 */
@Data
@Builder
public class CollaboratorCandidateDTO {
    private String collaboratorUserId;
    private String profileId;
    private String fullName;
    private String phone;
    private Boolean contractActive;

    // Location info
    private CollaboratorLocationDTO location;

    // Distance to station in meters (null if location not available)
    private Integer distanceMeters;

    // Workload statistics
    private CandidateStatsDTO stats;

    /**
     * True when this collaborator submitted the change request that
     * originated the task — admin UI must disable assignment in that case
     * (conflict of interest).
     */
    private Boolean isCrSubmitter;

    @Data
    @Builder
    public static class CandidateStatsDTO {
        private Integer completed;      // REVIEWED count
        private Integer active;         // ASSIGNED|CHECKED_IN|SUBMITTED count
        private Integer failedOrOverdue; // FAIL count in last 30d OR overdue tasks
    }
}

