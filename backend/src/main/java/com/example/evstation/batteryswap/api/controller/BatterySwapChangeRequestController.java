package com.example.evstation.batteryswap.api.controller;

import com.example.evstation.batteryswap.api.dto.BatterySwapCRDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapCRListDTO;
import com.example.evstation.batteryswap.api.dto.CreateBatterySwapCRDTO;
import com.example.evstation.batteryswap.application.BatterySwapChangeRequestService;
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
@Tag(name = "Battery Swap Change Requests", description = "EV User API for managing battery swap station change requests")
@RestController
@RequestMapping("/api/ev/battery-swap-change-requests")
@RequiredArgsConstructor
public class BatterySwapChangeRequestController {

    private final BatterySwapChangeRequestService service;

    @Operation(
            summary = "Create a battery swap change request",
            description = "Create a new DRAFT change request for creating or updating a battery swap station."
    )
    @PostMapping
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapCRDTO> createChangeRequest(
            @Valid @RequestBody CreateBatterySwapCRDTO request,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("Creating battery swap CR: type={}, userId={}", request.getType(), userId);

        BatterySwapCRDTO response = service.createChangeRequest(request, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(
            summary = "Get my change requests",
            description = "Get all battery swap change requests submitted by the current user."
    )
    @GetMapping
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<List<BatterySwapCRListDTO>> getMyChangeRequests(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Getting battery swap CRs for user: {}", userId);

        List<BatterySwapCRListDTO> responses = service.getMyChangeRequests(userId);
        return ResponseEntity.ok(responses);
    }

    @Operation(
            summary = "Get a specific change request",
            description = "Get details of a specific battery swap change request by ID."
    )
    @GetMapping("/{id}")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapCRDTO> getChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("Getting battery swap CR: id={}, userId={}", id, userId);

        return service.getChangeRequest(id, userId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
            summary = "Submit a change request",
            description = "Submit a DRAFT change request for review. Status changes from DRAFT to PENDING and risk assessment runs."
    )
    @PostMapping("/{id}/submit")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapCRDTO> submitChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("Submitting battery swap CR: id={}, userId={}", id, userId);

        BatterySwapCRDTO response = service.submitChangeRequest(id, userId);
        return ResponseEntity.ok(response);
    }

    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}
