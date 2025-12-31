package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.CreateIssueDTO;
import com.example.evstation.api.ev_user_mobile.dto.IssueResponseDTO;
import com.example.evstation.station.application.ReportIssueService;
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
@Tag(name = "EV User Issues", description = "API for EV Users to report and track issues on stations")
@RestController
@RequestMapping("/api/ev")
@RequiredArgsConstructor
public class IssueController {
    
    private final ReportIssueService reportIssueService;

    @Operation(
        summary = "Report an issue on a station",
        description = "Report a data discrepancy (location, price, hours, ports, other) on a published station"
    )
    @PostMapping("/stations/{stationId}/issues")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<IssueResponseDTO> reportIssue(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId,
            @Valid @RequestBody CreateIssueDTO dto,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Reporting issue: stationId={}, category={}, userId={}", 
                stationId, dto.getCategory(), userId);
        
        IssueResponseDTO response = reportIssueService.createIssue(stationId, dto, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(
        summary = "Get my reported issues",
        description = "Get all issues reported by the current user"
    )
    @GetMapping("/issues/mine")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<List<IssueResponseDTO>> getMyIssues(Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Getting issues for user: {}", userId);
        
        List<IssueResponseDTO> issues = reportIssueService.getMyIssues(userId);
        return ResponseEntity.ok(issues);
    }
    
    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}

