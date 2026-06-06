package com.example.evstation.notification.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PushTokenJpaRepository extends JpaRepository<PushTokenEntity, UUID> {

    List<PushTokenEntity> findByUserIdAndIsActiveTrue(UUID userId);

    Optional<PushTokenEntity> findByToken(String token);

    boolean existsByTokenAndUserId(String token, UUID userId);

    @Modifying
    @Query("UPDATE PushTokenEntity t SET t.isActive = false WHERE t.userId = :userId")
    int deactivateAllForUser(@Param("userId") UUID userId);

    @Modifying
    @Query("UPDATE PushTokenEntity t SET t.lastUsedAt = :now WHERE t.token = :token")
    int touchToken(@Param("token") String token, @Param("now") Instant now);

    void deleteByUserId(UUID userId);
}
