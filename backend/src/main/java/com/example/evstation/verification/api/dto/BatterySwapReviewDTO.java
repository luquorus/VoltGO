package com.example.evstation.verification.api.dto;

import com.example.evstation.verification.domain.VerificationResult;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * DTO for battery swap verification review request.
 */
@Data
public class BatterySwapReviewDTO {
    @NotNull(message = "Result is required")
    private VerificationResult result;

    private String adminNote;

    private String riskConfirmed;
}
