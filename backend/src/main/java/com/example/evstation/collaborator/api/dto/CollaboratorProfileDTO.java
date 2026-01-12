package com.example.evstation.collaborator.api.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
public class CollaboratorProfileDTO {
    private String id;
    private String userAccountId;
    private String email;
    private String fullName;
    private String phone;
    private Instant createdAt;
    private Boolean hasActiveContract;
    
    // Location fields
    private CollaboratorLocationDTO location;
}

