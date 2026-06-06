package com.example.evstation.notification.infrastructure.jpa;

import com.example.evstation.notification.domain.NotificationCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface NotificationPreferenceJpaRepository extends JpaRepository<NotificationPreferenceEntity, UUID> {

    List<NotificationPreferenceEntity> findByUserId(UUID userId);

    Optional<NotificationPreferenceEntity> findByUserIdAndCategory(UUID userId, NotificationCategory category);

    void deleteByUserId(UUID userId);
}
