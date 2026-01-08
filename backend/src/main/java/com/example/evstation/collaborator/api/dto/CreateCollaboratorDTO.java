package com.example.evstation.collaborator.api.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class CreateCollaboratorDTO {
    @NotNull(message = "User account ID is required")
    private UUID userAccountId;
    
    private String fullName;
    private String phone;
}

