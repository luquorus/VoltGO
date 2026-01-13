package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.ChangeRequestResponseDTO;
import com.example.evstation.api.ev_user_mobile.dto.CreateChangeRequestDTO;
import com.example.evstation.station.application.ChangeRequestService;
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
@Tag(name = "Change Requests", description = "API for managing station change requests")
@RestController
@RequestMapping("/api/ev/change-requests")
@RequiredArgsConstructor
public class ChangeRequestController {
    
    private final ChangeRequestService changeRequestService;

    @Operation(
        summary = "Create a new change request",
        description = "Create a new change request for CREATE_STATION or UPDATE_STATION. Status will be DRAFT."
    )
    @PostMapping
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<ChangeRequestResponseDTO> createChangeRequest(
            @Valid @RequestBody CreateChangeRequestDTO request,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Creating change request: type={}, userId={}", request.getType(), userId);
        
        ChangeRequestResponseDTO response = changeRequestService.createChangeRequest(request, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(
        summary = "Submit a change request for review",
        description = "Submit a DRAFT change request for review. Status changes from DRAFT to PENDING."
    )
    @PostMapping("/{id}/submit")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<ChangeRequestResponseDTO> submitChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Submitting change request: id={}, userId={}", id, userId);
        
        ChangeRequestResponseDTO response = changeRequestService.submitChangeRequest(id, userId);
        return ResponseEntity.ok(response);
    }

    @Operation(
        summary = "Get my change requests",
        description = "Get all change requests submitted by the current user"
    )
    @GetMapping("/mine")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<List<ChangeRequestResponseDTO>> getMyChangeRequests(
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Getting change requests for user: {}", userId);
        
        List<ChangeRequestResponseDTO> responses = changeRequestService.getMyChangeRequests(userId);
        return ResponseEntity.ok(responses);
    }

    @Operation(
        summary = "Get a specific change request",
        description = "Get details of a specific change request by ID"
    )
    @GetMapping("/{id}")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<ChangeRequestResponseDTO> getChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Getting change request: id={}, userId={}", id, userId);
        
        return changeRequestService.getChangeRequest(id, userId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    private UUID extractUserId(Authentication authentication) {
        // The principal is set to userId in JwtAuthenticationFilter
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}

