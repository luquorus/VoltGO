package com.example.evstation.api.admin_web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuditLogResponseDTO {
    private UUID id;
    private UUID actorId;
    private String actorRole;
    private String actorEmail;
    private String action;
    private String entityType;
    private UUID entityId;
    private Map<String, Object> metadata;
    private Instant createdAt;
}
