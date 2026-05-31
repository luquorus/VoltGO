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
public class PresignUploadResponseDTO {
    private String objectKey;
    private String uploadUrl;
    private Instant expiresAt;
}
