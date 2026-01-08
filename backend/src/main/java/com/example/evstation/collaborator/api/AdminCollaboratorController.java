package com.example.evstation.collaborator.api;

import com.example.evstation.collaborator.api.dto.CollaboratorProfileDTO;
import com.example.evstation.collaborator.api.dto.CreateCollaboratorDTO;
import com.example.evstation.collaborator.application.CollaboratorService;
import com.example.evstation.common.web.PaginationRequest;
import com.example.evstation.common.web.PaginationResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@Tag(name = "Admin Collaborators", description = "Admin API for managing collaborator profiles")
@RestController
@RequestMapping("/api/admin/collaborators")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminCollaboratorController {
    
    private final CollaboratorService collaboratorService;

    @Operation(
        summary = "Create collaborator profile",
        description = "Create a collaborator profile for a user account with COLLABORATOR role"
    )
    @PostMapping
    public ResponseEntity<CollaboratorProfileDTO> createCollaborator(
            @Valid @RequestBody CreateCollaboratorDTO request,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        
        log.info("Admin creating collaborator: userAccountId={}", request.getUserAccountId());
        
        CollaboratorProfileDTO result = collaboratorService.createCollaborator(request, adminId, adminRole);
        return ResponseEntity.status(HttpStatus.CREATED).body(result);
    }

    @Operation(
        summary = "List collaborators",
        description = "Get all collaborator profiles with pagination"
    )
    @GetMapping
    public ResponseEntity<PaginationResponse<CollaboratorProfileDTO>> getCollaborators(
            PaginationRequest pagination) {
        
        log.info("Admin listing collaborators");
        
        Page<CollaboratorProfileDTO> page = collaboratorService.getAllCollaborators(pagination.toPageable());
        return ResponseEntity.ok(PaginationResponse.fromPage(page));
    }

    @Operation(
        summary = "Get collaborator by ID",
        description = "Get a specific collaborator profile by ID"
    )
    @GetMapping("/{id}")
    public ResponseEntity<CollaboratorProfileDTO> getCollaborator(
            @Parameter(description = "Collaborator profile ID", required = true)
            @PathVariable UUID id) {
        
        log.info("Admin getting collaborator: id={}", id);
        
        return collaboratorService.getCollaboratorById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
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

