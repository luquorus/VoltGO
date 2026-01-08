package com.example.evstation.verification.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class SubmitEvidenceDTO {
    @NotBlank(message = "Photo object key is required")
    private String photoObjectKey;
    
    private String note;
}

