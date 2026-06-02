package com.example.evstation.verification.api;

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

/**
 * Web API for collaborators to perform battery swap verification tasks.
 */
@Slf4j
@RestController
@Tag(name = "Collaborator Web Battery Swap Verification", description = "Web API for collaborators to perform battery swap station verification tasks")
@RequestMapping("/api/collab/battery-swap/verification")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
public class CollaboratorWebBatterySwapVerificationController {

    private final VerificationService verificationService;

    @Operation(
            summary = "List assigned battery swap verification tasks",
            description = "Get battery swap verification tasks assigned to the current collaborator with optional filters."
    )
    @GetMapping("/tasks")
    public ResponseEntity<Page<BatterySwapVerificationTaskDTO>> getTasks(
            @RequestParam(required = false) VerificationTaskStatus status,
            Pageable pageable,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} getting battery swap web tasks: status={}", userId, status);

        Page<BatterySwapVerificationTaskDTO> tasks = verificationService.getBatterySwapTasksForCollaboratorWeb(
                userId, status, pageable);
        return ResponseEntity.ok(tasks);
    }

    @Operation(
            summary = "Get battery swap task detail",
            description = "Get full details of a specific battery swap verification task including check-in form data."
    )
    @GetMapping("/tasks/{id}")
    public ResponseEntity<BatterySwapVerificationTaskDTO> getTask(
            @PathVariable UUID id,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} getting battery swap task: {}", userId, id);

        return verificationService.getBatterySwapTaskById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
            summary = "Get battery swap task history",
            description = "Get reviewed (completed) battery swap verification tasks for the current collaborator."
    )
    @GetMapping("/tasks/history")
    public ResponseEntity<Page<BatterySwapVerificationTaskDTO>> getHistory(
            Pageable pageable,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} getting battery swap task history", userId);

        Page<BatterySwapVerificationTaskDTO> history = verificationService.getBatterySwapTaskHistory(userId, pageable);
        return ResponseEntity.ok(history);
    }

    @Operation(
            summary = "Submit battery swap check-in",
            description = "Submit check-in data for a battery swap verification task. Must be within 200 meters of station."
    )
    @PostMapping("/tasks/{id}/checkin")
    public ResponseEntity<BatterySwapVerificationTaskDTO> submitCheckin(
            @PathVariable UUID id,
            @Valid @RequestBody BatterySwapCheckinRequestDTO dto,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} submitting battery swap checkin for task {} at ({}, {})",
                userId, id, dto.getLat(), dto.getLng());

        BatterySwapVerificationTaskDTO result = verificationService.batterySwapCheckIn(id, dto, userId);
        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "Submit battery swap evidence",
            description = "Submit evidence photos for a battery swap verification task."
    )
    @PostMapping("/tasks/{id}/evidence")
    public ResponseEntity<BatterySwapVerificationTaskDTO> submitEvidence(
            @PathVariable UUID id,
            @Valid @RequestBody SubmitEvidenceDTO dto,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} submitting battery swap evidence for task {}", userId, id);

        BatterySwapVerificationTaskDTO result = verificationService.batterySwapSubmitEvidence(id, dto, userId);
        return ResponseEntity.ok(result);
    }

    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }
}
