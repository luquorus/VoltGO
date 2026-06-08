package com.example.evstation.notification.infrastructure.jpa;

import com.example.evstation.notification.domain.EvUserNotificationCategory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface EvUserNotificationJpaRepository extends JpaRepository<EvUserNotificationEntity, UUID> {

    Page<EvUserNotificationEntity> findByRecipientIdOrderByCreatedAtDesc(UUID recipientId, Pageable pageable);

    Page<EvUserNotificationEntity> findByRecipientIdAndCategoryOrderByCreatedAtDesc(UUID recipientId, EvUserNotificationCategory category, Pageable pageable);

    Page<EvUserNotificationEntity> findByRecipientIdAndCategoryAndIsReadOrderByCreatedAtDesc(UUID recipientId, EvUserNotificationCategory category, Boolean isRead, Pageable pageable);

    Page<EvUserNotificationEntity> findByRecipientIdAndIsReadOrderByCreatedAtDesc(UUID recipientId, Boolean isRead, Pageable pageable);

    long countByRecipientIdAndIsRead(UUID recipientId, Boolean isRead);

    @Modifying
    @Query("UPDATE EvUserNotificationEntity n SET n.isRead = true WHERE n.recipientId = :recipientId AND n.isRead = false")
    int markAllAsRead(@Param("recipientId") UUID recipientId);

    @Modifying
    @Query("UPDATE EvUserNotificationEntity n SET n.isRead = true WHERE n.id = :id AND n.recipientId = :recipientId")
    int markAsRead(@Param("id") UUID id, @Param("recipientId") UUID recipientId);

    List<EvUserNotificationEntity> findByRecipientIdAndCreatedAtBetweenOrderByCreatedAtDesc(UUID recipientId, Instant start, Instant end);

    void deleteByRecipientId(UUID recipientId);
}
