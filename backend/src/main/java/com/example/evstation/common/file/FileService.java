package com.example.evstation.common.file;

import com.example.evstation.api.common.dto.FileDownloadResult;
import io.minio.*;
import io.minio.http.Method;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

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

    /**
     * Upload a file directly to MinIO (backend proxies the upload).
     * Used when clients cannot reach MinIO directly (e.g., mobile on cellular).
     */
    public String uploadFile(MultipartFile file, String objectKey) {
        try (InputStream inputStream = file.getInputStream()) {
            long size = file.getSize();
            String contentType = file.getContentType();
            minioClient.putObject(
                    PutObjectArgs.builder()
                            .bucket(bucketName)
                            .object(objectKey)
                            .stream(inputStream, size, -1)
                            .contentType(contentType != null ? contentType : "application/octet-stream")
                            .build()
            );
            log.info("Uploaded file to MinIO: bucket={}, key={}, size={}", bucketName, objectKey, size);
            return objectKey;
        } catch (Exception e) {
            log.error("Failed to upload file to MinIO: {}", objectKey, e);
            throw new RuntimeException("Could not upload file to storage", e);
        }
    }

    /**
     * Download a file from MinIO and return its bytes and content type.
     * Used by proxy view endpoints to stream files to clients that cannot reach MinIO directly.
     */
    public FileDownloadResult getFile(String objectKey) {
        try (InputStream inputStream = minioClient.getObject(
                GetObjectArgs.builder()
                        .bucket(bucketName)
                        .object(objectKey)
                        .build())) {

            ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            byte[] data = new byte[8192];
            int bytesRead;
            while ((bytesRead = inputStream.read(data, 0, data.length)) != -1) {
                buffer.write(data, 0, bytesRead);
            }

            String contentType = guessContentType(objectKey);
            return new FileDownloadResult(buffer.toByteArray(), contentType);
        } catch (Exception e) {
            log.error("Failed to download file from MinIO: {}", objectKey, e);
            throw new RuntimeException("Could not download file from storage", e);
        }
    }

    private String guessContentType(String objectKey) {
        if (objectKey == null) return "application/octet-stream";
        String lower = objectKey.toLowerCase();
        if (lower.endsWith(".png")) return "image/png";
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
        if (lower.endsWith(".webp")) return "image/webp";
        if (lower.endsWith(".heic")) return "image/heic";
        if (lower.endsWith(".heif")) return "image/heif";
        if (lower.endsWith(".gif")) return "image/gif";
        return "application/octet-stream";
    }
}
