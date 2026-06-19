package com.example.evstation.api.collaborator_mobile.controller;

import com.example.evstation.api.common.dto.FileDownloadResult;
import com.example.evstation.api.common.dto.PresignViewResponseDTO;
import com.example.evstation.api.common.dto.ProxyUploadResponseDTO;
import com.example.evstation.common.file.FileService;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.verification.application.VerificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/collab/mobile/files")
@RequiredArgsConstructor
@PreAuthorize("hasRole('COLLABORATOR')")
public class CollabMobileFileController {

    private final FileService fileService;
    private final VerificationService verificationService;

    /**
     * Proxy upload endpoint — backend receives the file and forwards to MinIO.
     * Use this when the mobile client cannot reach MinIO directly (e.g., on cellular network).
     * App sends multipart file + contentType, backend returns the objectKey.
     */
    @PostMapping("/upload")
    public ResponseEntity<ProxyUploadResponseDTO> proxyUpload(
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false, defaultValue = "image/jpeg") String contentType,
            Authentication authentication) {

        if (file.isEmpty()) {
            throw new BusinessException(ErrorCode.INVALID_INPUT, "File is empty");
        }

        long maxSizeBytes = 10 * 1024 * 1024; // 10 MB
        if (file.getSize() > maxSizeBytes) {
            throw new BusinessException(ErrorCode.INVALID_INPUT, "File size exceeds 10 MB limit");
        }

        String objectKey = "collab/uploads/" + UUID.randomUUID() + resolveExtension(contentType);
        fileService.uploadFile(file, objectKey);

        log.info("Proxy uploaded file for user {}: key={}, size={}",
                authentication.getName(), objectKey, file.getSize());
        return ResponseEntity.ok(new ProxyUploadResponseDTO(objectKey));
    }

    @GetMapping("/presign-view")
    public ResponseEntity<PresignViewResponseDTO> getPresignViewUrl(
            @RequestParam(required = false) String objectKey,
            Authentication authentication) {

        if (objectKey == null || objectKey.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        UUID userId = UUID.fromString(authentication.getName());
        if (!verificationService.canCollaboratorViewEvidenceObject(userId, objectKey)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "You cannot view this evidence file");
        }

        String url = fileService.generatePresignedViewUrl(objectKey, 60);
        Instant expiresAt = Instant.now().plus(60, ChronoUnit.MINUTES);
        return ResponseEntity.ok(new PresignViewResponseDTO(url, expiresAt));
    }

    /**
     * Proxy view endpoint — backend streams file from MinIO to client.
     * Use this when the mobile client cannot reach MinIO directly (e.g., on cellular network).
     * Same authorization as presign-view: collaborator must be assigned to the task owning the evidence.
     */
    @GetMapping("/view")
    public ResponseEntity<Resource> viewFile(
            @RequestParam String objectKey,
            Authentication authentication) {

        if (objectKey == null || objectKey.isBlank()) {
            throw new BusinessException(ErrorCode.INVALID_INPUT, "objectKey is required");
        }

        UUID userId = UUID.fromString(authentication.getName());
        if (!verificationService.canCollaboratorViewEvidenceObject(userId, objectKey)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "You cannot view this evidence file");
        }

        FileDownloadResult result = fileService.getFile(objectKey);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType(result.getContentType()));
        headers.setContentLength(result.getData().length);

        ByteArrayResource resource = new ByteArrayResource(result.getData());
        return ResponseEntity.ok()
                .headers(headers)
                .body(resource);
    }

    private String resolveExtension(String contentType) {
        if (contentType == null) {
            return ".jpg";
        }
        String normalized = contentType.trim().toLowerCase();
        return switch (normalized) {
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            case "image/heic" -> ".heic";
            case "image/heif" -> ".heif";
            default -> ".jpg";
        };
    }
}
