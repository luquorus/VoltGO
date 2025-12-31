package com.example.evstation.api.ev_user_mobile.dto;

import com.example.evstation.station.domain.IssueCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CreateIssueDTO {
    
    @NotNull(message = "Category is required")
    private IssueCategory category;
    
    @NotBlank(message = "Description is required")
    @Size(min = 10, max = 2000, message = "Description must be between 10 and 2000 characters")
    private String description;
}

