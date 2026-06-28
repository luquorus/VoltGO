package com.example.evstation.api.admin_web.dto;

import com.example.evstation.station.domain.IssueCategory;
import com.example.evstation.station.domain.IssueStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminIssueResponseDTO {
    private UUID id;
    private UUID stationId;
    private String stationName;
    private UUID reporterId;
    private String reporterEmail;
    private IssueCategory category;
    private String description;
    private IssueStatus status;
    private Instant createdAt;
    private Instant decidedAt;
    private String adminNote;
}
