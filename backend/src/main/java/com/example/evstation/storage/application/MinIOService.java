package com.example.evstation.storage.application;

import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.SetBucketPolicyArgs;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

/**
 * Service for MinIO operations (S3-compatible object storage).
 * Handles bucket creation and presigned URL generation.
 * 
 * IMPORTANT: Presigned URL signatures include the hostname. The hostname used when
 * generating the URL MUST match the hostname the client uses to upload.
 * 
 * For Docker environments:
 * - Backend connects to MinIO via 'minio:9000' (Docker network)
 * - Presigned URLs will contain 'minio:9000'
 * - Client must resolve 'minio' to 127.0.0.1 (add to hosts file)
 * 
 * Alternative: Set MINIO_PUBLIC_ENDPOINT to same as MINIO_ENDPOINT if both
 * backend and client use the same hostname.
 */
@Slf4j
@Service
public class MinIOService implements CommandLineRunner {
    
    private final MinioClient minioClient; // Internal client for all MinIO operations
    private final String bucketName;
    private final String region;
    private final String publicEndpoint; // Public endpoint for replacing hostname in presigned URLs
    
    public MinIOService(
            MinioClient minioClient,
            @org.springframework.beans.factory.annotation.Qualifier("publicMinioClient") @SuppressWarnings("unused") MinioClient publicMinioClient,
            @Value("${MINIO_BUCKET:voltgo-evidence}") String bucketName,
            @Value("${MINIO_REGION:us-east-1}") String region,
            @Value("${MINIO_PUBLIC_ENDPOINT:${MINIO_ENDPOINT}}") String publicEndpoint) {
        this.minioClient = minioClient;
        this.bucketName = bucketName;
        this.region = region;
        this.publicEndpoint = publicEndpoint;
        log.info("MinIOService initialized: bucket={}, publicEndpoint={}", bucketName, publicEndpoint);
    }
    
    /**
     * Ensure bucket exists on startup.
     */
    @Override
    public void run(String... args) {
        try {
            boolean exists = minioClient.bucketExists(BucketExistsArgs.builder()
                    .bucket(bucketName)
                    .build());
            
            if (!exists) {
                log.info("Bucket '{}' does not exist. Creating...", bucketName);
                minioClient.makeBucket(MakeBucketArgs.builder()
                        .bucket(bucketName)
                        .region(region)
                        .build());
                log.info("Bucket '{}' created successfully", bucketName);
            } else {
                log.info("Bucket '{}' already exists", bucketName);
            }
            
            // Set bucket policy to allow presigned URL uploads/downloads (for both new and existing buckets)
            try {
                String policyJson = String.format("""
                    {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Principal": {"AWS": ["*"]},
                          "Action": [
                            "s3:GetObject",
                            "s3:PutObject"
                          ],
                          "Resource": ["arn:aws:s3:::%s/*"]
                        }
                      ]
                    }
                    """, bucketName);
                
                minioClient.setBucketPolicy(SetBucketPolicyArgs.builder()
                        .bucket(bucketName)
                        .config(policyJson)
                        .build());
                log.info("Bucket policy set for '{}' to allow presigned URL operations", bucketName);
            } catch (Exception e) {
                log.warn("Failed to set bucket policy for '{}': {}. Presigned URLs may not work. " +
                        "Please set bucket policy manually in MinIO console.", 
                        bucketName, e.getMessage());
                // Don't fail startup - policy might be set manually
            }
        } catch (Exception e) {
            log.error("Failed to check/create bucket '{}': {}", bucketName, e.getMessage(), e);
            // Don't fail startup - bucket might be created manually
        }
    }
    
    /**
     * Generate presigned upload URL for PUT operation.
     * 
     * Note: The URL will contain the MinIO hostname as configured in MINIO_ENDPOINT.
     * Clients must be able to resolve this hostname (e.g., add 'minio' to hosts file
     * if using Docker with hostname 'minio').
     * 
     * @param objectKey The object key (path) in the bucket
     * @param contentType Optional content type (e.g., "image/jpeg") - for reference only, not enforced
     * @param expiresInMinutes URL expiration time in minutes (default: 15)
     * @return Presigned URL string
     */
    public String generatePresignedUploadUrl(String objectKey, String contentType, int expiresInMinutes) {
        try {
            Duration expiration = Duration.ofMinutes(expiresInMinutes);
            
            // Use minioClient (connects to minio:9000) to generate presigned URL
            // Then replace hostname with publicEndpoint (localhost:9000) for clients
            String url = minioClient.getPresignedObjectUrl(
                    io.minio.GetPresignedObjectUrlArgs.builder()
                            .method(io.minio.http.Method.PUT)
                            .bucket(bucketName)
                            .object(objectKey)
                            .expiry((int) expiration.getSeconds())
                            .build());
            
            // Replace hostname in URL with public endpoint for client access
            // Extract hostname from publicEndpoint (e.g., "http://localhost:9000" -> "localhost:9000")
            java.net.URL publicUrl = new java.net.URL(publicEndpoint);
            String publicHost = publicUrl.getHost() + (publicUrl.getPort() != -1 ? ":" + publicUrl.getPort() : "");
            
            // Replace hostname in presigned URL
            java.net.URL originalUrl = new java.net.URL(url);
            String replacedUrl = url.replace(originalUrl.getHost() + (originalUrl.getPort() != -1 ? ":" + originalUrl.getPort() : ""), publicHost);
            
            log.debug("Generated presigned upload URL for objectKey: {}, contentType: {}, expires in {} minutes. Original: {}, Replaced: {}", 
                    objectKey, contentType, expiresInMinutes, url, replacedUrl);
            
            return replacedUrl;
        } catch (Exception e) {
            log.error("Failed to generate presigned upload URL for objectKey: {}", objectKey, e);
            throw new RuntimeException("Failed to generate presigned upload URL", e);
        }
    }
    
    /**
     * Generate presigned view/download URL for GET operation.
     * 
     * @param objectKey The object key (path) in the bucket
     * @param expiresInMinutes URL expiration time in minutes (default: 60)
     * @return Presigned URL string
     */
    public String generatePresignedViewUrl(String objectKey, int expiresInMinutes) {
        try {
            Duration expiration = Duration.ofMinutes(expiresInMinutes);
            
            // Use minioClient to generate presigned URL, then replace hostname with publicEndpoint
            String url = minioClient.getPresignedObjectUrl(
                    io.minio.GetPresignedObjectUrlArgs.builder()
                            .method(io.minio.http.Method.GET)
                            .bucket(bucketName)
                            .object(objectKey)
                            .expiry((int) expiration.getSeconds())
                            .build());
            
            // Replace hostname in URL with public endpoint for client access
            java.net.URL publicUrl = new java.net.URL(publicEndpoint);
            String publicHost = publicUrl.getHost() + (publicUrl.getPort() != -1 ? ":" + publicUrl.getPort() : "");
            
            java.net.URL originalUrl = new java.net.URL(url);
            String replacedUrl = url.replace(originalUrl.getHost() + (originalUrl.getPort() != -1 ? ":" + originalUrl.getPort() : ""), publicHost);
            
            log.debug("Generated presigned view URL for objectKey: {}, expires in {} minutes", 
                    objectKey, expiresInMinutes);
            
            return replacedUrl;
        } catch (Exception e) {
            log.error("Failed to generate presigned view URL for objectKey: {}", objectKey, e);
            throw new RuntimeException("Failed to generate presigned view URL", e);
        }
    }
    
    /**
     * Generate a unique object key for evidence photos.
     * Format: verification/task-{taskId}/{timestamp}-{uuid}.{extension}
     * 
     * @param taskId Verification task ID
     * @param extension File extension (e.g., "jpg", "png")
     * @return Object key string
     */
    public String generateEvidenceObjectKey(UUID taskId, String extension) {
        String timestamp = String.valueOf(Instant.now().toEpochMilli());
        String uuid = UUID.randomUUID().toString().substring(0, 8);
        String ext = extension != null && !extension.isEmpty() ? extension : "jpg";
        return String.format("verification/task-%s/%s-%s.%s", taskId, timestamp, uuid, ext);
    }
    
    /**
     * Check if object exists in bucket.
     */
    public boolean objectExists(String objectKey) {
        try {
            minioClient.statObject(io.minio.StatObjectArgs.builder()
                    .bucket(bucketName)
                    .object(objectKey)
                    .build());
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}

