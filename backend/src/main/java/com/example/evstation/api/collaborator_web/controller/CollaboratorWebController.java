package com.example.evstation.api.collaborator_web.controller;

import com.example.evstation.collaborator.api.dto.CollaboratorProfileDTO;
import com.example.evstation.collaborator.api.dto.ContractDTO;
import com.example.evstation.collaborator.application.CollaboratorService;
import com.example.evstation.collaborator.application.ContractService;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileEntity;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Tag(name = "Collaborator Web", description = "API for Collaborator Web application")
@RestController
@RequestMapping("/api/collab/web")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
public class CollaboratorWebController {
    
    private final CollaboratorService collaboratorService;
    private final ContractService contractService;
    private final CollaboratorProfileJpaRepository collaboratorRepository;

    @Operation(summary = "Test endpoint", description = "Test endpoint for Collaborator Web API")
    @GetMapping("/test")
    public ResponseEntity<Map<String, String>> test() {
        return ResponseEntity.ok(Map.of("message", "Collaborator Web API is accessible"));
    }

    @Operation(
        summary = "Get my profile",
        description = "Get the current collaborator's profile"
    )
    @GetMapping("/me/profile")
    public ResponseEntity<CollaboratorProfileDTO> getMyProfile(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Collaborator getting profile: userId={}", userId);
        
        return collaboratorService.getCollaboratorByUserAccountId(userId)
                .map(ResponseEntity::ok)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Collaborator profile not found. Please contact admin."));
    }

    @Operation(
        summary = "Get my contracts",
        description = "Get the current collaborator's contracts with active flag"
    )
    @GetMapping("/me/contracts")
    public ResponseEntity<List<ContractDTO>> getMyContracts(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Collaborator getting contracts: userId={}", userId);
        
        // Find collaborator profile by user account ID
        CollaboratorProfileEntity profile = collaboratorRepository.findByUserAccountId(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Collaborator profile not found. Please contact admin."));
        
        List<ContractDTO> contracts = contractService.getContractsByCollaboratorId(profile.getId());
        return ResponseEntity.ok(contracts);
    }
    
    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}
