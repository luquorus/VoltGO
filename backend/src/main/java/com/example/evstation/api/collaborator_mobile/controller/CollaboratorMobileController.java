package com.example.evstation.api.collaborator_mobile.controller;

import com.example.evstation.collaborator.api.dto.CollaboratorLocationDTO;
import com.example.evstation.collaborator.api.dto.UpdateLocationDTO;
import com.example.evstation.collaborator.application.CollaboratorLocationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Slf4j
@Tag(name = "Collaborator Mobile", description = "API for Collaborator Mobile application")
@RestController
@RequestMapping("/api/collab/mobile")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
public class CollaboratorMobileController {
    
    private final CollaboratorLocationService locationService;
    
    @Operation(summary = "Test endpoint", description = "Test endpoint for Collaborator Mobile API")
    @GetMapping("/test")
    public ResponseEntity<Map<String, String>> test() {
        return ResponseEntity.ok(Map.of("message", "Collaborator Mobile API is accessible"));
    }

    @Operation(
        summary = "Update my location (GPS)",
        description = "Update the current collaborator's location from mobile device GPS"
    )
    @PutMapping("/me/location")
    public ResponseEntity<CollaboratorLocationDTO> updateMyLocation(
            @Valid @RequestBody UpdateLocationDTO dto,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Collaborator mobile updating location: userId={}, lat={}, lng={}", 
                userId, dto.getLat(), dto.getLng());
        
        CollaboratorLocationDTO result = locationService.updateLocationFromMobile(userId, dto);
        return ResponseEntity.ok(result);
    }

    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}

