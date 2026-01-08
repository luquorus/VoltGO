package com.example.evstation.storage.api;

import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.storage.api.dto.PresignViewResponseDTO;
import com.example.evstation.storage.application.MinIOService;
import com.example.evstation.verification.infrastructure.jpa.VerificationEvidenceEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationEvidenceJpaRepository;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskJpaRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.constraints.NotBlank;

import java.time.Instant;
import java.util.UUID;

/**
 * Controller for collaborator web file operations (presigned view URLs).
 */
@Slf4j
@Tag(name = "Collaborator Web Files", description = "Web API for file view presigned URLs")
@RestController
@RequestMapping("/api/collab/web/files")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
@Validated
public class CollaboratorWebFileController {
    
    private final MinIOService minioService;
    private final VerificationEvidenceJpaRepository evidenceRepository;
    private final VerificationTaskJpaRepository taskRepository;
    
    private static final int VIEW_URL_EXPIRY_MINUTES = 60;
    
    @Operation(
        summary = "Generate presigned view URL",
        description = "Generate a presigned URL for viewing/downloading files. " +
                     "Collaborator can only view evidence photos belonging to their assigned tasks."
    )
    @GetMapping("/presign-view")
    public ResponseEntity<PresignViewResponseDTO> presignView(
            @RequestParam @NotBlank(message = "Object key is required") String objectKey,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} requesting presigned view URL for objectKey: {}", userId, objectKey);
        
        // Security check: collaborator can only view evidence from their assigned tasks
        if (!canViewEvidence(userId, objectKey)) {
            log.warn("Collaborator {} attempted to view unauthorized evidence: objectKey={}", userId, objectKey);
            throw new BusinessException(ErrorCode.FORBIDDEN, 
                    "You can only view evidence photos from your assigned verification tasks.");
        }
        
        String viewUrl = minioService.generatePresignedViewUrl(objectKey, VIEW_URL_EXPIRY_MINUTES);
        Instant expiresAt = Instant.now().plusSeconds(VIEW_URL_EXPIRY_MINUTES * 60);
        
        PresignViewResponseDTO response = PresignViewResponseDTO.builder()
                .viewUrl(viewUrl)
                .expiresAt(expiresAt)
                .build();
        
        log.debug("Generated presigned view URL for collaborator {}: objectKey={}", userId, objectKey);
        return ResponseEntity.ok(response);
    }
    
    /**
     * Check if collaborator can view evidence with given objectKey.
     * Phase 1: Simple check - evidence must belong to a task assigned to the collaborator.
     */
    private boolean canViewEvidence(UUID collaboratorUserId, String objectKey) {
        // Find evidence by objectKey
        VerificationEvidenceEntity evidence = evidenceRepository.findByPhotoObjectKey(objectKey)
                .orElse(null);
        
        if (evidence == null) {
            log.debug("Evidence not found for objectKey: {}", objectKey);
            return false;
        }
        
        // Check if task is assigned to this collaborator
        VerificationTaskEntity task = taskRepository.findById(evidence.getTaskId())
                .orElse(null);
        
        if (task == null) {
            log.debug("Task not found for evidence: taskId={}", evidence.getTaskId());
            return false;
        }
        
        boolean canView = collaboratorUserId.equals(task.getAssignedTo());
        log.debug("Collaborator {} can view evidence {} (task: {}): {}", 
                collaboratorUserId, objectKey, task.getId(), canView);
        return canView;
    }
    
    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }
}

