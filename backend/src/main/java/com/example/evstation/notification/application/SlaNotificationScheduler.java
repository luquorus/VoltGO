package com.example.evstation.notification.application;

import com.example.evstation.notification.api.dto.CreateNotificationDTO;
import com.example.evstation.notification.domain.NotificationCategory;
import com.example.evstation.notification.domain.NotificationType;
import com.example.evstation.verification.domain.VerificationTaskStatus;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Scheduled job to send SLA notifications for verification tasks.
 * Runs every hour to check for approaching and overdue tasks.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SlaNotificationScheduler {

    private final VerificationTaskJpaRepository taskRepository;
    private final NotificationService notificationService;
    private final com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository stationVersionRepository;

    private static final Duration APPROACHING_THRESHOLD = Duration.ofHours(24);

    /**
     * Check for tasks approaching SLA deadline (24h warning).
     * Runs every hour.
     */
    @Scheduled(fixedRate = 3600000)
    @Transactional(readOnly = true)
    public void notifyApproachingDeadline() {
        log.info("[SLA] Checking for tasks approaching deadline...");
        Instant now = Instant.now();
        Instant approachingThreshold = now.plus(APPROACHING_THRESHOLD);

        List<VerificationTaskStatus> activeStatuses = List.of(
                VerificationTaskStatus.ASSIGNED,
                VerificationTaskStatus.CHECKED_IN
        );

        for (VerificationTaskStatus status : activeStatuses) {
            var tasks = taskRepository.findByStatusOrderByCreatedAtDesc(status);
            for (var task : tasks) {
                if (task.getSlaDueAt() == null || task.getAssignedTo() == null) continue;

                Instant dueAt = task.getSlaDueAt();
                if (dueAt.isAfter(now) && dueAt.isBefore(approachingThreshold)) {
                    long hoursRemaining = Duration.between(now, dueAt).toHours();
                    String stationName = getStationName(task.getStationId());

                    try {
                        notificationService.send(CreateNotificationDTO.builder()
                                .recipientId(task.getAssignedTo())
                                .type(NotificationType.TASK_SLA_APPROACHING)
                                .category(NotificationCategory.TASK)
                                .title("Task Deadline Approaching")
                                .body("Task for '" + stationName + "' is due in " + hoursRemaining + " hours")
                                .data(java.util.Map.of(
                                        "taskId", task.getId().toString(),
                                        "stationId", task.getStationId().toString(),
                                        "stationName", stationName,
                                        "hoursRemaining", hoursRemaining,
                                        "slaDueAt", dueAt.toString()
                                ))
                                .referenceId(task.getId())
                                .referenceType("VERIFICATION_TASK")
                                .build());
                        log.info("[SLA] Approaching notification sent: taskId={}, hoursRemaining={}",
                                task.getId(), hoursRemaining);
                    } catch (Exception e) {
                        log.warn("[SLA] Failed to send approaching notification: {}", e.getMessage());
                    }
                }
            }
        }
        log.info("[SLA] Approaching deadline check complete.");
    }

    /**
     * Check for overdue tasks.
     * Runs every 30 minutes.
     */
    @Scheduled(fixedRate = 1800000)
    @Transactional(readOnly = true)
    public void notifyOverdueTasks() {
        log.info("[SLA] Checking for overdue tasks...");
        Instant now = Instant.now();

        List<VerificationTaskStatus> activeStatuses = List.of(
                VerificationTaskStatus.ASSIGNED,
                VerificationTaskStatus.CHECKED_IN
        );

        for (VerificationTaskStatus status : activeStatuses) {
            var tasks = taskRepository.findByStatusOrderByCreatedAtDesc(status);
            for (var task : tasks) {
                if (task.getSlaDueAt() == null || task.getAssignedTo() == null) continue;

                Instant dueAt = task.getSlaDueAt();
                if (dueAt.isBefore(now)) {
                    long overdueHours = Duration.between(dueAt, now).toHours();
                    String stationName = getStationName(task.getStationId());

                    try {
                        notificationService.send(CreateNotificationDTO.builder()
                                .recipientId(task.getAssignedTo())
                                .type(NotificationType.TASK_SLA_OVERDUE)
                                .category(NotificationCategory.TASK)
                                .title("Task Overdue")
                                .body("Task for '" + stationName + "' is overdue. Please complete it as soon as possible.")
                                .data(java.util.Map.of(
                                        "taskId", task.getId().toString(),
                                        "stationId", task.getStationId().toString(),
                                        "stationName", stationName,
                                        "overdueHours", overdueHours,
                                        "slaDueAt", dueAt.toString()
                                ))
                                .referenceId(task.getId())
                                .referenceType("VERIFICATION_TASK")
                                .build());
                        log.info("[SLA] Overdue notification sent: taskId={}, overdueHours={}",
                                task.getId(), overdueHours);
                    } catch (Exception e) {
                        log.warn("[SLA] Failed to send overdue notification: {}", e.getMessage());
                    }
                }
            }
        }
        log.info("[SLA] Overdue tasks check complete.");
    }

    private String getStationName(UUID stationId) {
        try {
            return stationVersionRepository.findPublishedByStationId(stationId)
                    .map(sv -> sv.getName())
                    .orElse("Station " + stationId.toString().substring(0, 8));
        } catch (Exception e) {
            return "Station " + stationId.toString().substring(0, 8);
        }
    }
}
