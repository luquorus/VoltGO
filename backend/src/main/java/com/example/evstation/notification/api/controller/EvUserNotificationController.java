package com.example.evstation.notification.api.controller;

import com.example.evstation.notification.api.dto.EvUserNotificationPageDTO;
import com.example.evstation.notification.application.EvUserNotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/ev/notifications")
@RequiredArgsConstructor
@Tag(name = "EV User Mobile - Notifications", description = "Notification management for EV users")
public class EvUserNotificationController {

    private final EvUserNotificationService notificationService;

    @Operation(summary = "Get notifications", description = "Get paginated notifications for the current EV user")
    @GetMapping
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<EvUserNotificationPageDTO> getNotifications(
            @Parameter(description = "Filter by category: BOOKING, BATTERY_SWAP, STATION, SYSTEM, ALL")
            @RequestParam(required = false) String category,
            @Parameter(description = "Filter by read status: true=read, false=unread")
            @RequestParam(required = false) Boolean isRead,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        log.info("Getting notifications for EV user={} category={} isRead={} page={}", userId, category, isRead, page);
        return ResponseEntity.ok(notificationService.getNotifications(userId, category, isRead, page, size));
    }

    @Operation(summary = "Get unread count", description = "Get count of unread notifications")
    @GetMapping("/unread-count")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<Long> getUnreadCount(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        long count = notificationService.getUnreadCount(userId);
        return ResponseEntity.ok(count);
    }

    @Operation(summary = "Mark notification as read")
    @PatchMapping("/{notificationId}/read")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<Void> markAsRead(
            @PathVariable UUID notificationId,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.markAsRead(notificationId, userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Mark all notifications as read")
    @PatchMapping("/read-all")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<Void> markAllAsRead(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        notificationService.markAllAsRead(userId);
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
