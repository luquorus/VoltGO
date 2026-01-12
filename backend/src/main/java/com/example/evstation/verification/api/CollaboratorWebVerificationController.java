package com.example.evstation.verification.api;

import com.example.evstation.verification.api.dto.*;
import com.example.evstation.verification.application.VerificationService;
import com.example.evstation.verification.domain.VerificationTaskStatus;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.Instant;
import java.util.UUID;

@Slf4j
@Tag(name = "Collaborator Web Verification", description = "Web API for collaborators to view tasks, history, and KPI")
@RestController
@RequestMapping("/api/collab/web/tasks")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
public class CollaboratorWebVerificationController {
    
    private final VerificationService verificationService;

    @Operation(summary = "Get tasks with filters", 
               description = "Get verification tasks assigned to the current collaborator with optional filters for status, priority, and SLA")
    @GetMapping
    public ResponseEntity<Page<VerificationTaskDTO>> getTasks(
            @RequestParam(required = false) VerificationTaskStatus status,
            @RequestParam(required = false) Integer priority,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant slaDueBefore,
            Pageable pageable,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} getting web tasks: status={}, priority={}", userId, status, priority);
        
        Page<VerificationTaskDTO> tasks = verificationService.getTasksForCollaboratorWeb(
                userId, status, priority, slaDueBefore, pageable);
        return ResponseEntity.ok(tasks);
    }

    @Operation(summary = "Get task history", 
               description = "Get reviewed (completed) verification tasks for the current collaborator")
    @GetMapping("/history")
    public ResponseEntity<Page<VerificationTaskDTO>> getHistory(
            Pageable pageable,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} getting task history", userId);
        
        Page<VerificationTaskDTO> history = verificationService.getTaskHistory(userId, pageable);
        return ResponseEntity.ok(history);
    }

    @Operation(summary = "Get KPI summary", 
               description = "Get simple KPI: count of reviewed tasks PASS/FAIL for the current month")
    @GetMapping("/kpi")
    public ResponseEntity<CollaboratorKpiDTO> getKpi(Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Collaborator {} getting KPI", userId);
        
        CollaboratorKpiDTO kpi = verificationService.getKpi(userId);
        return ResponseEntity.ok(kpi);
    }

    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }
}

