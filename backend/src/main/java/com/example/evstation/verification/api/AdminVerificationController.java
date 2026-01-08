package com.example.evstation.verification.api;

import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.verification.api.dto.*;
import com.example.evstation.verification.application.VerificationService;
import com.example.evstation.verification.domain.VerificationTaskStatus;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@Tag(name = "Admin Verification", description = "Admin API for managing verification tasks")
@RestController
@RequestMapping("/api/admin/verification-tasks")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminVerificationController {
    
    private final VerificationService verificationService;

    @Operation(summary = "Create a verification task", 
               description = "Create a new verification task for a station. Optionally link to a change request.")
    @PostMapping
    public ResponseEntity<VerificationTaskDTO> createTask(
            @Valid @RequestBody CreateTaskDTO dto,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String role = extractRole(authentication);
        
        log.info("Admin {} creating verification task for station {}", adminId, dto.getStationId());
        
        VerificationTaskDTO result = verificationService.createTask(dto, adminId, role);
        return ResponseEntity.ok(result);
    }

    @Operation(summary = "Assign task to collaborator", 
               description = "Assign an OPEN verification task to a collaborator")
    @PostMapping("/{id}/assign")
    public ResponseEntity<VerificationTaskDTO> assignTask(
            @PathVariable UUID id,
            @Valid @RequestBody AssignTaskDTO dto,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String role = extractRole(authentication);
        
        log.info("Admin {} assigning task {} to {}", adminId, id, dto.getCollaboratorUserId());
        
        VerificationTaskDTO result = verificationService.assignTask(id, dto, adminId, role);
        return ResponseEntity.ok(result);
    }

    @Operation(summary = "Get verification tasks", 
               description = "Get verification tasks with optional status filter")
    @GetMapping
    public ResponseEntity<Page<VerificationTaskDTO>> getTasks(
            @RequestParam(required = false) VerificationTaskStatus status,
            Pageable pageable) {
        
        log.info("Admin getting tasks with status: {}", status);
        
        Page<VerificationTaskDTO> tasks = verificationService.getTasksByStatus(status, pageable);
        return ResponseEntity.ok(tasks);
    }

    @Operation(summary = "Get verification task by ID", 
               description = "Get a specific verification task with all details including evidence and review")
    @GetMapping("/{id}")
    public ResponseEntity<VerificationTaskDTO> getTask(@PathVariable UUID id) {
        log.info("Admin getting task: {}", id);
        
        return verificationService.getTaskById(id)
                .map(ResponseEntity::ok)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Task not found"));
    }

    @Operation(summary = "Review verification task", 
               description = "Review a SUBMITTED verification task as PASS or FAIL")
    @PostMapping("/{id}/review")
    public ResponseEntity<VerificationTaskDTO> reviewTask(
            @PathVariable UUID id,
            @Valid @RequestBody ReviewTaskDTO dto,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String role = extractRole(authentication);
        
        log.info("Admin {} reviewing task {} as {}", adminId, id, dto.getResult());
        
        VerificationTaskDTO result = verificationService.reviewTask(id, dto, adminId, role);
        return ResponseEntity.ok(result);
    }

    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }

    private String extractRole(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .findFirst()
                .map(a -> a.getAuthority().replace("ROLE_", ""))
                .orElse("ADMIN");
    }
}

