package com.example.evstation.storage.api.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;

/**
 * Response DTO for presigned view URL.
 */
@Data
@Builder
public class PresignViewResponseDTO {
    /**
     * Presigned URL for GET operation.
     * Client should use this to view/download the file from MinIO.
     */
    private String viewUrl;
    
    /**
     * URL expiration timestamp.
     */
    private Instant expiresAt;
}

