package com.example.evstation.verification.api.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class AssignTaskDTO {
    @NotNull(message = "Collaborator user ID is required")
    private UUID collaboratorUserId;
}

