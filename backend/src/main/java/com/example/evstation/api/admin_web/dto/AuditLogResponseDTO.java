package com.example.evstation.api.admin_web.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Data
@Builder
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

