package com.example.evstation.station.application;

import com.example.evstation.api.admin_web.dto.AuditLogResponseDTO;
import com.example.evstation.auth.infrastructure.jpa.UserAccountEntity;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuditLogService {
    
    private final AuditLogJpaRepository auditLogRepository;
    private final UserAccountJpaRepository userAccountRepository;

    /**
     * Query audit logs with optional filters
     */
    @Transactional(readOnly = true)
    public Page<AuditLogResponseDTO> queryAuditLogs(
            String entityType,
            UUID entityId,
            Instant from,
            Instant to,
            Pageable pageable) {
        
        log.info("Querying audit logs: entityType={}, entityId={}, from={}, to={}", 
                entityType, entityId, from, to);
        
        Page<AuditLogEntity> page;
        
        // Use specific query methods based on filters to avoid NULL parameter issues
        if (entityType != null && entityId != null) {
            page = auditLogRepository.findByEntityTypeAndEntityIdOrderByCreatedAtDesc(
                    entityType, entityId, pageable);
        } else if (entityType != null) {
            page = auditLogRepository.findByEntityTypeOrderByCreatedAtDesc(entityType, pageable);
        } else {
            page = auditLogRepository.findAllByOrderByCreatedAtDesc(pageable);
        }
        
        // TODO: Apply from/to date filtering if needed (can add more query methods)
        
        // Collect unique actor IDs
        List<UUID> actorIds = page.getContent().stream()
                .map(AuditLogEntity::getActorId)
                .distinct()
                .toList();
        
        // Load actor emails
        Map<UUID, String> actorEmails = loadActorEmails(actorIds);
        
        return page.map(entity -> buildDTO(entity, actorEmails));
    }

    /**
     * Get audit logs for a specific station (including versions and change requests)
     */
    @Transactional(readOnly = true)
    public List<AuditLogResponseDTO> getStationAuditLogs(UUID stationId) {
        log.info("Getting audit logs for station: {}", stationId);
        
        List<AuditLogEntity> logs = auditLogRepository.findByStationId(stationId);
        
        List<UUID> actorIds = logs.stream()
                .map(AuditLogEntity::getActorId)
                .distinct()
                .toList();
        
        Map<UUID, String> actorEmails = loadActorEmails(actorIds);
        
        return logs.stream()
                .map(entity -> buildDTO(entity, actorEmails))
                .collect(Collectors.toList());
    }

    /**
     * Get audit logs for a specific change request
     */
    @Transactional(readOnly = true)
    public List<AuditLogResponseDTO> getChangeRequestAuditLogs(UUID changeRequestId) {
        log.info("Getting audit logs for change request: {}", changeRequestId);
        
        List<AuditLogEntity> logs = auditLogRepository
                .findByEntityTypeAndEntityIdOrderByCreatedAtDesc("CHANGE_REQUEST", changeRequestId);
        
        List<UUID> actorIds = logs.stream()
                .map(AuditLogEntity::getActorId)
                .distinct()
                .toList();
        
        Map<UUID, String> actorEmails = loadActorEmails(actorIds);
        
        return logs.stream()
                .map(entity -> buildDTO(entity, actorEmails))
                .collect(Collectors.toList());
    }

    /**
     * Get all audit logs (paginated)
     */
    @Transactional(readOnly = true)
    public Page<AuditLogResponseDTO> getAllAuditLogs(Pageable pageable) {
        log.info("Getting all audit logs");
        
        Page<AuditLogEntity> page = auditLogRepository.findAllByOrderByCreatedAtDesc(pageable);
        
        List<UUID> actorIds = page.getContent().stream()
                .map(AuditLogEntity::getActorId)
                .distinct()
                .toList();
        
        Map<UUID, String> actorEmails = loadActorEmails(actorIds);
        
        return page.map(entity -> buildDTO(entity, actorEmails));
    }

    // ========== Private Helper Methods ==========
    
    private Map<UUID, String> loadActorEmails(List<UUID> actorIds) {
        if (actorIds.isEmpty()) {
            return Map.of();
        }
        
        return userAccountRepository.findAllById(actorIds).stream()
                .collect(Collectors.toMap(
                        UserAccountEntity::getId,
                        UserAccountEntity::getEmail,
                        (a, b) -> a
                ));
    }
    
    private AuditLogResponseDTO buildDTO(AuditLogEntity entity, Map<UUID, String> actorEmails) {
        return AuditLogResponseDTO.builder()
                .id(entity.getId())
                .actorId(entity.getActorId())
                .actorRole(entity.getActorRole())
                .actorEmail(actorEmails.get(entity.getActorId()))
                .action(entity.getAction())
                .entityType(entity.getEntityType())
                .entityId(entity.getEntityId())
                .metadata(entity.getMetadata())
                .createdAt(entity.getCreatedAt())
                .build();
    }
}

