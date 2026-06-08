package com.example.evstation.collaborator.infrastructure.jpa;

import com.example.evstation.collaborator.domain.RegistrationRequestStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CollaboratorRegistrationRequestJpaRepository extends JpaRepository<CollaboratorRegistrationRequestEntity, UUID> {

    Optional<CollaboratorRegistrationRequestEntity> findByEmail(String email);

    List<CollaboratorRegistrationRequestEntity> findByEmailAndStatusIn(String email, List<RegistrationRequestStatus> statuses);

    @Query("SELECT COUNT(r) FROM CollaboratorRegistrationRequestEntity r " +
           "WHERE r.email = :email AND r.createdAt > :since")
    long countByEmailAndCreatedAtAfter(@Param("email") String email, @Param("since") Instant since);

    Page<CollaboratorRegistrationRequestEntity> findByStatus(RegistrationRequestStatus status, Pageable pageable);

    @Query("SELECT r FROM CollaboratorRegistrationRequestEntity r WHERE r.status = :status ORDER BY r.createdAt DESC")
    Page<CollaboratorRegistrationRequestEntity> findByStatusOrderByCreatedAtDesc(
            @Param("status") RegistrationRequestStatus status, Pageable pageable);

    Page<CollaboratorRegistrationRequestEntity> findByStatusNotOrderByCreatedAtDesc(
            RegistrationRequestStatus status, Pageable pageable);

    long countByStatus(RegistrationRequestStatus status);
}
