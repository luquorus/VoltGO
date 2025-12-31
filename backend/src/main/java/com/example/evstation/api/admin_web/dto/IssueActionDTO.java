package com.example.evstation.api.admin_web.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class IssueActionDTO {
    
    @NotBlank(message = "Note/reason is required")
    private String note;
}

