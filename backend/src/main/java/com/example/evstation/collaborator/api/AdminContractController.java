package com.example.evstation.collaborator.api;

import com.example.evstation.collaborator.api.dto.ContractDTO;
import com.example.evstation.collaborator.api.dto.CreateContractDTO;
import com.example.evstation.collaborator.api.dto.UpdateContractDTO;
import com.example.evstation.collaborator.application.ContractService;
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
import java.util.Map;
import java.util.UUID;

@Slf4j
@Tag(name = "Admin Contracts", description = "Admin API for managing collaborator contracts")
@RestController
@RequestMapping("/api/admin/contracts")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminContractController {
    
    private final ContractService contractService;

    @Operation(
        summary = "Create contract",
        description = "Create a new contract for a collaborator"
    )
    @PostMapping
    public ResponseEntity<ContractDTO> createContract(
            @Valid @RequestBody CreateContractDTO request,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        
        log.info("Admin creating contract: collaboratorId={}", request.getCollaboratorId());
        
        ContractDTO result = contractService.createContract(request, adminId, adminRole);
        return ResponseEntity.status(HttpStatus.CREATED).body(result);
    }

    @Operation(
        summary = "List contracts by collaborator",
        description = "Get all contracts for a specific collaborator"
    )
    @GetMapping
    public ResponseEntity<List<ContractDTO>> getContracts(
            @Parameter(description = "Collaborator profile ID", required = true)
            @RequestParam UUID collaboratorId) {
        
        log.info("Admin listing contracts: collaboratorId={}", collaboratorId);
        
        List<ContractDTO> contracts = contractService.getContractsByCollaboratorId(collaboratorId);
        return ResponseEntity.ok(contracts);
    }

    @Operation(
        summary = "Get contract by ID",
        description = "Get a specific contract by ID"
    )
    @GetMapping("/{id}")
    public ResponseEntity<ContractDTO> getContract(
            @Parameter(description = "Contract ID", required = true)
            @PathVariable UUID id) {
        
        log.info("Admin getting contract: id={}", id);
        
        return contractService.getContractById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
        summary = "Update contract",
        description = "Update contract dates, region, or note"
    )
    @PutMapping("/{id}")
    public ResponseEntity<ContractDTO> updateContract(
            @Parameter(description = "Contract ID", required = true)
            @PathVariable UUID id,
            @RequestBody UpdateContractDTO request,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        
        log.info("Admin updating contract: id={}", id);
        
        ContractDTO result = contractService.updateContract(id, request, adminId, adminRole);
        return ResponseEntity.ok(result);
    }

    @Operation(
        summary = "Terminate contract",
        description = "Terminate an active contract"
    )
    @PostMapping("/{id}/terminate")
    public ResponseEntity<ContractDTO> terminateContract(
            @Parameter(description = "Contract ID", required = true)
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> request,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        String adminRole = extractRole(authentication);
        String reason = request != null ? request.get("reason") : null;
        
        log.info("Admin terminating contract: id={}", id);
        
        ContractDTO result = contractService.terminateContract(id, reason, adminId, adminRole);
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

