package com.example.evstation.storage.api;

import com.example.evstation.storage.api.dto.PresignViewResponseDTO;
import com.example.evstation.storage.application.MinIOService;
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
 * Controller for admin file operations (presigned view URLs).
 */
@Slf4j
@Tag(name = "Admin Files", description = "Admin API for file view presigned URLs")
@RestController
@RequestMapping("/api/admin/files")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
@Validated
public class AdminFileController {
    
    private final MinIOService minioService;
    
    private static final int VIEW_URL_EXPIRY_MINUTES = 60;
    
    @Operation(
        summary = "Generate presigned view URL",
        description = "Generate a presigned URL for viewing/downloading files. " +
                     "Admin can view any file by objectKey."
    )
    @GetMapping("/presign-view")
    public ResponseEntity<PresignViewResponseDTO> presignView(
            @RequestParam @NotBlank(message = "Object key is required") String objectKey,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        log.info("Admin {} requesting presigned view URL for objectKey: {}", adminId, objectKey);
        
        // Admin can view any file - no additional checks needed
        String viewUrl = minioService.generatePresignedViewUrl(objectKey, VIEW_URL_EXPIRY_MINUTES);
        Instant expiresAt = Instant.now().plusSeconds(VIEW_URL_EXPIRY_MINUTES * 60);
        
        PresignViewResponseDTO response = PresignViewResponseDTO.builder()
                .viewUrl(viewUrl)
                .expiresAt(expiresAt)
                .build();
        
        log.debug("Generated presigned view URL for admin {}: objectKey={}", adminId, objectKey);
        return ResponseEntity.ok(response);
    }
    
    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }
}

