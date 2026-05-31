package com.example.evstation.api.ev_user_mobile.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class SwapVerifyRequestDTO {
    @NotBlank
    private String swapCode;
}
