package com.example.evstation.api.admin_web.controller;

import com.example.evstation.api.admin_web.dto.AdminChangeRequestDTO;
import com.example.evstation.api.admin_web.dto.ApproveRequestDTO;
import com.example.evstation.api.admin_web.dto.RejectRequestDTO;
import com.example.evstation.station.application.AdminChangeRequestService;
import com.example.evstation.station.domain.ChangeRequestStatus;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
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
@Tag(name = "Admin Change Requests", description = "Admin API for managing change requests")
@RestController
@RequestMapping("/api/admin/change-requests")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminChangeRequestController {
    
    private final AdminChangeRequestService adminChangeRequestService;

    @Operation(
        summary = "List change requests",
        description = "Get all change requests with optional status filter"
    )
    @GetMapping
    public ResponseEntity<List<AdminChangeRequestDTO>> getChangeRequests(
            @Parameter(description = "Filter by status: PENDING, APPROVED, REJECTED, PUBLISHED, DRAFT")
            @RequestParam(required = false) ChangeRequestStatus status) {
        
        log.info("Admin getting change requests: status={}", status);
        
        List<AdminChangeRequestDTO> requests;
        if (status != null) {
            requests = adminChangeRequestService.getChangeRequestsByStatus(status);
        } else {
            // Get all - for simplicity, get PENDING first as most relevant for admin
            requests = adminChangeRequestService.getChangeRequestsByStatus(ChangeRequestStatus.PENDING);
        }
        
        return ResponseEntity.ok(requests);
    }

    @Operation(
        summary = "Get change request details",
        description = "Get full details of a specific change request including audit logs"
    )
    @GetMapping("/{id}")
    public ResponseEntity<AdminChangeRequestDTO> getChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id) {
        
        log.info("Admin getting change request: id={}", id);
        
        return adminChangeRequestService.getChangeRequest(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
        summary = "Approve change request",
        description = "Approve a PENDING change request. Status changes to APPROVED."
    )
    @PostMapping("/{id}/approve")
    public ResponseEntity<AdminChangeRequestDTO> approveChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            @RequestBody(required = false) ApproveRequestDTO request,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        String note = request != null ? request.getNote() : null;
        
        log.info("Admin approving change request: id={}, adminId={}", id, adminId);
        
        AdminChangeRequestDTO result = adminChangeRequestService.approveChangeRequest(id, note, adminId, adminRole);
        return ResponseEntity.ok(result);
    }

    @Operation(
        summary = "Reject change request",
        description = "Reject a PENDING change request. Reason is required."
    )
    @PostMapping("/{id}/reject")
    public ResponseEntity<AdminChangeRequestDTO> rejectChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            @Valid @RequestBody RejectRequestDTO request,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        
        log.info("Admin rejecting change request: id={}, adminId={}", id, adminId);
        
        AdminChangeRequestDTO result = adminChangeRequestService.rejectChangeRequest(
                id, request.getReason(), adminId, adminRole);
        return ResponseEntity.ok(result);
    }

    @Operation(
        summary = "Publish change request",
        description = "Publish an APPROVED change request. This makes the station version publicly visible."
    )
    @PostMapping("/{id}/publish")
    public ResponseEntity<AdminChangeRequestDTO> publishChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        
        log.info("Admin publishing change request: id={}, adminId={}", id, adminId);
        
        AdminChangeRequestDTO result = adminChangeRequestService.publishChangeRequest(id, adminId, adminRole);
        return ResponseEntity.ok(result);
    }
    
    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
    
    private String extractRole(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .findFirst()
                .map(a -> a.getAuthority().replace("ROLE_", ""))
                .orElse("ADMIN");
    }
}

