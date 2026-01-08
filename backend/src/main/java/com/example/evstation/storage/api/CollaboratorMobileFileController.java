package com.example.evstation.storage.api;

import com.example.evstation.storage.api.dto.PresignUploadRequestDTO;
import com.example.evstation.storage.api.dto.PresignUploadResponseDTO;
import com.example.evstation.storage.application.MinIOService;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * Controller for collaborator mobile file operations (presigned upload URLs).
 */
@Slf4j
@Tag(name = "Collaborator Mobile Files", description = "Mobile API for file upload presigned URLs")
@RestController
@RequestMapping("/api/collab/mobile/files")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
public class CollaboratorMobileFileController {
    
    private final MinIOService minioService;
    private final AuditLogJpaRepository auditLogRepository;
    
    private static final int UPLOAD_URL_EXPIRY_MINUTES = 15;
    
    @Operation(
        summary = "Generate presigned upload URL",
        description = "Generate a presigned URL for uploading evidence photos. " +
                     "Client should use this URL to upload file directly to MinIO, then submit evidence with objectKey."
    )
    @PostMapping("/presign-upload")
    public ResponseEntity<PresignUploadResponseDTO> presignUpload(
            @RequestBody(required = false) PresignUploadRequestDTO request,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} requesting presigned upload URL", userId);
        
        // Generate object key (without taskId for now - can be enhanced later)
        // Format: verification/uploads/{userId}/{timestamp}-{uuid}.jpg
        String timestamp = String.valueOf(Instant.now().toEpochMilli());
        String uuid = UUID.randomUUID().toString().substring(0, 8);
        String objectKey = String.format("verification/uploads/%s/%s-%s.jpg", userId, timestamp, uuid);
        
        // Generate presigned URL
        String contentType = request != null && request.getContentType() != null 
                ? request.getContentType() 
                : "image/jpeg";
        
        String uploadUrl = minioService.generatePresignedUploadUrl(
                objectKey, 
                contentType, 
                UPLOAD_URL_EXPIRY_MINUTES);
        
        Instant expiresAt = Instant.now().plusSeconds(UPLOAD_URL_EXPIRY_MINUTES * 60);
        
        PresignUploadResponseDTO response = PresignUploadResponseDTO.builder()
                .objectKey(objectKey)
                .uploadUrl(uploadUrl)
                .expiresAt(expiresAt)
                .build();
        
        // Audit log
        writeAuditLog(userId, "COLLABORATOR", "PRESIGN_UPLOAD", "FILE", null,
                Map.of("objectKey", objectKey, "expiresAt", expiresAt.toString()));
        
        log.info("Generated presigned upload URL for collaborator {}: objectKey={}", userId, objectKey);
        return ResponseEntity.ok(response);
    }
    
    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }
    
    private void writeAuditLog(UUID actorId, String actorRole, String action, 
                               String entityType, UUID entityId, Map<String, Object> metadata) {
        AuditLogEntity auditLog = AuditLogEntity.builder()
                .actorId(actorId)
                .actorRole(actorRole)
                .action(action)
                .entityType(entityType)
                .entityId(entityId)
                .metadata(metadata)
                .createdAt(Instant.now())
                .build();
        auditLogRepository.save(auditLog);
        log.debug("Audit log written: action={}, entityType={}", action, entityType);
    }
}

