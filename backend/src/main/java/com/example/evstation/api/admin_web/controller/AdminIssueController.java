package com.example.evstation.api.admin_web.controller;

import com.example.evstation.api.admin_web.dto.AdminIssueResponseDTO;
import com.example.evstation.api.admin_web.dto.IssueActionDTO;
import com.example.evstation.station.application.ReportIssueService;
import com.example.evstation.station.domain.IssueStatus;
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
@Tag(name = "Admin Issues", description = "Admin API for managing reported issues")
@RestController
@RequestMapping("/api/admin/issues")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminIssueController {
    
    private final ReportIssueService reportIssueService;

    @Operation(
        summary = "List issues",
        description = "Get all issues with optional status filter"
    )
    @GetMapping
    public ResponseEntity<List<AdminIssueResponseDTO>> getIssues(
            @Parameter(description = "Filter by status: OPEN, ACKNOWLEDGED, RESOLVED, REJECTED")
            @RequestParam(required = false) IssueStatus status) {
        
        log.info("Admin getting issues: status={}", status);
        
        List<AdminIssueResponseDTO> issues = reportIssueService.getIssuesByStatus(status);
        return ResponseEntity.ok(issues);
    }

    @Operation(
        summary = "Get issue details",
        description = "Get full details of a specific issue"
    )
    @GetMapping("/{id}")
    public ResponseEntity<AdminIssueResponseDTO> getIssue(
            @Parameter(description = "Issue ID", required = true)
            @PathVariable UUID id) {
        
        log.info("Admin getting issue: id={}", id);
        
        return reportIssueService.getIssueById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
        summary = "Acknowledge an issue",
        description = "Mark an OPEN issue as ACKNOWLEDGED (seen by admin)"
    )
    @PostMapping("/{id}/acknowledge")
    public ResponseEntity<AdminIssueResponseDTO> acknowledgeIssue(
            @Parameter(description = "Issue ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        
        log.info("Admin acknowledging issue: id={}, adminId={}", id, adminId);
        
        AdminIssueResponseDTO response = reportIssueService.acknowledgeIssue(id, adminId, adminRole);
        return ResponseEntity.ok(response);
    }

    @Operation(
        summary = "Resolve an issue",
        description = "Mark an OPEN or ACKNOWLEDGED issue as RESOLVED"
    )
    @PostMapping("/{id}/resolve")
    public ResponseEntity<AdminIssueResponseDTO> resolveIssue(
            @Parameter(description = "Issue ID", required = true)
            @PathVariable UUID id,
            @Valid @RequestBody IssueActionDTO dto,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        
        log.info("Admin resolving issue: id={}, adminId={}", id, adminId);
        
        AdminIssueResponseDTO response = reportIssueService.resolveIssue(id, dto.getNote(), adminId, adminRole);
        return ResponseEntity.ok(response);
    }

    @Operation(
        summary = "Reject an issue",
        description = "Mark an OPEN or ACKNOWLEDGED issue as REJECTED (invalid report)"
    )
    @PostMapping("/{id}/reject")
    public ResponseEntity<AdminIssueResponseDTO> rejectIssue(
            @Parameter(description = "Issue ID", required = true)
            @PathVariable UUID id,
            @Valid @RequestBody IssueActionDTO dto,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        
        log.info("Admin rejecting issue: id={}, adminId={}", id, adminId);
        
        AdminIssueResponseDTO response = reportIssueService.rejectIssue(id, dto.getNote(), adminId, adminRole);
        return ResponseEntity.ok(response);
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

