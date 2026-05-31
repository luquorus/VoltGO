package com.example.evstation.api.common.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PresignViewResponseDTO {
    private String viewUrl;
    private Instant expiresAt;
}
