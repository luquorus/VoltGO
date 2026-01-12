package com.example.evstation.api.ev_user_mobile.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

/**
 * DTO for updating change request image URLs.
 */
@Data
public class UpdateChangeRequestDTO {
    
    @NotNull(message = "Image URLs list is required")
    private List<String> imageUrls;
}

