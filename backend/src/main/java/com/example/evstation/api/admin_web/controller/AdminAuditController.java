package com.example.evstation.api.admin_web.controller;

import com.example.evstation.api.admin_web.dto.AuditLogResponseDTO;
import com.example.evstation.common.web.PaginationRequest;
import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.station.application.AuditLogService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Tag(name = "Admin Audit Logs", description = "Admin API for querying audit logs")
@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminAuditController {
    
    private final AuditLogService auditLogService;

    @Operation(
        summary = "Query audit logs",
        description = "Query audit logs with optional filters: entityType, entityId, from, to"
    )
    @GetMapping("/audit")
    public ResponseEntity<PaginationResponse<AuditLogResponseDTO>> queryAuditLogs(
            @Parameter(description = "Filter by entity type: CHANGE_REQUEST, STATION, STATION_VERSION")
            @RequestParam(required = false) String entityType,
            
            @Parameter(description = "Filter by entity ID")
            @RequestParam(required = false) UUID entityId,
            
            @Parameter(description = "Filter from date (ISO format)")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            
            @Parameter(description = "Filter to date (ISO format)")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            
            PaginationRequest pagination) {
        
        log.info("Querying audit logs: entityType={}, entityId={}, from={}, to={}", 
                entityType, entityId, from, to);
        
        Page<AuditLogResponseDTO> page;
        if (entityType == null && entityId == null && from == null && to == null) {
            page = auditLogService.getAllAuditLogs(pagination.toPageable());
        } else {
            page = auditLogService.queryAuditLogs(entityType, entityId, from, to, pagination.toPageable());
        }
        
        return ResponseEntity.ok(PaginationResponse.fromPage(page));
    }

    @Operation(
        summary = "Get station audit logs",
        description = "Get all audit logs related to a station (including versions and change requests)"
    )
    @GetMapping("/stations/{stationId}/audit")
    public ResponseEntity<List<AuditLogResponseDTO>> getStationAuditLogs(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {
        
        log.info("Getting audit logs for station: {}", stationId);
        
        List<AuditLogResponseDTO> logs = auditLogService.getStationAuditLogs(stationId);
        return ResponseEntity.ok(logs);
    }

    @Operation(
        summary = "Get change request audit logs",
        description = "Get all audit logs for a specific change request"
    )
    @GetMapping("/change-requests/{id}/audit")
    public ResponseEntity<List<AuditLogResponseDTO>> getChangeRequestAuditLogs(
            @Parameter(description = "Change request ID", required = true)
            @PathVariable UUID id) {
        
        log.info("Getting audit logs for change request: {}", id);
        
        List<AuditLogResponseDTO> logs = auditLogService.getChangeRequestAuditLogs(id);
        return ResponseEntity.ok(logs);
    }
}

