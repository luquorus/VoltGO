package com.example.evstation.verification.api;

import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.verification.api.dto.*;
import com.example.evstation.verification.application.CollaboratorCandidateQueryService;
import com.example.evstation.verification.application.VerificationService;
import com.example.evstation.verification.domain.VerificationTaskStatus;
import com.example.evstation.verification.domain.VerificationType;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
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
 * Admin API for battery swap verification tasks.
 */
@Slf4j
@RestController
@Tag(name = "Admin Battery Swap Verification", description = "Admin API for managing battery swap station verification tasks")
@RequestMapping("/api/admin/battery-swap/verification")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminBatterySwapVerificationController {

    private final VerificationService verificationService;
    private final CollaboratorCandidateQueryService candidateQueryService;

    @Operation(
            summary = "List all battery swap verification tasks",
            description = "Get all battery swap verification tasks with optional status filter (paginated)."
    )
    @GetMapping("/tasks")
    public ResponseEntity<Page<BatterySwapVerificationTaskDTO>> listTasks(
            @Parameter(description = "Filter by status: OPEN, ASSIGNED, CHECKED_IN, SUBMITTED, REVIEWED")
            @RequestParam(required = false) VerificationTaskStatus status,
            @org.springframework.data.web.PageableDefault(size = 20) Pageable pageable) {

        log.info("Admin listing battery swap verification tasks: status={}", status);
        Page<BatterySwapVerificationTaskDTO> page = verificationService.getBatterySwapTasksByStatus(status, pageable);
        return ResponseEntity.ok(page);
    }

    @Operation(
            summary = "Get battery swap verification task detail",
            description = "Get full details of a specific battery swap verification task by ID."
    )
    @GetMapping("/tasks/{id}")
    public ResponseEntity<BatterySwapVerificationTaskDTO> getTask(
            @Parameter(description = "Task ID", required = true)
            @PathVariable UUID id) {

        log.info("Admin getting battery swap verification task: id={}", id);
        return verificationService.getBatterySwapTaskById(id)
                .map(ResponseEntity::ok)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Task not found"));
    }

    @Operation(
            summary = "Create a battery swap verification task manually",
            description = "Create a new battery swap verification task for a station. Optionally assign to a collaborator."
    )
    @PostMapping("/tasks")
    public ResponseEntity<BatterySwapVerificationTaskDTO> createTask(
            @Valid @RequestBody CreateBatterySwapTaskDTO dto,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        String role = extractRole(authentication);

        log.info("Admin {} creating battery swap verification task for station {}", adminId, dto.getStationId());

        BatterySwapVerificationTaskDTO result = verificationService.createBatterySwapVerificationTask(
                dto.getStationId(), dto.getVersionId(), dto.getAssigneeId(), adminId, role);

        if (dto.getAssigneeId() != null) {
            result = verificationService.assignBatterySwapTask(result.getId() != null
                    ? UUID.fromString(result.getId()) : null, dto.getAssigneeId(), adminId, role);
        }

        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "Assign battery swap verification task to collaborator",
            description = "Assign an OPEN battery swap verification task to a collaborator by user ID."
    )
    @PutMapping("/tasks/{id}/assign")
    public ResponseEntity<BatterySwapVerificationTaskDTO> assignTask(
            @Parameter(description = "Task ID", required = true)
            @PathVariable UUID id,
            @Valid @RequestBody AssignTaskDTO dto,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        String role = extractRole(authentication);

        if (dto.getCollaboratorUserId() == null && dto.getCollaboratorEmail() == null) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Either collaboratorUserId or collaboratorEmail is required");
        }

        UUID collaboratorUserId = dto.getCollaboratorUserId();
        if (collaboratorUserId == null) {
            collaboratorUserId = candidateQueryService.findUserIdByEmail(dto.getCollaboratorEmail());
        }

        log.info("Admin {} assigning battery swap task {} to user {}", adminId, id, collaboratorUserId);
        BatterySwapVerificationTaskDTO result = verificationService.assignBatterySwapTask(id, collaboratorUserId, adminId, role);
        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "Review battery swap verification task",
            description = "Review a SUBMITTED battery swap verification task as PASS or FAIL."
    )
    @PostMapping("/tasks/{id}/review")
    public ResponseEntity<BatterySwapVerificationTaskDTO> reviewTask(
            @Parameter(description = "Task ID", required = true)
            @PathVariable UUID id,
            @Valid @RequestBody BatterySwapReviewDTO dto,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        String role = extractRole(authentication);

        log.info("Admin {} reviewing battery swap task {} as {}", adminId, id, dto.getResult());

        BatterySwapVerificationTaskDTO result = verificationService.reviewBatterySwapTask(id, dto, adminId, role);
        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "Get collaborator candidates for battery swap task",
            description = "Get list of collaborators sorted by distance to station with workload stats."
    )
    @GetMapping("/tasks/{id}/candidates")
    public ResponseEntity<CandidateListResponseDTO> getCollaboratorCandidates(
            @Parameter(description = "Task ID", required = true)
            @PathVariable UUID id,
            @RequestParam(defaultValue = "true") boolean onlyActiveContract,
            @RequestParam(defaultValue = "false") boolean includeUnlocated,
            Pageable pageable) {

        log.info("Admin getting candidates for battery swap task {}: onlyActiveContract={}, includeUnlocated={}",
                id, onlyActiveContract, includeUnlocated);

        CandidateListResponseDTO result = candidateQueryService.listCandidatesForTask(
                id, onlyActiveContract, includeUnlocated, pageable);
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

    /**
     * DTO for creating battery swap verification task.
     */
    @lombok.Data
    public static class CreateBatterySwapTaskDTO {
        @jakarta.validation.constraints.NotNull(message = "Station ID is required")
        private UUID stationId;

        private UUID versionId;

        private UUID assigneeId;

        @jakarta.validation.constraints.Min(value = 1, message = "Priority must be between 1 and 5")
        @jakarta.validation.constraints.Max(value = 5, message = "Priority must be between 1 and 5")
        private Integer priority = 2;

        private java.time.Instant slaDueAt;
    }
}
