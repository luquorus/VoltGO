package com.example.evstation.storage.api.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;

/**
 * Response DTO for presigned upload URL.
 */
@Data
@Builder
public class PresignUploadResponseDTO {
    /**
     * Object key (path) in the bucket.
     * Client should use this when submitting evidence.
     */
    private String objectKey;
    
    /**
     * Presigned URL for PUT operation.
     * Client should use this to upload the file directly to MinIO.
     */
    private String uploadUrl;
    
    /**
     * URL expiration timestamp.
     */
    private Instant expiresAt;
}

