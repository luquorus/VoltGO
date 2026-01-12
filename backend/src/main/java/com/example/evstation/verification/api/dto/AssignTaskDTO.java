package com.example.evstation.verification.api.dto;

import jakarta.validation.constraints.Email;
import lombok.Data;

import java.util.UUID;

/**
 * DTO for assigning a verification task to a collaborator.
 * Either collaboratorUserId or collaboratorEmail must be provided.
 */
@Data
public class AssignTaskDTO {
    /**
     * Collaborator user ID (preferred - from candidates list)
     */
    private UUID collaboratorUserId;
    
    /**
     * Collaborator email (fallback - for backward compatibility)
     */
    @Email(message = "Invalid email format")
    private String collaboratorEmail;
}

