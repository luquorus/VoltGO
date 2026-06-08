package com.example.evstation.notification.infrastructure.jpa;

import com.example.evstation.notification.domain.NotificationCategory;
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
public interface CollaboratorNotificationJpaRepository extends JpaRepository<CollaboratorNotificationEntity, UUID> {

    Page<CollaboratorNotificationEntity> findByRecipientIdOrderByCreatedAtDesc(UUID recipientId, Pageable pageable);

    Page<CollaboratorNotificationEntity> findByRecipientIdAndCategoryOrderByCreatedAtDesc(UUID recipientId, NotificationCategory category, Pageable pageable);

    Page<CollaboratorNotificationEntity> findByRecipientIdAndCategoryAndIsReadOrderByCreatedAtDesc(UUID recipientId, NotificationCategory category, Boolean isRead, Pageable pageable);

    Page<CollaboratorNotificationEntity> findByRecipientIdAndIsReadOrderByCreatedAtDesc(UUID recipientId, Boolean isRead, Pageable pageable);

    long countByRecipientIdAndIsRead(UUID recipientId, Boolean isRead);

    @Modifying
    @Query("UPDATE CollaboratorNotificationEntity n SET n.isRead = true WHERE n.recipientId = :recipientId AND n.isRead = false")
    int markAllAsRead(@Param("recipientId") UUID recipientId);

    @Modifying
    @Query("UPDATE CollaboratorNotificationEntity n SET n.isRead = true WHERE n.id = :id AND n.recipientId = :recipientId")
    int markAsRead(@Param("id") UUID id, @Param("recipientId") UUID recipientId);

    List<CollaboratorNotificationEntity> findByRecipientIdAndCreatedAtBetweenOrderByCreatedAtDesc(UUID recipientId, Instant start, Instant end);

    void deleteByRecipientId(UUID recipientId);
}
