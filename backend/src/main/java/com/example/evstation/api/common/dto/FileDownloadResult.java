package com.example.evstation.api.common.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

/**
 * Result of downloading a file from MinIO via the backend proxy.
 */
@Data
@AllArgsConstructor
public class FileDownloadResult {
    private byte[] data;
    private String contentType;
}
