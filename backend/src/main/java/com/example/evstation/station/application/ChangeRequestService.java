package com.example.evstation.station.application;

import com.example.evstation.api.ev_user_mobile.dto.ChangeRequestResponseDTO;
import com.example.evstation.api.ev_user_mobile.dto.CreateChangeRequestDTO;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.risk.application.RiskEngineService;
import com.example.evstation.risk.domain.RiskAssessment;
import com.example.evstation.station.domain.*;
import com.example.evstation.station.infrastructure.jpa.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChangeRequestService {
    
    private final ChangeRequestJpaRepository changeRequestRepository;
    private final StationJpaRepository stationRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final StationServiceJpaRepository stationServiceRepository;
    private final ChargingPortJpaRepository chargingPortRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final RiskEngineService riskEngineService;
    
    private static final GeometryFactory GEOMETRY_FACTORY = new GeometryFactory(new PrecisionModel(), 4326);

    /**
     * Create a new change request (DRAFT status)
     */
    @Transactional
    public ChangeRequestResponseDTO createChangeRequest(CreateChangeRequestDTO request, UUID userId) {
        log.info("Creating change request: type={}, userId={}", request.getType(), userId);
        
        // Validate request based on type
        validateChangeRequest(request);
        
        UUID stationId;
        int versionNo = 1;
        
        if (request.getType() == ChangeRequestType.CREATE_STATION) {
            // Create new station
            StationEntity station = StationEntity.builder()
                    .id(UUID.randomUUID())
                    .providerId(userId)
                    .createdAt(Instant.now())
                    .build();
            stationRepository.save(station);
            stationId = station.getId();
            log.info("Created new station: {}", stationId);
        } else {
            // UPDATE_STATION - validate station exists
            stationId = request.getStationId();
            if (!stationRepository.existsById(stationId)) {
                throw new BusinessException(ErrorCode.NOT_FOUND, "Station not found: " + stationId);
            }
            
            // Get next version number
            Optional<StationVersionEntity> latestVersion = stationVersionRepository
                    .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED);
            versionNo = latestVersion.map(v -> v.getVersionNo() + 1).orElse(1);
        }
        
        // Create station_version with DRAFT status
        CreateChangeRequestDTO.StationDataDTO data = request.getStationData();
        Point location = createPoint(data.getLocation().getLng(), data.getLocation().getLat());
        
        StationVersionEntity stationVersion = StationVersionEntity.builder()
                .id(UUID.randomUUID())
                .stationId(stationId)
                .versionNo(versionNo)
                .workflowStatus(WorkflowStatus.DRAFT)
                .name(data.getName())
                .address(data.getAddress())
                .location(location)
                .operatingHours(data.getOperatingHours())
                .parking(data.getParking())
                .visibility(data.getVisibility())
                .publicStatus(data.getPublicStatus())
                .createdBy(userId)
                .createdAt(Instant.now())
                .build();
        stationVersionRepository.save(stationVersion);
        log.info("Created station version: {}", stationVersion.getId());
        
        // Create station services and charging ports
        List<StationServiceEntity> savedServices = new ArrayList<>();
        List<ChargingPortEntity> savedPorts = new ArrayList<>();
        
        for (CreateChangeRequestDTO.ServiceDTO serviceDto : data.getServices()) {
            StationServiceEntity service = StationServiceEntity.builder()
                    .id(UUID.randomUUID())
                    .stationVersionId(stationVersion.getId())
                    .serviceType(serviceDto.getType())
                    .build();
            stationServiceRepository.save(service);
            savedServices.add(service);
            
            // Create charging ports if service type is CHARGING
            if (serviceDto.getType() == ServiceType.CHARGING && serviceDto.getChargingPorts() != null) {
                for (CreateChangeRequestDTO.ChargingPortDTO portDto : serviceDto.getChargingPorts()) {
                    ChargingPortEntity port = ChargingPortEntity.builder()
                            .id(UUID.randomUUID())
                            .stationServiceId(service.getId())
                            .powerType(portDto.getPowerType())
                            .powerKw(portDto.getPowerKw())
                            .portCount(portDto.getCount())
                            .build();
                    chargingPortRepository.save(port);
                    savedPorts.add(port);
                }
            }
        }
        log.info("Created {} services and {} charging ports", savedServices.size(), savedPorts.size());
        
        // Create change_request with DRAFT status
        ChangeRequestEntity changeRequest = ChangeRequestEntity.builder()
                .id(UUID.randomUUID())
                .type(request.getType())
                .status(ChangeRequestStatus.DRAFT)
                .stationId(request.getType() == ChangeRequestType.UPDATE_STATION ? stationId : null)
                .proposedStationVersionId(stationVersion.getId())
                .submittedBy(userId)
                .riskScore(0)
                .riskReasons(List.of())
                .createdAt(Instant.now())
                .build();
        changeRequestRepository.save(changeRequest);
        log.info("Created change request: {}", changeRequest.getId());
        
        return buildResponse(changeRequest, stationVersion, savedServices, savedPorts);
    }

    /**
     * Submit a change request (DRAFT -> PENDING)
     */
    @Transactional
    public ChangeRequestResponseDTO submitChangeRequest(UUID changeRequestId, UUID userId) {
        log.info("Submitting change request: id={}, userId={}", changeRequestId, userId);
        
        ChangeRequestEntity changeRequest = changeRequestRepository.findById(changeRequestId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Change request not found"));
        
        // Verify ownership
        if (!changeRequest.getSubmittedBy().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "You can only submit your own change requests");
        }
        
        // Verify status is DRAFT
        if (changeRequest.getStatus() != ChangeRequestStatus.DRAFT) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Only DRAFT change requests can be submitted. Current status: " + changeRequest.getStatus());
        }
        
        // Update status to PENDING
        changeRequest.setStatus(ChangeRequestStatus.PENDING);
        changeRequest.setSubmittedAt(Instant.now());
        
        // Update station_version status to PENDING
        StationVersionEntity stationVersion = stationVersionRepository
                .findById(changeRequest.getProposedStationVersionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Station version not found"));
        stationVersion.setWorkflowStatus(WorkflowStatus.PENDING);
        stationVersionRepository.save(stationVersion);
        
        // Run Risk Engine to assess the change request
        RiskAssessment riskAssessment = riskEngineService.assessChangeRequest(changeRequest);
        changeRequest.setRiskScore(riskAssessment.getRiskScore());
        changeRequest.setRiskReasons(riskAssessment.getRiskReasonCodes());
        log.info("Risk assessment: score={}, level={}, reasons={}", 
                riskAssessment.getRiskScore(), riskAssessment.getRiskLevel(), 
                riskAssessment.getRiskReasonCodes());
        
        changeRequestRepository.save(changeRequest);
        log.info("Change request submitted: id={}, status=PENDING, riskScore={}", 
                changeRequestId, riskAssessment.getRiskScore());
        
        // Write audit log for SUBMIT_CHANGE_REQUEST
        writeAuditLog(userId, "EV_USER", "SUBMIT_CHANGE_REQUEST", "CHANGE_REQUEST", changeRequestId,
                Map.of(
                        "type", changeRequest.getType().name(),
                        "stationVersionId", changeRequest.getProposedStationVersionId().toString(),
                        "stationName", stationVersion.getName(),
                        "riskScore", riskAssessment.getRiskScore(),
                        "riskLevel", riskAssessment.getRiskLevel(),
                        "riskReasons", riskAssessment.getRiskReasonCodes()
                ));
        
        // Load services and ports for response
        List<StationServiceEntity> services = stationServiceRepository
                .findByStationVersionId(stationVersion.getId());
        List<UUID> serviceIds = services.stream().map(StationServiceEntity::getId).toList();
        List<ChargingPortEntity> ports = serviceIds.isEmpty() ? List.of() : 
                chargingPortRepository.findByStationServiceIds(serviceIds);
        
        return buildResponse(changeRequest, stationVersion, services, ports);
    }

    /**
     * Get all change requests for the current user
     */
    @Transactional(readOnly = true)
    public List<ChangeRequestResponseDTO> getMyChangeRequests(UUID userId) {
        log.info("Getting change requests for user: {}", userId);
        
        List<ChangeRequestEntity> changeRequests = changeRequestRepository
                .findBySubmittedByOrderByCreatedAtDesc(userId);
        
        return changeRequests.stream()
                .map(this::loadAndBuildResponse)
                .collect(Collectors.toList());
    }

    /**
     * Get a specific change request by ID
     */
    @Transactional(readOnly = true)
    public Optional<ChangeRequestResponseDTO> getChangeRequest(UUID changeRequestId, UUID userId) {
        log.info("Getting change request: id={}, userId={}", changeRequestId, userId);
        
        return changeRequestRepository.findById(changeRequestId)
                .filter(cr -> cr.getSubmittedBy().equals(userId))
                .map(this::loadAndBuildResponse);
    }


    // ========== Private Helper Methods ==========
    
    private void validateChangeRequest(CreateChangeRequestDTO request) {
        // Validate stationId based on type
        if (request.getType() == ChangeRequestType.UPDATE_STATION && request.getStationId() == null) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "stationId is required for UPDATE_STATION");
        }
        if (request.getType() == ChangeRequestType.CREATE_STATION && request.getStationId() != null) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "stationId must be null for CREATE_STATION");
        }
        
        // Validate services
        var data = request.getStationData();
        for (var service : data.getServices()) {
            if (service.getType() == ServiceType.CHARGING) {
                if (service.getChargingPorts() == null || service.getChargingPorts().isEmpty()) {
                    throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                            "At least one charging port is required for CHARGING service");
                }
                
                // Validate DC ports have powerKw
                for (var port : service.getChargingPorts()) {
                    if (port.getPowerType() == PowerType.DC && 
                            (port.getPowerKw() == null || port.getPowerKw().doubleValue() <= 0)) {
                        throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                                "DC charging ports must have powerKw > 0");
                    }
                }
            }
        }
    }
    
    private Point createPoint(double lng, double lat) {
        Coordinate coordinate = new Coordinate(lng, lat);
        return GEOMETRY_FACTORY.createPoint(coordinate);
    }
    
    private ChangeRequestResponseDTO loadAndBuildResponse(ChangeRequestEntity changeRequest) {
        StationVersionEntity stationVersion = stationVersionRepository
                .findById(changeRequest.getProposedStationVersionId())
                .orElse(null);
        
        if (stationVersion == null) {
            // Return basic response without station data
            return ChangeRequestResponseDTO.builder()
                    .id(changeRequest.getId())
                    .type(changeRequest.getType())
                    .status(changeRequest.getStatus())
                    .stationId(changeRequest.getStationId())
                    .proposedStationVersionId(changeRequest.getProposedStationVersionId())
                    .submittedBy(changeRequest.getSubmittedBy())
                    .riskScore(changeRequest.getRiskScore())
                    .riskReasons(changeRequest.getRiskReasons())
                    .adminNote(changeRequest.getAdminNote())
                    .createdAt(changeRequest.getCreatedAt())
                    .submittedAt(changeRequest.getSubmittedAt())
                    .decidedAt(changeRequest.getDecidedAt())
                    .build();
        }
        
        List<StationServiceEntity> services = stationServiceRepository
                .findByStationVersionId(stationVersion.getId());
        List<UUID> serviceIds = services.stream().map(StationServiceEntity::getId).toList();
        List<ChargingPortEntity> ports = serviceIds.isEmpty() ? List.of() : 
                chargingPortRepository.findByStationServiceIds(serviceIds);
        
        return buildResponse(changeRequest, stationVersion, services, ports);
    }
    
    private ChangeRequestResponseDTO buildResponse(
            ChangeRequestEntity changeRequest,
            StationVersionEntity stationVersion,
            List<StationServiceEntity> services,
            List<ChargingPortEntity> ports) {
        
        // Group ports by service ID
        Map<UUID, List<ChargingPortEntity>> portsByService = ports.stream()
                .collect(Collectors.groupingBy(ChargingPortEntity::getStationServiceId));
        
        // Build service DTOs
        List<ChangeRequestResponseDTO.ServiceDTO> serviceDTOs = services.stream()
                .map(service -> {
                    List<ChangeRequestResponseDTO.ChargingPortDTO> portDTOs = 
                            portsByService.getOrDefault(service.getId(), List.of()).stream()
                                    .map(port -> ChangeRequestResponseDTO.ChargingPortDTO.builder()
                                            .powerType(port.getPowerType())
                                            .powerKw(port.getPowerKw())
                                            .count(port.getPortCount())
                                            .build())
                                    .collect(Collectors.toList());
                    
                    return ChangeRequestResponseDTO.ServiceDTO.builder()
                            .type(service.getServiceType())
                            .chargingPorts(portDTOs)
                            .build();
                })
                .collect(Collectors.toList());
        
        // Build station data
        ChangeRequestResponseDTO.StationDataDTO stationData = ChangeRequestResponseDTO.StationDataDTO.builder()
                .name(stationVersion.getName())
                .address(stationVersion.getAddress())
                .lat(stationVersion.getLocation().getY())
                .lng(stationVersion.getLocation().getX())
                .operatingHours(stationVersion.getOperatingHours())
                .parking(stationVersion.getParking())
                .visibility(stationVersion.getVisibility())
                .publicStatus(stationVersion.getPublicStatus())
                .services(serviceDTOs)
                .build();
        
        return ChangeRequestResponseDTO.builder()
                .id(changeRequest.getId())
                .type(changeRequest.getType())
                .status(changeRequest.getStatus())
                .stationId(changeRequest.getStationId())
                .proposedStationVersionId(changeRequest.getProposedStationVersionId())
                .submittedBy(changeRequest.getSubmittedBy())
                .riskScore(changeRequest.getRiskScore())
                .riskReasons(changeRequest.getRiskReasons())
                .adminNote(changeRequest.getAdminNote())
                .createdAt(changeRequest.getCreatedAt())
                .submittedAt(changeRequest.getSubmittedAt())
                .decidedAt(changeRequest.getDecidedAt())
                .stationData(stationData)
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

