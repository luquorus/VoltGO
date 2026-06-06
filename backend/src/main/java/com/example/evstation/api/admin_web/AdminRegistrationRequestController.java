package com.example.evstation.api.admin_web;

import com.example.evstation.collaborator.api.dto.ApproveRegistrationRequestDTO;
import com.example.evstation.collaborator.api.dto.CollaboratorRegistrationRequestDTO;
import com.example.evstation.collaborator.api.dto.RejectRegistrationRequestDTO;
import com.example.evstation.collaborator.application.CollaboratorRegistrationRequestService;
import com.example.evstation.common.web.PaginationRequest;
import com.example.evstation.common.web.PaginationResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Admin API Controller for Collaborator Registration Requests.
 * 
 * Requires ADMIN role.
 */
@Slf4j
@RestController
@RequestMapping("/api/admin/registration-requests")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminRegistrationRequestController {

    private final CollaboratorRegistrationRequestService registrationRequestService;

    /**
     * Get paginated list of registration requests.
     * 
     * GET /api/admin/registration-requests
     */
    @GetMapping
    public ResponseEntity<PaginationResponse<CollaboratorRegistrationRequestDTO>> getRegistrationRequests(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status) {
        
        log.info("Getting registration requests: page={}, size={}, status={}", page, size, status);
        
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<CollaboratorRegistrationRequestDTO> pageResult = registrationRequestService.getRequests(status, pageable);
        
        PaginationResponse<CollaboratorRegistrationRequestDTO> response = PaginationResponse.<CollaboratorRegistrationRequestDTO>builder()
                .content(pageResult.getContent())
                .page(pageResult.getNumber())
                .size(pageResult.getSize())
                .totalElements(pageResult.getTotalElements())
                .totalPages(pageResult.getTotalPages())
                .first(pageResult.isFirst())
                .last(pageResult.isLast())
                .build();
        
        return ResponseEntity.ok(response);
    }

    /**
     * Get a single registration request by ID.
     * 
     * GET /api/admin/registration-requests/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<CollaboratorRegistrationRequestDTO> getRegistrationRequest(
            @PathVariable UUID id) {
        
        log.info("Getting registration request: id={}", id);
        
        CollaboratorRegistrationRequestDTO request = registrationRequestService.getRequest(id);
        
        return ResponseEntity.ok(request);
    }

    /**
     * Approve a registration request.
     * 
     * POST /api/admin/registration-requests/{id}/approve
     */
    @PostMapping("/{id}/approve")
    public ResponseEntity<CollaboratorRegistrationRequestDTO> approveRegistrationRequest(
            @PathVariable UUID id,
            @Valid @RequestBody ApproveRegistrationRequestDTO dto,
            Authentication authentication) {

        log.info("Approving registration request: id={}", id);

        UUID adminId = extractUserId(authentication);

        CollaboratorRegistrationRequestDTO result = registrationRequestService.approveRequest(id, dto, adminId);

        return ResponseEntity.ok(result);
    }

    /**
     * Reject a registration request.
     * 
     * POST /api/admin/registration-requests/{id}/reject
     */
    @PostMapping("/{id}/reject")
    public ResponseEntity<CollaboratorRegistrationRequestDTO> rejectRegistrationRequest(
            @PathVariable UUID id,
            @Valid @RequestBody RejectRegistrationRequestDTO dto,
            Authentication authentication) {

        log.info("Rejecting registration request: id={}", id);

        UUID adminId = extractUserId(authentication);

        CollaboratorRegistrationRequestDTO result = registrationRequestService.rejectRequest(id, dto, adminId);

        return ResponseEntity.ok(result);
    }

    /**
     * Get count of pending requests.
     *
     * GET /api/admin/registration-requests/pending-count
     */
    @GetMapping("/pending-count")
    public ResponseEntity<Long> getPendingCount() {
        long count = registrationRequestService.countPendingRequests();
        return ResponseEntity.ok(count);
    }

    /**
     * Delete a registration request.
     *
     * DELETE /api/admin/registration-requests/{id}
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteRegistrationRequest(
            @PathVariable UUID id) {

        log.info("Deleting registration request: id={}", id);

        registrationRequestService.deleteRequest(id);

        return ResponseEntity.noContent().build();
    }

    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}
