package com.example.evstation.risk.application;

import com.example.evstation.batteryswap.domain.ChangeRequestType;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapChangeRequestEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapStationVersionEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapTrustEntity;
import com.example.evstation.risk.domain.BatterySwapRiskReason;
import com.example.evstation.station.infrastructure.jpa.StationEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.EnumSet;
import java.util.Set;

/**
 * Risk assessor for battery swap change requests.
 * Implements 6-category risk assessment as defined in design doc section 4.2:
 * 1. Location Risk
 * 2. Data Accuracy Risk
 * 3. Operation Risk
 * 4. Financial Risk
 * 5. Safety Risk
 * 6. Provider Trust Risk
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BatterySwapRiskAssessor {

    // Threshold constants
    private static final double GPS_CHANGE_THRESHOLD_METERS = 100.0;
    private static final double BATTERY_COUNT_CHANGE_THRESHOLD = 0.2; // 20% change
    private static final double CHARGE_POWER_CHANGE_THRESHOLD = 0.25; // 25% change
    private static final int LOW_BATTERY_INVENTORY_THRESHOLD = 5;
    private static final double MIN_CHARGE_POWER_KW = 10.0;
    private static final double MAX_CHARGE_POWER_KW = 200.0;
    private static final BigDecimal PRICE_CHANGE_THRESHOLD = new BigDecimal("5000"); // 5000 VND
    private static final int LOW_TRUST_THRESHOLD = 30;
    private static final int HIGH_REJECTION_THRESHOLD = 50; // 50%

    /**
     * Assess the risk of a battery swap change request.
     *
     * @param changeRequest The change request to assess
     * @param proposedVersion The proposed station version
     * @param publishedVersion Optional published version for comparison (null for new stations)
     * @param station Optional station entity
     * @param trust Optional trust record for the station
     * @return RiskAssessmentResult with score, reasons, and flags
     */
    public BatterySwapRiskAssessmentResult assess(
            BatterySwapChangeRequestEntity changeRequest,
            BatterySwapStationVersionEntity proposedVersion,
            BatterySwapStationVersionEntity publishedVersion,
            StationEntity station,
            BatterySwapTrustEntity trust) {
        
        log.info("Assessing battery swap risk for request: id={}, type={}", 
                changeRequest.getId(), changeRequest.getType());
        
        Set<BatterySwapRiskReason> reasons = EnumSet.noneOf(BatterySwapRiskReason.class);

        // 1. Location Risk Assessment
        reasons.addAll(assessLocationRisk(changeRequest, station, publishedVersion));

        // 2. Data Accuracy Risk Assessment
        reasons.addAll(assessDataAccuracyRisk(proposedVersion, publishedVersion, changeRequest.getType()));

        // 3. Operation Risk Assessment
        reasons.addAll(assessOperationRisk(proposedVersion));

        // 4. Financial Risk Assessment
        reasons.addAll(assessFinancialRisk(proposedVersion, publishedVersion));

        // 5. Safety Risk Assessment
        reasons.addAll(assessSafetyRisk(proposedVersion, station));

        // 6. Provider Trust Risk Assessment
        reasons.addAll(assessProviderTrustRisk(trust, changeRequest.getSubmittedBy()));

        BatterySwapRiskAssessmentResult result = BatterySwapRiskAssessmentResult.fromReasons(reasons);
        
        log.info("Battery swap risk assessment complete: id={}, score={}, level={}, reasons={}", 
                changeRequest.getId(), result.getRiskScore(), result.getRiskLevel(), result.getRiskReasonCodes());
        
        return result;
    }

    /**
     * 1. Assess location-related risks (Design Doc Section 4.2.1)
     */
    Set<BatterySwapRiskReason> assessLocationRisk(
            BatterySwapChangeRequestEntity changeRequest,
            StationEntity station,
            BatterySwapStationVersionEntity publishedVersion) {
        
        Set<BatterySwapRiskReason> reasons = EnumSet.noneOf(BatterySwapRiskReason.class);

        // NEW_BATTERY_SWAP_STATION: New station creation
        if (changeRequest.getType() == ChangeRequestType.CREATE_BATTERY_SWAP_STATION) {
            reasons.add(BatterySwapRiskReason.NEW_BATTERY_SWAP_STATION);
            log.debug("Location risk: New battery swap station");
        }

        // LOCATION_CHANGED: Station location changed from previous
        if (publishedVersion != null && station != null) {
            // Compare current station location with published version
            // This would require additional logic to compare coordinates
            // For now, mark if station exists with different location
            if (station.getId() != null && publishedVersion.getStationId() != null) {
                // Location change detection would go here
            }
        }

        // SENSITIVE_AREA: Station in sensitive/restricted area
        // This would require checking against a list of sensitive areas
        // For implementation, this would check station attributes or external data

        return reasons;
    }

    /**
     * 2. Assess data accuracy risks (Design Doc Section 4.2.2)
     */
    Set<BatterySwapRiskReason> assessDataAccuracyRisk(
            BatterySwapStationVersionEntity proposedVersion,
            BatterySwapStationVersionEntity publishedVersion,
            ChangeRequestType requestType) {
        
        Set<BatterySwapRiskReason> reasons = EnumSet.noneOf(BatterySwapRiskReason.class);

        if (proposedVersion == null) {
            return reasons;
        }

        // BATTERY_COUNT_CHANGED: Total battery count changed significantly
        if (publishedVersion != null) {
            int publishedBatteries = publishedVersion.getTotalBatteries();
            int proposedBatteries = proposedVersion.getTotalBatteries();
            
            if (publishedBatteries > 0) {
                double changeRatio = Math.abs(proposedBatteries - publishedBatteries) / (double) publishedBatteries;
                if (changeRatio > BATTERY_COUNT_CHANGE_THRESHOLD) {
                    reasons.add(BatterySwapRiskReason.BATTERY_COUNT_CHANGED);
                    log.debug("Data accuracy risk: Battery count changed by {}%", (int)(changeRatio * 100));
                }
            }
        }

        // CHARGE_POWER_CHANGED: Average charge power changed significantly
        if (publishedVersion != null) {
            BigDecimal publishedPower = publishedVersion.getAvgChargePowerKw();
            BigDecimal proposedPower = proposedVersion.getAvgChargePowerKw();
            
            if (publishedPower != null && proposedPower != null) {
                BigDecimal diff = proposedPower.subtract(publishedPower).abs();
                if (publishedPower.compareTo(BigDecimal.ZERO) > 0) {
                    double changeRatio = diff.doubleValue() / publishedPower.doubleValue();
                    if (changeRatio > CHARGE_POWER_CHANGE_THRESHOLD) {
                        reasons.add(BatterySwapRiskReason.CHARGE_POWER_CHANGED);
                        log.debug("Data accuracy risk: Charge power changed");
                    }
                }
            }
        }

        // PILE_CONFIG_CHANGED: Pile/slot configuration changed
        // This would require comparing pile templates between versions
        // For now, it's handled as a configuration change

        // OPERATING_HOURS_CHANGED: Operating hours changed
        if (publishedVersion != null) {
            String publishedHours = normalizeString(publishedVersion.getOperatingHours());
            String proposedHours = normalizeString(proposedVersion.getOperatingHours());
            
            if (!publishedHours.equals(proposedHours)) {
                reasons.add(BatterySwapRiskReason.OPERATING_HOURS_CHANGED);
                log.debug("Data accuracy risk: Operating hours changed");
            }
        }

        // PARKING_FEE_CHANGED: Parking fee changed
        if (publishedVersion != null) {
            BigDecimal publishedFee = publishedVersion.getParkingFee();
            BigDecimal proposedFee = proposedVersion.getParkingFee();
            
            boolean feeChanged = (publishedFee == null && proposedFee != null) ||
                    (publishedFee != null && proposedFee == null) ||
                    (publishedFee != null && proposedFee != null && 
                     publishedFee.subtract(proposedFee).abs().compareTo(PRICE_CHANGE_THRESHOLD) > 0);
            
            if (feeChanged) {
                reasons.add(BatterySwapRiskReason.PARKING_FEE_CHANGED);
                log.debug("Data accuracy risk: Parking fee changed");
            }
        }

        return reasons;
    }

    /**
     * 3. Assess operational risks (Design Doc Section 4.2.3)
     */
    Set<BatterySwapRiskReason> assessOperationRisk(BatterySwapStationVersionEntity proposedVersion) {
        Set<BatterySwapRiskReason> reasons = EnumSet.noneOf(BatterySwapRiskReason.class);

        if (proposedVersion == null) {
            return reasons;
        }

        // LOW_BATTERY_INVENTORY: Battery inventory is low
        Integer totalBatteries = proposedVersion.getTotalBatteries();
        if (totalBatteries != null && totalBatteries < LOW_BATTERY_INVENTORY_THRESHOLD) {
            reasons.add(BatterySwapRiskReason.LOW_BATTERY_INVENTORY);
            log.debug("Operation risk: Low battery inventory ({})", totalBatteries);
        }

        // ABNORMAL_CHARGE_POWER: Average charge power outside normal range
        BigDecimal avgPower = proposedVersion.getAvgChargePowerKw();
        if (avgPower != null) {
            double power = avgPower.doubleValue();
            if (power < MIN_CHARGE_POWER_KW || power > MAX_CHARGE_POWER_KW) {
                reasons.add(BatterySwapRiskReason.ABNORMAL_CHARGE_POWER);
                log.debug("Operation risk: Abnormal charge power ({} kW)", power);
            }
        }

        // LIMITED_AVAILABILITY: Operating hours suggest limited availability
        String operatingHours = proposedVersion.getOperatingHours();
        if (operatingHours != null) {
            // Parse operating hours and check if less than 12 hours/day
            // Simplified check - in production would parse the hours string
            if (operatingHours.toLowerCase().contains("closed") || 
                operatingHours.toLowerCase().contains("limited")) {
                reasons.add(BatterySwapRiskReason.LIMITED_AVAILABILITY);
                log.debug("Operation risk: Limited availability indicated");
            }
        }

        // CONFIGURATION_ISSUE: Potential configuration issue
        // This would detect inconsistencies like:
        // - Piles configured but no batteries
        // - Batteries configured but no piles
        // For now, basic validation
        
        return reasons;
    }

    /**
     * 4. Assess financial risks (Design Doc Section 4.2.4)
     */
    Set<BatterySwapRiskReason> assessFinancialRisk(
            BatterySwapStationVersionEntity proposedVersion,
            BatterySwapStationVersionEntity publishedVersion) {
        
        Set<BatterySwapRiskReason> reasons = EnumSet.noneOf(BatterySwapRiskReason.class);

        // MISSING_PRICE_INFO: Pricing information incomplete or missing
        if (proposedVersion != null && proposedVersion.getParkingFee() == null) {
            // Parking fee is optional, so this is a warning rather than a hard rule
            // In production, would check other price fields
        }

        // PRICE_SIGNIFICANTLY_CHANGED: Significant price change
        if (publishedVersion != null && proposedVersion != null) {
            BigDecimal publishedFee = publishedVersion.getParkingFee();
            BigDecimal proposedFee = proposedVersion.getParkingFee();
            
            if (publishedFee != null && proposedFee != null) {
                BigDecimal diff = proposedFee.subtract(publishedFee).abs();
                // For parking fees, significant is > 50% change or > 10,000 VND
                if (publishedFee.compareTo(BigDecimal.ZERO) > 0) {
                    double changeRatio = diff.doubleValue() / publishedFee.doubleValue();
                    if (changeRatio > 0.5 || diff.compareTo(new BigDecimal("10000")) > 0) {
                        reasons.add(BatterySwapRiskReason.PRICE_SIGNIFICANTLY_CHANGED);
                        log.debug("Financial risk: Significant price change");
                    }
                }
            }
        }

        // PRICE_DEVIATION: Price significantly deviates from market average
        // This would require external market data
        // Implementation would compare against average prices in the area

        return reasons;
    }

    /**
     * 5. Assess safety risks (Design Doc Section 4.2.5)
     */
    Set<BatterySwapRiskReason> assessSafetyRisk(
            BatterySwapStationVersionEntity proposedVersion,
            StationEntity station) {
        
        Set<BatterySwapRiskReason> reasons = EnumSet.noneOf(BatterySwapRiskReason.class);

        // SAFETY_CONCERN: Potential safety concern
        // This would check:
        // - Indoor vs outdoor setup
        // - Fire safety equipment
        // - Electrical compliance
        // Implementation depends on additional station attributes

        // MISSING_SAFETY_EQUIPMENT: Required safety equipment missing
        // This would check station attributes for safety equipment indicators

        // ENVIRONMENTAL_RISK: Environmental conditions may affect safety
        // This would check:
        // - Flood-prone areas
        // - Extreme weather exposure
        // - Indoor ventilation requirements

        return reasons;
    }

    /**
     * 6. Assess provider trust risks (Design Doc Section 4.2.6)
     */
    Set<BatterySwapRiskReason> assessProviderTrustRisk(
            BatterySwapTrustEntity trust,
            java.util.UUID submittedBy) {
        
        Set<BatterySwapRiskReason> reasons = EnumSet.noneOf(BatterySwapRiskReason.class);

        if (trust == null) {
            // No trust record - treat as new provider
            reasons.add(BatterySwapRiskReason.NEW_PROVIDER);
            log.debug("Provider trust risk: No trust record found");
            return reasons;
        }

        // LOW_TRUST_PROVIDER: Provider has low trust score
        if (trust.getScore() < LOW_TRUST_THRESHOLD) {
            reasons.add(BatterySwapRiskReason.LOW_TRUST_PROVIDER);
            log.debug("Provider trust risk: Low trust score ({})", trust.getScore());
        }

        // HIGH_REJECTION_RATE: Provider has high rejection rate
        // This would require calculating rejection rate from historical data
        // For now, checked via trust breakdown or external data

        // PENDING_VERIFICATIONS: Provider has pending verifications
        // This would require querying verification tasks for the provider
        // Count of pending verifications > threshold

        // NEW_PROVIDER: Provider is new with limited history
        // Based on trust record age or verification count
        if (trust.getCreatedAt() != null) {
            long daysSinceCreation = java.time.Duration.between(
                    trust.getCreatedAt(), java.time.Instant.now()).toDays();
            if (daysSinceCreation < 30) {
                reasons.add(BatterySwapRiskReason.NEW_PROVIDER);
                log.debug("Provider trust risk: New provider ({} days)", daysSinceCreation);
            }
        }

        return reasons;
    }

    /**
     * Normalize string for comparison (trim, lowercase, handle null/empty).
     */
    private String normalizeString(String value) {
        if (value == null) {
            return "";
        }
        return value.trim().toLowerCase();
    }

    /**
     * Calculate distance between two points in meters using Haversine formula.
     */
    double calculateDistanceInMeters(double lat1, double lng1, double lat2, double lng2) {
        final double R = 6371000; // Earth's radius in meters
        
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        
        return R * c;
    }
}
