package com.example.evstation.api.public_api;

import com.example.evstation.auth.application.port.JwtTokenProvider;
import com.example.evstation.collaborator.api.dto.CollaboratorRegistrationRequestDTO;
import com.example.evstation.collaborator.api.dto.SubmitRegistrationRequestDTO;
import com.example.evstation.collaborator.application.CollaboratorRegistrationRequestService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * Public API Controller for Collaborator Registration.
 *
 * GET /api/public/registration-requests/{id} - publicly accessible (no auth required)
 * POST /api/public/registration-requests  - requires authentication (JWT token)
 */
@Slf4j
@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicRegistrationController {

    private final CollaboratorRegistrationRequestService registrationRequestService;

    /**
     * Submit a new collaborator registration request.
     * Requires authentication — email is extracted from JWT token for security.
     * Only PENDING_COLLABORATOR users can submit (enforced by service layer).
     *
     * POST /api/public/registration-requests
     */
    @PostMapping("/registration-requests")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, Object>> submitRegistrationRequest(
            @Valid @RequestBody SubmitRegistrationRequestDTO dto) {

        String email = extractEmailFromSecurityContext();

        log.info("Received registration request for email: {}", email);

        UUID requestId = registrationRequestService.submitRequest(dto, email);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of(
                        "id", requestId.toString(),
                        "message", "Registration request submitted successfully. Please wait for admin approval."
                ));
    }

    /**
     * Check the status of a registration request by ID.
     *
     * GET /api/public/registration-requests/{id}
     */
    @GetMapping("/registration-requests/{id}")
    public ResponseEntity<CollaboratorRegistrationRequestDTO> getRegistrationRequestStatus(
            @PathVariable UUID id) {

        log.info("Checking registration request status: id={}", id);

        CollaboratorRegistrationRequestDTO request = registrationRequestService.getRequest(id);

        return ResponseEntity.ok(request);
    }

    private String extractEmailFromSecurityContext() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getDetails() == null) {
            throw new AccessDeniedException("Authentication required");
        }
        Object details = auth.getDetails();
        if (details instanceof JwtTokenProvider.TokenClaims claims) {
            return claims.email();
        }
        throw new AccessDeniedException("Unable to extract email from token");
    }
}
