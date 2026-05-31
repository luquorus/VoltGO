package com.example.evstation.api.collaborator_mobile.controller;

import com.example.evstation.api.common.dto.PresignUploadResponseDTO;
import com.example.evstation.api.common.dto.PresignViewResponseDTO;
import com.example.evstation.common.file.FileService;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.verification.application.VerificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@RestController
@RequestMapping("/api/collab/mobile/files")
@RequiredArgsConstructor
@PreAuthorize("hasRole('COLLABORATOR')")
public class CollabMobileFileController {

    private final FileService fileService;
    private final VerificationService verificationService;

    @PostMapping("/presign-upload")
    public ResponseEntity<PresignUploadResponseDTO> getPresignUploadUrl(
            @RequestParam(required = false) String contentType) {

        String objectKey = "collab/uploads/" + UUID.randomUUID() + resolveExtension(contentType);
        String url = fileService.generatePresignedUploadUrl(objectKey, 60);
        Instant expiresAt = Instant.now().plus(60, ChronoUnit.MINUTES);
        return ResponseEntity.ok(new PresignUploadResponseDTO(objectKey, url, expiresAt));
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
