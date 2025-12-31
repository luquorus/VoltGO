package com.example.evstation.api.collaborator_web.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@Tag(name = "Collaborator Web", description = "API for Collaborator Web application")
@RestController
@RequestMapping("/api/collab/web")
@PreAuthorize("hasRole('COLLABORATOR')")
public class CollaboratorWebController {
    
    @Operation(summary = "Test endpoint", description = "Test endpoint for Collaborator Web API")
    @GetMapping("/test")
    public ResponseEntity<Map<String, String>> test() {
        return ResponseEntity.ok(Map.of("message", "Collaborator Web API is accessible"));
    }
}

