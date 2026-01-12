package com.example.evstation.collaborator.application;

import com.example.evstation.collaborator.api.dto.CollaboratorLocationDTO;
import com.example.evstation.collaborator.api.dto.UpdateLocationDTO;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileEntity;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.collaborator.infrastructure.jpa.LocationSource;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * Service for managing collaborator location updates.
 * Handles GPS updates from mobile and manual updates from web.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CollaboratorLocationService {
    
    private static final int SRID = 4326;
    private static final GeometryFactory GEOMETRY_FACTORY = new GeometryFactory(new PrecisionModel(), SRID);
    
    private final CollaboratorProfileJpaRepository collaboratorRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final Clock clock;

    /**
     * Update collaborator location from mobile (GPS).
     */
    @Transactional
    public CollaboratorLocationDTO updateLocationFromMobile(UUID userId, UpdateLocationDTO dto) {
        return updateLocation(userId, dto, LocationSource.MOBILE);
    }

    /**
     * Update collaborator location from web (manual).
     */
    @Transactional
    public CollaboratorLocationDTO updateLocationFromWeb(UUID userId, UpdateLocationDTO dto) {
        return updateLocation(userId, dto, LocationSource.WEB);
    }

    /**
     * Get collaborator's current location.
     */
    @Transactional(readOnly = true)
    public CollaboratorLocationDTO getLocation(UUID userId) {
        CollaboratorProfileEntity profile = collaboratorRepository.findByUserAccountId(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Collaborator profile not found"));
        
        if (profile.getCurrentLocation() == null) {
            return CollaboratorLocationDTO.builder()
                    .lat(null)
                    .lng(null)
                    .updatedAt(null)
                    .source(null)
                    .build();
        }
        
        return buildLocationDTO(profile);
    }

    private CollaboratorLocationDTO updateLocation(UUID userId, UpdateLocationDTO dto, LocationSource source) {
        log.info("Updating location for user {} from {}: lat={}, lng={}", 
                userId, source, dto.getLat(), dto.getLng());
        
        CollaboratorProfileEntity profile = collaboratorRepository.findByUserAccountId(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Collaborator profile not found. Please contact admin."));
        
        // Create point geometry (note: Point takes x=lng, y=lat)
        Point location = GEOMETRY_FACTORY.createPoint(new Coordinate(dto.getLng(), dto.getLat()));
        location.setSRID(SRID);
        
        Instant now = Instant.now(clock);
        
        profile.setCurrentLocation(location);
        profile.setLocationUpdatedAt(now);
        profile.setLocationSource(source);
        
        collaboratorRepository.save(profile);
        
        // Write audit log
        writeAuditLog(userId, "UPDATE_COLLABORATOR_LOCATION", profile.getId(),
                Map.of(
                        "lat", dto.getLat(),
                        "lng", dto.getLng(),
                        "source", source.name(),
                        "sourceNote", dto.getSourceNote() != null ? dto.getSourceNote() : ""
                ));
        
        log.info("Location updated for user {}: lat={}, lng={}", userId, dto.getLat(), dto.getLng());
        
        return buildLocationDTO(profile);
    }

    private CollaboratorLocationDTO buildLocationDTO(CollaboratorProfileEntity profile) {
        return CollaboratorLocationDTO.builder()
                .lat(profile.getLatitude())
                .lng(profile.getLongitude())
                .updatedAt(profile.getLocationUpdatedAt())
                .source(profile.getLocationSource() != null ? profile.getLocationSource().name() : null)
                .build();
    }

    private void writeAuditLog(UUID actorId, String action, UUID entityId, Map<String, Object> metadata) {
        AuditLogEntity auditLog = AuditLogEntity.builder()
                .actorId(actorId)
                .actorRole("COLLABORATOR")
                .action(action)
                .entityType("COLLABORATOR_PROFILE")
                .entityId(entityId)
                .metadata(metadata)
                .createdAt(Instant.now(clock))
                .build();
        auditLogRepository.save(auditLog);
        log.debug("Audit log written: action={}, entityId={}", action, entityId);
    }
}

