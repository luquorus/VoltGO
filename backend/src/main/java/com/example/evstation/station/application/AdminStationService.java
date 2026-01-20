package com.example.evstation.station.application;

import com.example.evstation.api.admin_web.dto.AdminStationDTO;
import com.example.evstation.api.admin_web.dto.CreateStationDTO;
import com.example.evstation.api.admin_web.dto.UpdateStationDTO;
import com.example.evstation.auth.infrastructure.jpa.UserAccountEntity;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.booking.application.ChargerUnitCreationService;
import com.example.evstation.booking.infrastructure.jpa.BookingJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.domain.*;
import com.example.evstation.station.infrastructure.jpa.*;
import com.example.evstation.trust.infrastructure.jpa.StationTrustEntity;
import com.example.evstation.trust.infrastructure.jpa.StationTrustJpaRepository;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdminStationService {
    
    private final StationJpaRepository stationRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final StationServiceJpaRepository stationServiceRepository;
    private final ChargingPortJpaRepository chargingPortRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final BookingJpaRepository bookingRepository;
    private final StationTrustJpaRepository trustRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final ChargerUnitCreationService chargerUnitCreationService;
    
    private static final GeometryFactory GEOMETRY_FACTORY = new GeometryFactory(new PrecisionModel(), 4326);
    
    /**
     * Get all stations with pagination (admin only)
     */
    @Transactional(readOnly = true)
    public Page<AdminStationDTO> getAllStations(Pageable pageable) {
        log.info("Admin getting all stations: page={}, size={}", pageable.getPageNumber(), pageable.getPageSize());
        
        Page<StationEntity> stations = stationRepository.findAll(pageable);
        
        return stations.map(this::buildAdminStationDTO);
    }
    
    /**
     * Get station detail by ID (admin only)
     */
    @Transactional(readOnly = true)
    public Optional<AdminStationDTO> getStationById(UUID stationId) {
        log.info("Admin getting station: {}", stationId);
        
        return stationRepository.findById(stationId)
                .map(this::buildAdminStationDTO);
    }
    
    /**
     * Create a new station (admin only, bypass workflow)
     */
    @Transactional
    public AdminStationDTO createStation(CreateStationDTO request, UUID adminId) {
        log.info("Admin creating station: name={}, publishImmediately={}", 
                request.getStationData().getName(), request.getPublishImmediately());
        
        // Validate request
        validateStationData(request.getStationData());
        
        // Create station entity
        StationEntity station = StationEntity.builder()
                .id(UUID.randomUUID())
                .providerId(request.getProviderId())
                .createdAt(Instant.now())
                .build();
        stationRepository.save(station);
        log.info("Created station: {}", station.getId());
        
        // Create station version
        CreateStationDTO.StationDataDTO data = request.getStationData();
        Point location = createPoint(data.getLocation().getLng(), data.getLocation().getLat());
        
        int versionNo = 1;
        WorkflowStatus workflowStatus = Boolean.TRUE.equals(request.getPublishImmediately()) 
                ? WorkflowStatus.PUBLISHED 
                : WorkflowStatus.DRAFT;
        
        StationVersionEntity stationVersion = StationVersionEntity.builder()
                .id(UUID.randomUUID())
                .stationId(station.getId())
                .versionNo(versionNo)
                .workflowStatus(workflowStatus)
                .name(data.getName())
                .address(data.getAddress())
                .location(location)
                .operatingHours(data.getOperatingHours())
                .parking(data.getParking())
                .visibility(data.getVisibility())
                .publicStatus(data.getPublicStatus())
                .createdBy(adminId)
                .createdAt(Instant.now())
                .publishedAt(Boolean.TRUE.equals(request.getPublishImmediately()) ? Instant.now() : null)
                .build();
        stationVersionRepository.save(stationVersion);
        log.info("Created station version: {}, status={}", stationVersion.getId(), workflowStatus);
        
        // Create services and charging ports
        createServicesAndPorts(stationVersion.getId(), data.getServices());
        
        // If publishing immediately, automatically create charger units
        if (Boolean.TRUE.equals(request.getPublishImmediately())) {
            try {
                List<UUID> createdUnitIds = chargerUnitCreationService.createChargerUnitsFromChargingPorts(stationVersion);
                log.info("Created {} charger units for published station version: {}", 
                        createdUnitIds.size(), stationVersion.getId());
            } catch (Exception e) {
                log.error("Failed to create charger units for station version: {}", 
                        stationVersion.getId(), e);
                // Don't fail the create operation if charger unit creation fails
            }
        }
        
        // Write audit log
        writeAuditLog(adminId, "ADMIN", "CREATE_STATION", "station", station.getId(), 
                java.util.Map.of("versionId", stationVersion.getId().toString(), 
                                "publishImmediately", request.getPublishImmediately()));
        
        return buildAdminStationDTO(station);
    }
    
    /**
     * Update station (admin only, creates new version)
     */
    @Transactional
    public AdminStationDTO updateStation(UUID stationId, UpdateStationDTO request, UUID adminId) {
        log.info("Admin updating station: {}, publishImmediately={}", stationId, request.getPublishImmediately());
        
        // Validate station exists
        StationEntity station = stationRepository.findById(stationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Station not found: " + stationId));
        
        // Validate request
        validateStationData(request.getStationData());
        
        // Get current published version to determine next version number
        Optional<StationVersionEntity> currentPublished = stationVersionRepository
                .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED);
        
        int nextVersionNo = currentPublished
                .map(v -> v.getVersionNo() + 1)
                .orElse(1);
        
        // Create new version
        UpdateStationDTO.StationDataDTO data = request.getStationData();
        Point location = createPoint(data.getLocation().getLng(), data.getLocation().getLat());
        
        WorkflowStatus workflowStatus = Boolean.TRUE.equals(request.getPublishImmediately()) 
                ? WorkflowStatus.PUBLISHED 
                : WorkflowStatus.DRAFT;
        
        StationVersionEntity newVersion = StationVersionEntity.builder()
                .id(UUID.randomUUID())
                .stationId(stationId)
                .versionNo(nextVersionNo)
                .workflowStatus(workflowStatus)
                .name(data.getName())
                .address(data.getAddress())
                .location(location)
                .operatingHours(data.getOperatingHours())
                .parking(data.getParking())
                .visibility(data.getVisibility())
                .publicStatus(data.getPublicStatus())
                .createdBy(adminId)
                .createdAt(Instant.now())
                .publishedAt(Boolean.TRUE.equals(request.getPublishImmediately()) ? Instant.now() : null)
                .build();
        stationVersionRepository.save(newVersion);
        log.info("Created new station version: {}, status={}", newVersion.getId(), workflowStatus);
        
        // If publishing immediately, archive old published version
        if (Boolean.TRUE.equals(request.getPublishImmediately()) && currentPublished.isPresent()) {
            StationVersionEntity oldVersion = currentPublished.get();
            oldVersion.setWorkflowStatus(WorkflowStatus.ARCHIVED);
            oldVersion.setPublishedAt(null); // Clear published_at when archiving
            stationVersionRepository.save(oldVersion);
            log.info("Archived old published version: {}", oldVersion.getId());
        }
        
        // Create services and charging ports
        createServicesAndPorts(newVersion.getId(), data.getServices());
        
        // If publishing immediately, automatically create charger units
        if (Boolean.TRUE.equals(request.getPublishImmediately())) {
            try {
                List<UUID> createdUnitIds = chargerUnitCreationService.createChargerUnitsFromChargingPorts(newVersion);
                log.info("Created {} charger units for published station version: {}", 
                        createdUnitIds.size(), newVersion.getId());
            } catch (Exception e) {
                log.error("Failed to create charger units for station version: {}", 
                        newVersion.getId(), e);
                // Don't fail the update operation if charger unit creation fails
            }
        }
        
        // Write audit log
        writeAuditLog(adminId, "ADMIN", "UPDATE_STATION", "station", stationId,
                java.util.Map.of("versionId", newVersion.getId().toString(),
                                "versionNo", nextVersionNo,
                                "publishImmediately", request.getPublishImmediately()));
        
        return buildAdminStationDTO(station);
    }
    
    /**
     * Delete station (hard delete - permanently remove from database)
     * Due to ON DELETE CASCADE constraints, deleting station will automatically delete:
     * - All station_versions
     * - All station_services (via station_version)
     * - All charging_ports (via station_service)
     * - All bookings
     * - All change_requests
     * - All station_trust records
     * - All verification_tasks
     * - All report_issues
     */
    @Transactional
    public void deleteStation(UUID stationId, UUID adminId) {
        log.info("Admin deleting station (hard delete): {}", stationId);
        
        StationEntity station = stationRepository.findById(stationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Station not found: " + stationId));
        
        // Check if there are active bookings
        long activeBookings = bookingRepository.findAll().stream()
                .filter(b -> b.getStationId().equals(stationId) &&
                        (b.getStatus() == com.example.evstation.booking.domain.BookingStatus.HOLD ||
                         b.getStatus() == com.example.evstation.booking.domain.BookingStatus.CONFIRMED))
                .count();
        
        if (activeBookings > 0) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Cannot delete station with active bookings. Please cancel all bookings first.");
        }
        
        // Write audit log before deletion (so we have record even after station is deleted)
        writeAuditLog(adminId, "ADMIN", "DELETE_STATION", "station", stationId, null);
        
        // Hard delete: Delete station entity
        // Due to ON DELETE CASCADE, all related records will be automatically deleted:
        // - station_version (ON DELETE CASCADE)
        // - station_service (via station_version CASCADE)
        // - charging_port (via station_service CASCADE)
        // - booking (ON DELETE CASCADE)
        // - change_request (ON DELETE CASCADE)
        // - station_trust (ON DELETE CASCADE)
        // - verification_task (ON DELETE CASCADE)
        // - report_issue (ON DELETE CASCADE)
        stationRepository.delete(station);
        
        log.info("Permanently deleted station and all related data: {}", stationId);
    }
    
    // ========== Private Helper Methods ==========
    
    private void validateStationData(Object stationData) {
        List<?> services = null;
        
        if (stationData instanceof CreateStationDTO.StationDataDTO createData) {
            services = createData.getServices();
        } else if (stationData instanceof UpdateStationDTO.StationDataDTO updateData) {
            services = updateData.getServices();
        }
        
        if (services != null) {
            validateServices(services);
        }
    }
    
    private void validateServices(List<?> services) {
        if (services == null || services.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "At least one service is required");
        }
        
        for (Object serviceObj : services) {
            List<?> chargingPorts = null;
            
            if (serviceObj instanceof CreateStationDTO.ServiceDTO createService) {
                if (createService.getType() == ServiceType.CHARGING) {
                    chargingPorts = createService.getChargingPorts();
                }
            } else if (serviceObj instanceof UpdateStationDTO.ServiceDTO updateService) {
                if (updateService.getType() == ServiceType.CHARGING) {
                    chargingPorts = updateService.getChargingPorts();
                }
            }
            
            if (chargingPorts != null) {
                if (chargingPorts.isEmpty()) {
                    throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                            "At least one charging port is required for CHARGING service");
                }
                
                for (Object portObj : chargingPorts) {
                    PowerType powerType = null;
                    java.math.BigDecimal powerKw = null;
                    
                    if (portObj instanceof CreateStationDTO.ChargingPortDTO createPort) {
                        powerType = createPort.getPowerType();
                        powerKw = createPort.getPowerKw();
                    } else if (portObj instanceof UpdateStationDTO.ChargingPortDTO updatePort) {
                        powerType = updatePort.getPowerType();
                        powerKw = updatePort.getPowerKw();
                    }
                    
                    if (powerType == PowerType.DC && (powerKw == null || powerKw.doubleValue() <= 0)) {
                        throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                                "DC charging ports must have powerKw > 0");
                    }
                }
            }
        }
    }
    
    private void createServicesAndPorts(UUID stationVersionId, List<?> services) {
        List<StationServiceEntity> savedServices = new ArrayList<>();
        List<ChargingPortEntity> savedPorts = new ArrayList<>();
        
        for (Object serviceObj : services) {
            if (serviceObj instanceof CreateStationDTO.ServiceDTO createService) {
                if (createService.getType() == ServiceType.CHARGING) {
                    StationServiceEntity service = StationServiceEntity.builder()
                            .id(UUID.randomUUID())
                            .stationVersionId(stationVersionId)
                            .serviceType(ServiceType.CHARGING)
                            .build();
                    stationServiceRepository.save(service);
                    savedServices.add(service);
                    
                    for (var portDTO : createService.getChargingPorts()) {
                        ChargingPortEntity port = ChargingPortEntity.builder()
                                .id(UUID.randomUUID())
                                .stationServiceId(service.getId())
                                .powerType(portDTO.getPowerType())
                                .powerKw(portDTO.getPowerKw())
                                .portCount(portDTO.getCount())
                                .build();
                        chargingPortRepository.save(port);
                        savedPorts.add(port);
                    }
                }
            } else if (serviceObj instanceof UpdateStationDTO.ServiceDTO updateService) {
                if (updateService.getType() == ServiceType.CHARGING) {
                    StationServiceEntity service = StationServiceEntity.builder()
                            .id(UUID.randomUUID())
                            .stationVersionId(stationVersionId)
                            .serviceType(ServiceType.CHARGING)
                            .build();
                    stationServiceRepository.save(service);
                    savedServices.add(service);
                    
                    for (var portDTO : updateService.getChargingPorts()) {
                        ChargingPortEntity port = ChargingPortEntity.builder()
                                .id(UUID.randomUUID())
                                .stationServiceId(service.getId())
                                .powerType(portDTO.getPowerType())
                                .powerKw(portDTO.getPowerKw())
                                .portCount(portDTO.getCount())
                                .build();
                        chargingPortRepository.save(port);
                        savedPorts.add(port);
                    }
                }
            }
        }
        
        log.info("Created {} services and {} ports for station version: {}", 
                savedServices.size(), savedPorts.size(), stationVersionId);
    }
    
    private Point createPoint(double lng, double lat) {
        Coordinate coordinate = new Coordinate(lng, lat);
        return GEOMETRY_FACTORY.createPoint(coordinate);
    }
    
    private AdminStationDTO buildAdminStationDTO(StationEntity station) {
        // Get published version
        Optional<StationVersionEntity> publishedVersion = stationVersionRepository
                .findByStationIdAndWorkflowStatus(station.getId(), WorkflowStatus.PUBLISHED);
        
        // Get provider info
        String providerEmail = null;
        if (station.getProviderId() != null) {
            providerEmail = userAccountRepository.findById(station.getProviderId())
                    .map(UserAccountEntity::getEmail)
                    .orElse(null);
        }
        
        // Get trust score
        Integer trustScore = trustRepository.findById(station.getId())
                .map(StationTrustEntity::getScore)
                .orElse(null);
        
        // Count total versions
        long totalVersions = stationVersionRepository.findAll().stream()
                .filter(v -> v.getStationId().equals(station.getId()))
                .count();
        
        // Re-fetch station to ensure we have latest data
        StationEntity stationEntity = station;
        
        // Count active bookings
        long activeBookings = bookingRepository.findAll().stream()
                .filter(b -> b.getStationId().equals(station.getId()) &&
                        (b.getStatus() == com.example.evstation.booking.domain.BookingStatus.HOLD ||
                         b.getStatus() == com.example.evstation.booking.domain.BookingStatus.CONFIRMED))
                .count();
        
        if (publishedVersion.isEmpty()) {
            // No published version - return basic info
        return AdminStationDTO.builder()
                .stationId(stationEntity.getId())
                .providerId(stationEntity.getProviderId())
                .providerEmail(providerEmail)
                .stationCreatedAt(stationEntity.getCreatedAt())
                .workflowStatus(null)
                .trustScore(trustScore)
                .totalVersions(totalVersions)
                .activeBookings(activeBookings)
                .build();
        }
        
        StationVersionEntity version = publishedVersion.get();
        
        // Get services and ports
        List<StationServiceEntity> services = stationServiceRepository
                .findByStationVersionId(version.getId());
        List<UUID> serviceIds = services.stream().map(StationServiceEntity::getId).toList();
        List<ChargingPortEntity> ports = serviceIds.isEmpty() ? List.of() :
                chargingPortRepository.findByStationServiceIds(serviceIds);
        
        // Build services DTO
        List<AdminStationDTO.ServiceDTO> serviceDTOs = services.stream()
                .map(service -> {
                    List<AdminStationDTO.ChargingPortDTO> portDTOs = ports.stream()
                            .filter(p -> p.getStationServiceId().equals(service.getId()))
                            .map(p -> AdminStationDTO.ChargingPortDTO.builder()
                                    .powerType(p.getPowerType())
                                    .powerKw(p.getPowerKw())
                                    .portCount(p.getPortCount())
                                    .build())
                            .collect(Collectors.toList());
                    
                    return AdminStationDTO.ServiceDTO.builder()
                            .type(service.getServiceType())
                            .chargingPorts(portDTOs)
                            .build();
                })
                .collect(Collectors.toList());
        
        // Get created by email
        String createdByEmail = userAccountRepository.findById(version.getCreatedBy())
                .map(UserAccountEntity::getEmail)
                .orElse(null);
        
        // Extract lat/lng from PostGIS point
        Double lat = version.getLocation() != null ? version.getLocation().getY() : null;
        Double lng = version.getLocation() != null ? version.getLocation().getX() : null;
        
        return AdminStationDTO.builder()
                .stationId(stationEntity.getId())
                .providerId(stationEntity.getProviderId())
                .providerEmail(providerEmail)
                .stationCreatedAt(stationEntity.getCreatedAt())
                .publishedVersionId(version.getId())
                .publishedVersionNo(version.getVersionNo())
                .workflowStatus(version.getWorkflowStatus())
                .name(version.getName())
                .address(version.getAddress())
                .lat(lat)
                .lng(lng)
                .operatingHours(version.getOperatingHours())
                .parking(version.getParking())
                .visibility(version.getVisibility())
                .publicStatus(version.getPublicStatus())
                .publishedAt(version.getPublishedAt())
                .createdBy(version.getCreatedBy())
                .createdByEmail(createdByEmail)
                .services(serviceDTOs)
                .trustScore(trustScore)
                .totalVersions(totalVersions)
                .activeBookings(activeBookings)
                .build();
    }
    
    private void writeAuditLog(UUID actorId, String actorRole, String action,
                              String entityType, UUID entityId, Map<String, Object> metadata) {
        AuditLogEntity auditLog = AuditLogEntity.builder()
                .actorId(actorId)
                .actorRole(actorRole)
                .action(action)
                .entityType(entityType)
                .entityId(entityId)
                .metadata(metadata)
                .createdAt(Instant.now())
                .build();
        auditLogRepository.save(auditLog);
        log.debug("Audit log written: action={}, entityType={}, entityId={}", action, entityType, entityId);
    }
}

