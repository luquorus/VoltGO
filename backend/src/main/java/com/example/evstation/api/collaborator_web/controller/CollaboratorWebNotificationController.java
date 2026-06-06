package com.example.evstation.api.collaborator_web.controller;

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
@RequestMapping("/api/collab/web/notifications")
@PreAuthorize("hasRole('COLLABORATOR')")
@RequiredArgsConstructor
@Tag(name = "Collaborator Web - Notifications", description = "Notification management for collaborator web")
public class CollaboratorWebNotificationController {

    private final NotificationService notificationService;

    @Operation(summary = "Get notifications", description = "Get paginated notifications for the current collaborator")
    @GetMapping
    public ResponseEntity<NotificationPageDTO> getNotifications(
            @RequestParam(required = false) String category,
            @RequestParam(required = false) Boolean isRead,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Getting notifications for user={} category={} isRead={} page={}", userId, category, isRead, page);
        return ResponseEntity.ok(notificationService.getNotifications(userId, category, isRead, page, size));
    }

    @Operation(summary = "Get unread count")
    @GetMapping("/unread-count")
    public ResponseEntity<Long> getUnreadCount(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        var result = notificationService.getNotifications(userId, null, false, 0, 1);
        return ResponseEntity.ok(result.getUnreadCount());
    }

    @Operation(summary = "Mark notification as read")
    @PatchMapping("/{notificationId}/read")
    public ResponseEntity<Void> markAsRead(@PathVariable UUID notificationId, Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.markAsRead(notificationId, userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Mark all notifications as read")
    @PatchMapping("/read-all")
    public ResponseEntity<Void> markAllAsRead(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.markAllAsRead(userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Register FCM push token")
    @PostMapping("/push-token")
    public ResponseEntity<Void> registerPushToken(
            @Valid @RequestBody RegisterPushTokenDTO dto,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.registerPushToken(userId, dto.getToken(), dto.getDeviceType());
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "Unregister FCM push token")
    @DeleteMapping("/push-token")
    public ResponseEntity<Void> unregisterPushToken(
            @RequestBody RegisterPushTokenDTO dto,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.unregisterPushToken(userId, dto.getToken());
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Get notification preferences")
    @GetMapping("/preferences")
    public ResponseEntity<NotificationPreferenceDTO> getPreferences(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        return ResponseEntity.ok(notificationService.getPreferences(userId));
    }

    @Operation(summary = "Save notification preferences")
    @PutMapping("/preferences")
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
