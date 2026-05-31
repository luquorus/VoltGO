package com.example.evstation.verification.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class SubmitEvidenceDTO {
    @NotBlank(message = "Photo object key is required")
    private String photoObjectKey;

    @Size(max = 1000, message = "Note must be at most 1000 characters")
    private String note;
}
