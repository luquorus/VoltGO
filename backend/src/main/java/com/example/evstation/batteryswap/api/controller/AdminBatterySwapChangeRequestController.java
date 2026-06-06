package com.example.evstation.batteryswap.api.controller;

import com.example.evstation.api.admin_web.dto.ApproveRequestDTO;
import com.example.evstation.api.admin_web.dto.RejectRequestDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapCRDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapCRListDTO;
import com.example.evstation.batteryswap.api.dto.CreateBatterySwapCRDTO;
import com.example.evstation.batteryswap.api.dto.UpdateBatterySwapCRDTO;
import com.example.evstation.batteryswap.application.BatterySwapChangeRequestService;
import com.example.evstation.batteryswap.domain.ChangeRequestStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Slf4j
@Tag(name = "Admin Battery Swap Change Requests", description = "Admin API for managing battery swap station change requests")
@RestController
@RequestMapping("/api/admin/battery-swap/change-requests")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminBatterySwapChangeRequestController {

    private final BatterySwapChangeRequestService service;

    @Operation(
            summary = "Create a new battery swap change request",
            description = "Create a new change request. Admin: submitted with submitImmediately=true (bypasses workflow, immediately published). EV user: submitted with submitImmediately=false (created as DRAFT)."
    )
    @PostMapping
    public ResponseEntity<BatterySwapCRDTO> createChangeRequest(
            @Valid @RequestBody CreateBatterySwapCRDTO request,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        boolean isAdmin = authentication.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .anyMatch(a -> a.equals("ROLE_ADMIN"));
        boolean submitImmediately = Boolean.TRUE.equals(request.getSubmitImmediately()) || isAdmin;
        log.info("Creating battery swap CR: type={}, adminId={}, submitImmediately={}",
                request.getType(), adminId, submitImmediately);

        BatterySwapCRDTO result = service.createChangeRequest(request, adminId, submitImmediately);
        return ResponseEntity.status(HttpStatus.CREATED).body(result);
    }

    @Operation(
            summary = "Update a DRAFT battery swap change request",
            description = "Update version fields and pile templates of a DRAFT CR. Only works on DRAFT CRs."
    )
    @PutMapping("/{id}")
    public ResponseEntity<BatterySwapCRDTO> updateChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            @Valid @RequestBody UpdateBatterySwapCRDTO request,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        log.info("Admin updating battery swap CR: id={}, adminId={}", id, adminId);

        BatterySwapCRDTO result = service.updateChangeRequest(id, request, adminId);
        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "List all battery swap change requests",
            description = "Get all battery swap change requests with optional status filter."
    )
    @GetMapping
    public ResponseEntity<List<BatterySwapCRListDTO>> listAll(
            @Parameter(description = "Filter by status: DRAFT, PENDING, APPROVED, REJECTED, PUBLISHED")
            @RequestParam(required = false) ChangeRequestStatus status) {

        log.info("Admin listing battery swap CRs: status={}", status);
        List<BatterySwapCRListDTO> dtos = service.listAll(status);
        return ResponseEntity.ok(dtos);
    }

    @Operation(
            summary = "Get change request detail",
            description = "Get full details of a specific battery swap change request by ID."
    )
    @GetMapping("/{id}")
    public ResponseEntity<BatterySwapCRDTO> getChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id) {

        log.info("Admin getting battery swap CR: id={}", id);
        return service.getChangeRequestAdmin(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
            summary = "Approve a change request",
            description = "Approve a PENDING change request. Status changes from PENDING to APPROVED."
    )
    @PostMapping("/{id}/approve")
    public ResponseEntity<BatterySwapCRDTO> approveChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            @RequestBody(required = false) ApproveRequestDTO request,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        String note = request != null ? request.getNote() : null;

        log.info("Admin approving battery swap CR: id={}, adminId={}", id, adminId);
        BatterySwapCRDTO result = service.approveChangeRequest(id, adminId, note);
        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "Reject a change request",
            description = "Reject a PENDING change request. Reason is required."
    )
    @PostMapping("/{id}/reject")
    public ResponseEntity<BatterySwapCRDTO> rejectChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            @Valid @RequestBody RejectRequestDTO request,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        log.info("Admin rejecting battery swap CR: id={}, adminId={}", id, adminId);

        BatterySwapCRDTO result = service.rejectChangeRequest(id, adminId, request.getReason());
        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "Publish a change request",
            description = "Publish an APPROVED change request. If riskScore >= 60, a verification task is created. " +
                    "The version is applied to operational state."
    )
    @PostMapping("/{id}/publish")
    public ResponseEntity<BatterySwapCRDTO> publishChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        log.info("Admin publishing battery swap CR: id={}, adminId={}", id, adminId);

        BatterySwapCRDTO result = service.publishChangeRequest(id, adminId);
        return ResponseEntity.ok(result);
    }

    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}
