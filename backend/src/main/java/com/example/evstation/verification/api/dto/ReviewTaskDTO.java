package com.example.evstation.verification.api.dto;

import com.example.evstation.verification.domain.VerificationResult;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class ReviewTaskDTO {
    @NotNull(message = "Result is required")
    private VerificationResult result;
    
    private String adminNote;
}

