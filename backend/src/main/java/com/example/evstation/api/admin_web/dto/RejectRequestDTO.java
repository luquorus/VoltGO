package com.example.evstation.api.admin_web.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class RejectRequestDTO {
    @NotBlank(message = "Rejection reason is required")
    private String reason;
}

