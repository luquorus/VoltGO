package com.example.evstation.storage.config;

import io.minio.MinioClient;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * MinIO configuration for S3-compatible object storage.
 * Used for storing verification evidence photos.
 * 
 * IMPORTANT: Presigned URL signatures include the hostname from MINIO_ENDPOINT.
 * Clients must be able to resolve this hostname. For Docker environments:
 * - If MINIO_ENDPOINT=http://minio:9000, clients need 'minio' in their hosts file
 *   pointing to 127.0.0.1 (or the actual MinIO host IP)
 * - Alternatively, use MINIO_ENDPOINT=http://localhost:9000 if MinIO is exposed
 *   on localhost and backend runs on the same host (not in Docker)
 */
@Slf4j
@Configuration
public class MinIOConfig {
    
    @Value("${MINIO_ENDPOINT}")
    private String endpoint;
    
    @Value("${MINIO_ACCESS_KEY}")
    private String accessKey;
    
    @Value("${MINIO_SECRET_KEY}")
    private String secretKey;
    
    @Bean
    public MinioClient minioClient() {
        log.info("Initializing MinIO client: endpoint={}", endpoint);
        
        MinioClient client = MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
        
        log.info("MinIO client initialized successfully. Presigned URLs will use host: {}", endpoint);
        return client;
    }
}

