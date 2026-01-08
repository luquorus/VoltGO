package com.example.evstation.verification.api;

import com.example.evstation.verification.api.dto.*;
import com.example.evstation.verification.application.VerificationService;
import com.example.evstation.verification.domain.VerificationTaskStatus;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Slf4j
@Tag(name = "Collaborator Mobile Verification", description = "Mobile API for collaborators to perform verification tasks")
@RestController
@RequestMapping("/api/collab/mobile/tasks")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
public class CollaboratorMobileVerificationController {
    
    private final VerificationService verificationService;

    @Operation(summary = "Get assigned tasks for mobile", 
               description = "Get verification tasks assigned to the current collaborator with status ASSIGNED, CHECKED_IN, or SUBMITTED")
    @GetMapping
    public ResponseEntity<List<VerificationTaskDTO>> getTasks(
            @RequestParam(required = false) List<VerificationTaskStatus> status,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} getting mobile tasks", userId);
        
        // Default to ASSIGNED, CHECKED_IN, SUBMITTED if not specified
        List<VerificationTaskStatus> statuses = status != null && !status.isEmpty() 
                ? status 
                : List.of(
                    VerificationTaskStatus.ASSIGNED, 
                    VerificationTaskStatus.CHECKED_IN, 
                    VerificationTaskStatus.SUBMITTED);
        
        List<VerificationTaskDTO> tasks = verificationService.getTasksForCollaboratorMobile(userId, statuses);
        return ResponseEntity.ok(tasks);
    }

    @Operation(summary = "Check-in at station", 
               description = "Check-in at the station location. Must be within 200 meters of the published station location. Requires task status to be ASSIGNED.")
    @PostMapping("/{id}/check-in")
    public ResponseEntity<VerificationTaskDTO> checkIn(
            @PathVariable UUID id,
            @Valid @RequestBody CheckinDTO dto,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} checking in for task {} at ({}, {})", 
                userId, id, dto.getLat(), dto.getLng());
        
        VerificationTaskDTO result = verificationService.checkIn(id, dto, userId);
        return ResponseEntity.ok(result);
    }

    @Operation(summary = "Submit verification evidence", 
               description = "Submit photo evidence for the verification task. Requires task status to be CHECKED_IN and collaborator must have active contract.")
    @PostMapping("/{id}/submit-evidence")
    public ResponseEntity<VerificationTaskDTO> submitEvidence(
            @PathVariable UUID id,
            @Valid @RequestBody SubmitEvidenceDTO dto,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} submitting evidence for task {}", userId, id);
        
        VerificationTaskDTO result = verificationService.submitEvidence(id, dto, userId);
        return ResponseEntity.ok(result);
    }

    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }
}

