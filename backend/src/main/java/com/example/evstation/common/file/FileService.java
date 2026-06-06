package com.example.evstation.common.file;

import io.minio.*;
import io.minio.http.Method;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class FileService {

    private final MinioClient minioClient;

    @Value("${minio.bucket:voltgo}")
    private String bucketName;

    @Value("${minio.url:http://localhost:9000}")
    private String minioUrl;

    @Value("${minio.public-url:}")
    private String publicMinioUrl;

    @Value("${minio.access-key:admin}")
    private String accessKey;

    @Value("${minio.secret-key:admin123}")
    private String secretKey;

    private MinioClient presignClient;

    @PostConstruct
    public void init() {
        try {
            boolean found = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucketName).build());
            if (!found) {
                log.info("Creating MinIO bucket: {}", bucketName);
                minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucketName).build());
            }
            presignClient = buildPresignClient();
        } catch (Exception e) {
            log.error("Failed to initialize MinIO bucket", e);
        }
    }

    /**
     * Generate a presigned URL for GET operation
     */
    public String generatePresignedViewUrl(String objectKey, int expiryMinutes) {
        try {
            return presignClient.getPresignedObjectUrl(
                    GetPresignedObjectUrlArgs.builder()
                            .method(Method.GET)
                            .bucket(bucketName)
                            .object(objectKey)
                            .expiry(expiryMinutes, java.util.concurrent.TimeUnit.MINUTES)
                            .build()
            );
        } catch (Exception e) {
            log.error("Failed to generate presigned view URL for object: {}", objectKey, e);
            throw new RuntimeException("Could not generate presigned URL", e);
        }
    }

    /**
     * Generate a presigned URL for PUT operation
     */
    public String generatePresignedUploadUrl(String objectKey, int expiryMinutes) {
        try {
            return presignClient.getPresignedObjectUrl(
                    GetPresignedObjectUrlArgs.builder()
                            .method(Method.PUT)
                            .bucket(bucketName)
                            .object(objectKey)
                            .expiry(expiryMinutes, java.util.concurrent.TimeUnit.MINUTES)
                            .build()
            );
        } catch (Exception e) {
            log.error("Failed to generate presigned upload URL for object: {}", objectKey, e);
            throw new RuntimeException("Could not generate presigned URL", e);
        }
    }

    private MinioClient buildPresignClient() {
        String endpoint = (publicMinioUrl != null && !publicMinioUrl.isBlank())
                ? publicMinioUrl
                : minioUrl;
        return MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
    }
}
