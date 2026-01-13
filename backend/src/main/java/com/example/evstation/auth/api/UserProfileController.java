package com.example.evstation.auth.api;

import com.example.evstation.auth.api.dto.ChangePasswordRequest;
import com.example.evstation.auth.api.dto.UpdateProfileRequest;
import com.example.evstation.auth.api.dto.UserProfileDTO;
import com.example.evstation.auth.application.UserProfileService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Slf4j
@Tag(name = "User Profile", description = "API for managing user profile")
@RestController
@RequestMapping("/api/profile")
@RequiredArgsConstructor
public class UserProfileController {
    private final UserProfileService userProfileService;

    @Operation(
        summary = "Get my profile",
        description = "Get current user's profile information"
    )
    @GetMapping("/me")
    @PreAuthorize("hasAnyRole('EV_USER', 'PROVIDER', 'COLLABORATOR', 'ADMIN')")
    public ResponseEntity<UserProfileDTO> getMyProfile(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Getting profile for user: {}", userId);
        
        return userProfileService.getProfile(userId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
        summary = "Update my profile",
        description = "Update current user's profile (name, phone)"
    )
    @PutMapping("/me")
    @PreAuthorize("hasAnyRole('EV_USER', 'PROVIDER', 'COLLABORATOR', 'ADMIN')")
    public ResponseEntity<UserProfileDTO> updateMyProfile(
            @Valid @RequestBody UpdateProfileRequest request,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Updating profile for user: {}", userId);
        
        return userProfileService.updateProfile(userId, request)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
        summary = "Change password",
        description = "Change current user's password"
    )
    @PostMapping("/me/change-password")
    @PreAuthorize("hasAnyRole('EV_USER', 'PROVIDER', 'COLLABORATOR', 'ADMIN')")
    public ResponseEntity<Map<String, String>> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Changing password for user: {}", userId);
        
        boolean success = userProfileService.changePassword(userId, request);
        
        if (success) {
            return ResponseEntity.ok(Map.of("message", "Password changed successfully"));
        } else {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("message", "Current password is incorrect"));
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

