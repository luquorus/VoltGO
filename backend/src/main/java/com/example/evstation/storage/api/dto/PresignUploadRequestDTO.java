package com.example.evstation.storage.api.dto;

import lombok.Data;

/**
 * Request DTO for presigned upload URL generation.
 */
@Data
public class PresignUploadRequestDTO {
    /**
     * Optional content type (e.g., "image/jpeg", "image/png").
     * If not provided, default will be used.
     */
    private String contentType;
}

