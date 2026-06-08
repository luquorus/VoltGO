package com.example.evstation.notification.api.controller;

import com.example.evstation.notification.api.dto.*;
import com.example.evstation.notification.application.NotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/collab/notifications")
@RequiredArgsConstructor
@Tag(name = "Collaborator Mobile - Notifications", description = "Notification management for collaborators")
public class CollabMobileNotificationController {

    private final NotificationService notificationService;

    @Operation(summary = "Get notifications", description = "Get paginated notifications for the current collaborator")
    @GetMapping
    @PreAuthorize("hasAnyRole('COLLABORATOR', 'ADMIN')")
    public ResponseEntity<NotificationPageDTO> getNotifications(
            @Parameter(description = "Filter by category: TASK, CONTRACT, STATION, ALL")
            @RequestParam(required = false) String category,
            @Parameter(description = "Filter by read status: true=read, false=unread")
            @RequestParam(required = false) Boolean isRead,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Getting notifications for user={} category={} isRead={} page={}", userId, category, isRead, page);
        return ResponseEntity.ok(notificationService.getNotifications(userId, category, isRead, page, size));
    }

    @Operation(summary = "Get unread count", description = "Get count of unread notifications")
    @GetMapping("/unread-count")
    @PreAuthorize("hasAnyRole('COLLABORATOR', 'ADMIN')")
    public ResponseEntity<Long> getUnreadCount(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        var page = notificationService.getNotifications(userId, null, false, 0, 1);
        return ResponseEntity.ok(page.getUnreadCount());
    }

    @Operation(summary = "Mark notification as read")
    @PatchMapping("/{notificationId}/read")
    @PreAuthorize("hasAnyRole('COLLABORATOR', 'ADMIN')")
    public ResponseEntity<Void> markAsRead(
            @PathVariable UUID notificationId,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.markAsRead(notificationId, userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Mark all notifications as read")
    @PatchMapping("/read-all")
    @PreAuthorize("hasAnyRole('COLLABORATOR', 'ADMIN')")
    public ResponseEntity<Void> markAllAsRead(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.markAllAsRead(userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Register FCM push token", description = "Register a Firebase Cloud Messaging token for the current device")
    @PostMapping("/push-token")
    @PreAuthorize("hasAnyRole('COLLABORATOR', 'ADMIN')")
    public ResponseEntity<Void> registerPushToken(
            @Valid @RequestBody RegisterPushTokenDTO dto,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.registerPushToken(userId, dto.getToken(), dto.getDeviceType());
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "Unregister FCM push token")
    @DeleteMapping("/push-token")
    @PreAuthorize("hasAnyRole('COLLABORATOR', 'ADMIN')")
    public ResponseEntity<Void> unregisterPushToken(
            @RequestBody RegisterPushTokenDTO dto,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.unregisterPushToken(userId, dto.getToken());
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Get notification preferences")
    @GetMapping("/preferences")
    @PreAuthorize("hasAnyRole('COLLABORATOR', 'ADMIN')")
    public ResponseEntity<NotificationPreferenceDTO> getPreferences(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        return ResponseEntity.ok(notificationService.getPreferences(userId));
    }

    @Operation(summary = "Save notification preferences")
    @PutMapping("/preferences")
    @PreAuthorize("hasAnyRole('COLLABORATOR', 'ADMIN')")
    public ResponseEntity<Void> savePreferences(
            @Valid @RequestBody NotificationPreferenceDTO dto,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.savePreferences(userId, dto.getPreferences());
        return ResponseEntity.ok().build();
    }

    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}
