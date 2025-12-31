package com.example.evstation.risk.application;

import com.example.evstation.risk.domain.RiskAssessment;
import com.example.evstation.risk.domain.RiskReasonCode;
import com.example.evstation.station.domain.ChangeRequestType;
import com.example.evstation.station.infrastructure.jpa.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Risk Engine Service that evaluates the risk of a change request.
 * Uses rule-based logic to compute a risk score and list of reasons.
 * 
 * Rules:
 * 1. GPS_CHANGED_100M: +50 if distance > 100m (UPDATE only)
 * 2. PRICE_CHANGED: +20 if price_info different
 * 3. PORTS_CHANGED: +30 if charging ports config changed
 * 4. HOURS_CHANGED: +10 if operating_hours changed
 * 5. ACCESS_CHANGED: +10 if visibility or public_status changed
 * 6. NEW_STATION: +10 for CREATE_STATION requests
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RiskEngineService {
    
    private static final double GPS_CHANGE_THRESHOLD_METERS = 100.0;
    
    private final StationVersionJpaRepository stationVersionRepository;
    private final StationServiceJpaRepository stationServiceRepository;
    private final ChargingPortJpaRepository chargingPortRepository;

    /**
     * Assess the risk of a change request.
     * 
     * @param changeRequest The change request entity
     * @return RiskAssessment containing score and reasons
     */
    @Transactional(readOnly = true)
    public RiskAssessment assessChangeRequest(ChangeRequestEntity changeRequest) {
        log.info("Assessing risk for change request: id={}, type={}", 
                changeRequest.getId(), changeRequest.getType());
        
        List<RiskReasonCode> reasons = new ArrayList<>();
        
        // Load proposed station version
        StationVersionEntity proposedVersion = stationVersionRepository
                .findById(changeRequest.getProposedStationVersionId())
                .orElseThrow(() -> new IllegalStateException("Proposed station version not found"));
        
        // Load proposed charging ports
        List<ChargingPortEntity> proposedPorts = loadChargingPorts(proposedVersion.getId());
        
        if (changeRequest.getType() == ChangeRequestType.CREATE_STATION) {
            // For CREATE_STATION, add baseline risk
            reasons.add(RiskReasonCode.NEW_STATION);
            log.debug("CREATE_STATION: added NEW_STATION reason");
        } else {
            // For UPDATE_STATION, compare with published version
            Optional<StationVersionEntity> publishedVersionOpt = 
                    stationVersionRepository.findPublishedByStationId(changeRequest.getStationId());
            
            if (publishedVersionOpt.isPresent()) {
                StationVersionEntity publishedVersion = publishedVersionOpt.get();
                List<ChargingPortEntity> publishedPorts = loadChargingPorts(publishedVersion.getId());
                
                // Apply rules
                reasons.addAll(compareVersions(publishedVersion, proposedVersion, 
                        publishedPorts, proposedPorts));
            } else {
                // No published version found for UPDATE - treat as CREATE
                log.warn("UPDATE_STATION but no published version found for station: {}", 
                        changeRequest.getStationId());
                reasons.add(RiskReasonCode.NEW_STATION);
            }
        }
        
        RiskAssessment assessment = RiskAssessment.fromReasons(reasons);
        log.info("Risk assessment complete: id={}, score={}, level={}, reasons={}", 
                changeRequest.getId(), assessment.getRiskScore(), 
                assessment.getRiskLevel(), assessment.getRiskReasonCodes());
        
        return assessment;
    }

    /**
     * Compare published and proposed versions to detect changes.
     */
    private List<RiskReasonCode> compareVersions(
            StationVersionEntity published,
            StationVersionEntity proposed,
            List<ChargingPortEntity> publishedPorts,
            List<ChargingPortEntity> proposedPorts) {
        
        List<RiskReasonCode> reasons = new ArrayList<>();
        
        // Rule 1: GPS_CHANGED_100M
        if (isGpsChanged(published.getLocation(), proposed.getLocation())) {
            reasons.add(RiskReasonCode.GPS_CHANGED_100M);
            log.debug("GPS changed by more than {}m", GPS_CHANGE_THRESHOLD_METERS);
        }
        
        // Rule 2: PRICE_CHANGED (if price_info field exists - check for null)
        // Note: price_info may not be in current schema, skip for now
        // if (isPriceChanged(published.getPriceInfo(), proposed.getPriceInfo())) {
        //     reasons.add(RiskReasonCode.PRICE_CHANGED);
        // }
        
        // Rule 3: PORTS_CHANGED
        if (arePortsChanged(publishedPorts, proposedPorts)) {
            reasons.add(RiskReasonCode.PORTS_CHANGED);
            log.debug("Charging ports configuration changed");
        }
        
        // Rule 4: HOURS_CHANGED
        if (isHoursChanged(published.getOperatingHours(), proposed.getOperatingHours())) {
            reasons.add(RiskReasonCode.HOURS_CHANGED);
            log.debug("Operating hours changed");
        }
        
        // Rule 5: ACCESS_CHANGED (visibility or public_status)
        if (isAccessChanged(published, proposed)) {
            reasons.add(RiskReasonCode.ACCESS_CHANGED);
            log.debug("Access settings changed (visibility or status)");
        }
        
        return reasons;
    }

    /**
     * Check if GPS location changed by more than threshold (100m).
     */
    private boolean isGpsChanged(Point published, Point proposed) {
        if (published == null || proposed == null) {
            return published != proposed; // One is null, other is not
        }
        
        // Calculate distance in meters using Haversine formula
        double distance = calculateDistanceInMeters(
                published.getY(), published.getX(),  // lat, lng
                proposed.getY(), proposed.getX()
        );
        
        log.debug("GPS distance: {}m (threshold: {}m)", distance, GPS_CHANGE_THRESHOLD_METERS);
        return distance > GPS_CHANGE_THRESHOLD_METERS;
    }

    /**
     * Calculate distance between two points using Haversine formula.
     * Returns distance in meters.
     */
    private double calculateDistanceInMeters(double lat1, double lng1, double lat2, double lng2) {
        final double R = 6371000; // Earth's radius in meters
        
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        
        return R * c;
    }

    /**
     * Check if charging ports configuration changed.
     * Compares as multiset of (power_type, power_kw, count).
     */
    private boolean arePortsChanged(List<ChargingPortEntity> published, List<ChargingPortEntity> proposed) {
        // Create multiset representations
        Set<String> publishedSet = portsToMultiset(published);
        Set<String> proposedSet = portsToMultiset(proposed);
        
        return !publishedSet.equals(proposedSet);
    }

    /**
     * Convert ports list to a multiset representation for comparison.
     */
    private Set<String> portsToMultiset(List<ChargingPortEntity> ports) {
        return ports.stream()
                .map(p -> String.format("%s|%s|%d",
                        p.getPowerType(),
                        p.getPowerKw() != null ? p.getPowerKw().stripTrailingZeros().toPlainString() : "null",
                        p.getPortCount()))
                .collect(Collectors.toSet());
    }

    /**
     * Check if operating hours changed.
     */
    private boolean isHoursChanged(String published, String proposed) {
        String normalizedPublished = normalizeString(published);
        String normalizedProposed = normalizeString(proposed);
        return !normalizedPublished.equals(normalizedProposed);
    }

    /**
     * Check if price info changed.
     * Note: Reserved for future use when price_info field is added to schema.
     */
    @SuppressWarnings("unused")
    private boolean isPriceChanged(String published, String proposed) {
        String normalizedPublished = normalizeString(published);
        String normalizedProposed = normalizeString(proposed);
        return !normalizedPublished.equals(normalizedProposed);
    }

    /**
     * Check if access settings changed (visibility or public_status).
     */
    private boolean isAccessChanged(StationVersionEntity published, StationVersionEntity proposed) {
        boolean visibilityChanged = published.getVisibility() != proposed.getVisibility();
        boolean statusChanged = published.getPublicStatus() != proposed.getPublicStatus();
        return visibilityChanged || statusChanged;
    }

    /**
     * Normalize string for comparison (trim, lowercase, handle null).
     */
    private String normalizeString(String value) {
        if (value == null) {
            return "";
        }
        return value.trim().toLowerCase();
    }

    /**
     * Load charging ports for a station version.
     */
    private List<ChargingPortEntity> loadChargingPorts(UUID stationVersionId) {
        List<StationServiceEntity> services = stationServiceRepository.findByStationVersionId(stationVersionId);
        if (services.isEmpty()) {
            return List.of();
        }
        
        List<UUID> serviceIds = services.stream()
                .map(StationServiceEntity::getId)
                .toList();
        
        return chargingPortRepository.findByStationServiceIds(serviceIds);
    }
}

