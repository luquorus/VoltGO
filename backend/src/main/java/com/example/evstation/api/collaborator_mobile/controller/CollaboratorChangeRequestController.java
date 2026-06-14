package com.example.evstation.api.collaborator_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.ChangeRequestResponseDTO;
import com.example.evstation.api.ev_user_mobile.dto.CreateChangeRequestDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationDetailDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationListItemDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapCRDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapCRListDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationDetailDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationListDTO;
import com.example.evstation.batteryswap.api.dto.CreateBatterySwapCRDTO;
import com.example.evstation.batteryswap.application.BatterySwapChangeRequestService;
import com.example.evstation.batteryswap.application.BatterySwapStationAdminService;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.notification.application.NotificationService;
import com.example.evstation.notification.domain.NotificationCategory;
import com.example.evstation.notification.domain.NotificationType;
import com.example.evstation.station.application.ChangeRequestService;
import com.example.evstation.station.application.StationQueryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Collaborator Mobile API — Change Request for charging stations and battery swap stations.
 *
 * Allows field collaborators to propose edits to station data after on-site verification.
 * The workflow is identical to the EV User flow (DRAFT → PENDING → APPROVED/REJECTED → PUBLISHED),
 * but every action records actor_role = "COLLABORATOR" in the audit log, and the
 * submitter is notified when the admin makes a decision.
 */
@Slf4j
@Tag(name = "Collaborator Change Requests",
        description = "Collaborator mobile API for creating and managing station change requests")
@RestController
@RequestMapping("/api/collab/mobile")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
public class CollaboratorChangeRequestController {

    private final ChangeRequestService changeRequestService;
    private final BatterySwapChangeRequestService batterySwapChangeRequestService;
    private final StationQueryService stationQueryService;
    private final BatterySwapStationAdminService batterySwapStationAdminService;
    private final NotificationService notificationService;

    private static final String ACTOR_ROLE = "COLLABORATOR";

    // ============================================
    // Charging Station Change Requests
    // ============================================

    @Operation(summary = "Create a charging-station change request",
            description = "Submit a DRAFT change request (CREATE_STATION or UPDATE_STATION) on behalf of a field collaborator.")
    @PostMapping("/change-requests")
    public ResponseEntity<ChangeRequestResponseDTO> createChangeRequest(
            @Valid @RequestBody CreateChangeRequestDTO request,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("[COLLAB-CR] Creating charging CR: type={}, userId={}", request.getType(), userId);

        ChangeRequestResponseDTO response = changeRequestService.createChangeRequest(
                request, userId, ACTOR_ROLE);

        // Notify collaborator that their draft was created (in-app record only — push handled by listener)
        notifyCollaborator(userId,
                "Change request saved as draft",
                String.format("Your %s proposal has been saved as a draft. Submit it when you're ready for admin review.",
                        request.getType().name()),
                response.getId(),
                "CHANGE_REQUEST");

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(summary = "Submit a charging-station change request for review",
            description = "Move a DRAFT change request to PENDING. Runs the standard risk engine.")
    @PostMapping("/change-requests/{id}/submit")
    public ResponseEntity<ChangeRequestResponseDTO> submitChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("[COLLAB-CR] Submitting charging CR: id={}, userId={}", id, userId);

        ChangeRequestResponseDTO response = changeRequestService.submitChangeRequest(
                id, userId, ACTOR_ROLE);

        notifyCollaborator(userId,
                "Change request submitted for review",
                String.format("Your change request %s has been submitted to admins for review.", id),
                id,
                "CHANGE_REQUEST");

        return ResponseEntity.ok(response);
    }

    @Operation(summary = "List my charging change requests",
            description = "Get all charging change requests submitted by the current collaborator.")
    @GetMapping("/change-requests/mine")
    public ResponseEntity<List<ChangeRequestResponseDTO>> getMyChangeRequests(
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("[COLLAB-CR] Listing charging CRs for collaborator: {}", userId);

        return ResponseEntity.ok(changeRequestService.getMyChangeRequests(userId));
    }

    @Operation(summary = "Get a specific charging change request",
            description = "Get full details of a charging change request owned by the current collaborator.")
    @GetMapping("/change-requests/{id}")
    public ResponseEntity<ChangeRequestResponseDTO> getChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        return changeRequestService.getChangeRequest(id, userId)
                .map(ResponseEntity::ok)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND,
                        "Change request not found or not owned by current user"));
    }

    // ============================================
    // Battery Swap Station Change Requests
    // ============================================

    @Operation(summary = "Create a battery-swap change request",
            description = "Submit a DRAFT change request (CREATE_BATTERY_SWAP_STATION or UPDATE_BATTERY_SWAP_STATION) for a battery swap station.")
    @PostMapping("/battery-swap-change-requests")
    public ResponseEntity<BatterySwapCRDTO> createBatterySwapChangeRequest(
            @Valid @RequestBody CreateBatterySwapCRDTO request,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("[COLLAB-CR] Creating battery-swap CR: type={}, userId={}",
                request.getType(), userId);

        BatterySwapCRDTO response = batterySwapChangeRequestService.createChangeRequest(
                request, userId, false, ACTOR_ROLE);

        notifyCollaborator(userId,
                "Battery-swap change request saved",
                "Your battery-swap station proposal has been saved as a draft.",
                response.getId(),
                "BATTERY_SWAP_CHANGE_REQUEST");

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(summary = "Submit a battery-swap change request for review",
            description = "Move a DRAFT battery-swap CR to PENDING. Runs the battery-swap risk engine.")
    @PostMapping("/battery-swap-change-requests/{id}/submit")
    public ResponseEntity<BatterySwapCRDTO> submitBatterySwapChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("[COLLAB-CR] Submitting battery-swap CR: id={}, userId={}", id, userId);

        BatterySwapCRDTO response = batterySwapChangeRequestService.submitChangeRequest(id, userId, ACTOR_ROLE);

        notifyCollaborator(userId,
                "Battery-swap change request submitted",
                String.format("Your battery-swap change request %s has been sent for admin review.", id),
                id,
                "BATTERY_SWAP_CHANGE_REQUEST");

        return ResponseEntity.ok(response);
    }

    @Operation(summary = "List my battery-swap change requests")
    @GetMapping("/battery-swap-change-requests/mine")
    public ResponseEntity<List<BatterySwapCRListDTO>> getMyBatterySwapChangeRequests(
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        log.info("[COLLAB-CR] Listing battery-swap CRs for collaborator: {}", userId);

        return ResponseEntity.ok(batterySwapChangeRequestService.getMyChangeRequests(userId));
    }

    @Operation(summary = "Get a specific battery-swap change request")
    @GetMapping("/battery-swap-change-requests/{id}")
    public ResponseEntity<BatterySwapCRDTO> getBatterySwapChangeRequest(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id,
            Authentication authentication) {

        UUID userId = extractUserId(authentication);
        return batterySwapChangeRequestService.getChangeRequest(id, userId)
                .map(ResponseEntity::ok)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND,
                        "Battery-swap change request not found or not owned by current user"));
    }

    // ============================================
    // Station search & auto-fill (used by change-request create form)
    // ============================================

    @Operation(summary = "Search published charging stations by name (auto-fill helper)",
            description = "Returns PUBLISHED charging stations whose name matches the query (case-insensitive). "
                    + "The collaborator picks one to auto-fill the change-request create form.")
    @GetMapping("/stations/search/by-name")
    public ResponseEntity<PaginationResponse<StationListItemDTO>> searchChargingStationsByName(
            @Parameter(description = "Station name query (case-insensitive, partial match)", required = true)
            @RequestParam @jakarta.validation.constraints.NotNull String name,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        log.info("[COLLAB-CR] Search charging stations by name: query='{}', page={}, size={}", name, page, size);
        Pageable pageable = PageRequest.of(Math.max(0, page), Math.min(Math.max(1, size), 50));
        Page<StationListItemDTO> result = stationQueryService.searchStationsByName(name, pageable);
        return ResponseEntity.ok(PaginationResponse.fromPage(result));
    }

    @Operation(summary = "Get full detail of a published charging station (auto-fill helper)",
            description = "Returns the full PUBLISHED station data so the collaborator's create form can pre-populate "
                    + "name, address, GPS, operating hours, charging ports and (if present) battery-swap info.")
    @GetMapping("/stations/{stationId}")
    public ResponseEntity<StationDetailDTO> getChargingStationDetail(
            @Parameter(description = "Station ID", required = true) @PathVariable UUID stationId) {

        log.info("[COLLAB-CR] Get charging station detail for auto-fill: {}", stationId);
        return stationQueryService.findStationDetail(stationId)
                .map(ResponseEntity::ok)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND,
                        "Published station not found: " + stationId));
    }

    @Operation(summary = "Search published battery-swap stations by name (auto-fill helper)",
            description = "Returns PUBLISHED battery-swap stations whose name matches the query.")
    @GetMapping("/battery-swap-stations/search/by-name")
    public ResponseEntity<PaginationResponse<BatterySwapStationListDTO>> searchBatterySwapStationsByName(
            @Parameter(description = "Station name or ID query (case-insensitive, partial match)", required = true)
            @RequestParam String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        log.info("[COLLAB-CR] Search battery-swap stations: query='{}', page={}, size={}", search, page, size);
        int safePage = Math.max(0, page);
        int safeSize = Math.min(Math.max(1, size), 50);
        PaginationResponse<BatterySwapStationListDTO> response = batterySwapStationAdminService
                .listStations(safePage, safeSize, search);
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "Get full detail of a published battery-swap station (auto-fill helper)",
            description = "Returns the full PUBLISHED battery-swap station data for pre-populating the create form.")
    @GetMapping("/battery-swap-stations/{stationId}")
    public ResponseEntity<BatterySwapStationDetailDTO> getBatterySwapStationDetail(
            @Parameter(description = "Station ID", required = true) @PathVariable UUID stationId) {

        log.info("[COLLAB-CR] Get battery-swap station detail for auto-fill: {}", stationId);
        return batterySwapStationAdminService.getStation(stationId)
                .map(ResponseEntity::ok)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND,
                        "Published battery-swap station not found: " + stationId));
    }

    // ============================================
    // Helpers
    // ============================================

    /**
     * Fire an in-app notification to the collaborator. Used for lifecycle events
     * the collaborator should know about (CR created, submitted, etc.). The
     * notification service will also send push + email after the transaction commits
     * if the user has those channels enabled.
     */
    private void notifyCollaborator(UUID userId, String title, String body,
                                    UUID referenceId, String referenceType) {
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("deepLink", "/change-requests/" + referenceId);
            notificationService.send(com.example.evstation.notification.api.dto.CreateNotificationDTO.builder()
                    .recipientId(userId)
                    .type(NotificationType.STATION_CHANGE_REQUEST_SUBMITTED)
                    .category(NotificationCategory.STATION)
                    .title(title)
                    .body(body)
                    .data(data)
                    .referenceId(referenceId)
                    .referenceType(referenceType)
                    .build());
        } catch (Exception e) {
            // Never let a notification failure break the main flow
            log.warn("[COLLAB-CR] Failed to send notification to collaborator {}: {}",
                    userId, e.getMessage());
        }
    }

    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}
