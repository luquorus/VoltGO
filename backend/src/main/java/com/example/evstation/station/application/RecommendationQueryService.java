package com.example.evstation.station.application;

import com.example.evstation.api.ev_user_mobile.dto.ChargingSummaryDTO;
import com.example.evstation.api.ev_user_mobile.dto.PortInfoDTO;
import com.example.evstation.api.ev_user_mobile.dto.RecommendationRequestDTO;
import com.example.evstation.api.ev_user_mobile.dto.RecommendationResponseDTO;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.trust.infrastructure.jpa.StationTrustJpaRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RecommendationQueryService {
    
    @PersistenceContext
    private final EntityManager entityManager;
    
    private final StationTrustJpaRepository trustRepository;
    
    @Value("${app.recommendation.default-average-speed-kmph:30.0}")
    private double defaultAverageSpeedKmph;
    
    @Value("${app.recommendation.default-consumption-kwh-per-km:0.18}")
    private double defaultConsumptionKwhPerKm;
    
    @Value("${app.recommendation.default-vehicle-max-charge-kw:120.0}")
    private double defaultVehicleMaxChargeKw;
    
    @Value("${app.recommendation.default-target-percent:80}")
    private int defaultTargetPercent;
    
    @Value("${app.recommendation.default-limit:10}")
    private int defaultLimit;
    
    public RecommendationResponseDTO getRecommendations(RecommendationRequestDTO request) {
        // Normalize inputs
        int targetPercent = request.getTargetPercent() != null ? request.getTargetPercent() : defaultTargetPercent;
        double averageSpeedKmph = request.getAverageSpeedKmph() != null ? request.getAverageSpeedKmph() : defaultAverageSpeedKmph;
        double consumptionKwhPerKm = request.getConsumptionKwhPerKm() != null ? request.getConsumptionKwhPerKm() : defaultConsumptionKwhPerKm;
        double vehicleMaxChargeKw = request.getVehicleMaxChargeKw() != null ? request.getVehicleMaxChargeKw() : defaultVehicleMaxChargeKw;
        int limit = request.getLimit() != null ? request.getLimit() : defaultLimit;
        
        // Validate targetPercent > batteryPercent
        if (targetPercent < request.getBatteryPercent()) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "targetPercent must be >= batteryPercent");
        }
        
        // Calculate needed energy
        double currentEnergy = request.getBatteryCapacityKwh() * request.getBatteryPercent() / 100.0;
        double targetEnergy = request.getBatteryCapacityKwh() * targetPercent / 100.0;
        double neededKwh = Math.max(0, targetEnergy - currentEnergy);
        
        // Get candidate stations with ports and distance
        List<StationWithPortsAndDistance> candidates = findStationsWithPortsAndDistance(
                request.getCurrentLocation().getLat(),
                request.getCurrentLocation().getLng(),
                request.getRadiusKm()
        );
        
        // Evaluate each station
        List<RecommendationResponseDTO.RecommendationResultDTO> results = new ArrayList<>();
        
        for (StationWithPortsAndDistance candidate : candidates) {
            RecommendationResponseDTO.RecommendationResultDTO result = evaluateStation(
                    candidate,
                    neededKwh,
                    request.getBatteryCapacityKwh(),
                    request.getBatteryPercent(),
                    targetPercent,
                    vehicleMaxChargeKw,
                    averageSpeedKmph
            );
            
            if (result != null) {
                results.add(result);
            }
        }
        
        // Sort by totalMinutes, then travelMinutes, then chargeMinutes, then trustScore desc
        results.sort((a, b) -> {
            int totalCompare = Integer.compare(a.getEstimate().getTotalMinutes(), b.getEstimate().getTotalMinutes());
            if (totalCompare != 0) return totalCompare;
            
            int travelCompare = Integer.compare(a.getEstimate().getTravelMinutes(), b.getEstimate().getTravelMinutes());
            if (travelCompare != 0) return travelCompare;
            
            int chargeCompare = Integer.compare(a.getEstimate().getChargeMinutes(), b.getEstimate().getChargeMinutes());
            if (chargeCompare != 0) return chargeCompare;
            
            return Integer.compare(b.getTrustScore(), a.getTrustScore()); // desc
        });
        
        // Take top N
        results = results.stream().limit(limit).collect(Collectors.toList());
        
        // Build response
        RecommendationResponseDTO.RecommendationInputDTO input = RecommendationResponseDTO.RecommendationInputDTO.builder()
                .currentLocation(RecommendationResponseDTO.RecommendationInputDTO.LocationDTO.builder()
                        .lat(request.getCurrentLocation().getLat())
                        .lng(request.getCurrentLocation().getLng())
                        .build())
                .radiusKm(request.getRadiusKm())
                .batteryPercent(request.getBatteryPercent())
                .batteryCapacityKwh(request.getBatteryCapacityKwh())
                .targetPercent(targetPercent)
                .consumptionKwhPerKm(consumptionKwhPerKm)
                .averageSpeedKmph(averageSpeedKmph)
                .vehicleMaxChargeKw(vehicleMaxChargeKw)
                .limit(limit)
                .build();
        
        return RecommendationResponseDTO.builder()
                .input(input)
                .results(results)
                .build();
    }
    
    private List<StationWithPortsAndDistance> findStationsWithPortsAndDistance(double lat, double lng, double radiusKm) {
        double radiusMeters = radiusKm * 1000;
        
        // Query stations with distance and ports
        String query = """
            SELECT 
                sv.station_id,
                sv.name,
                sv.address,
                ST_Y(CAST(sv.location AS geometry)) as lat,
                ST_X(CAST(sv.location AS geometry)) as lng,
                CAST(ST_Distance(
                    CAST(sv.location AS geography),
                    CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography)
                ) AS DOUBLE PRECISION) / 1000.0 as distance_km,
                cp.power_type,
                cp.power_kw,
                cp.port_count
            FROM station_version sv
            JOIN station_service ss ON sv.id = ss.station_version_id
            JOIN charging_port cp ON ss.id = cp.station_service_id
            WHERE sv.workflow_status = 'PUBLISHED'
            AND ST_DWithin(
                CAST(sv.location AS geography),
                CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
                :radiusMeters
            )
            ORDER BY sv.station_id, cp.power_type, cp.power_kw DESC NULLS LAST
            """;
        
        Query nativeQuery = entityManager.createNativeQuery(query);
        nativeQuery.setParameter("lat", lat);
        nativeQuery.setParameter("lng", lng);
        nativeQuery.setParameter("radiusMeters", radiusMeters);
        
        @SuppressWarnings("unchecked")
        List<Object[]> rows = nativeQuery.getResultList();
        
        // Group by station
        Map<UUID, StationWithPortsAndDistance> stationMap = new LinkedHashMap<>();
        
        for (Object[] row : rows) {
            UUID stationId = (UUID) row[0];
            String name = (String) row[1];
            String address = (String) row[2];
            Double stationLat = ((Number) row[3]).doubleValue();
            Double stationLng = ((Number) row[4]).doubleValue();
            Double distanceKm = ((Number) row[5]).doubleValue();
            String powerType = (String) row[6];
            BigDecimal powerKw = row[7] != null ? (BigDecimal) row[7] : null;
            Integer portCount = ((Number) row[8]).intValue();
            
            StationWithPortsAndDistance station = stationMap.computeIfAbsent(stationId, id -> {
                Integer trustScore = trustRepository.findById(id)
                        .map(trust -> trust.getScore())
                        .orElse(50);
                
                return new StationWithPortsAndDistance(
                        id, name, address, stationLat, stationLng, distanceKm, trustScore, new ArrayList<>()
                );
            });
            
            station.ports.add(PortInfoDTO.builder()
                    .powerType(powerType)
                    .powerKw(powerKw)
                    .count(portCount)
                    .build());
        }
        
        return new ArrayList<>(stationMap.values());
    }
    
    private RecommendationResponseDTO.RecommendationResultDTO evaluateStation(
            StationWithPortsAndDistance candidate,
            double neededKwh,
            double batteryCapacityKwh,
            int batteryPercent,
            int targetPercent,
            double vehicleMaxChargeKw,
            double averageSpeedKmph) {
        
        if (candidate.ports.isEmpty()) {
            return null; // Skip stations without ports
        }
        
        // Evaluate each port option and pick the best one
        RecommendationResponseDTO.RecommendationResultDTO bestResult = null;
        int bestTotalMinutes = Integer.MAX_VALUE;
        
        // Prefer DC ports first
        List<PortInfoDTO> dcPorts = candidate.ports.stream()
                .filter(p -> "DC".equals(p.getPowerType()) && p.getPowerKw() != null)
                .sorted((a, b) -> b.getPowerKw().compareTo(a.getPowerKw())) // Desc by power
                .collect(Collectors.toList());
        
        List<PortInfoDTO> acPorts = candidate.ports.stream()
                .filter(p -> "AC".equals(p.getPowerType()))
                .collect(Collectors.toList());
        
        List<PortInfoDTO> portsToEvaluate = new ArrayList<>(dcPorts);
        portsToEvaluate.addAll(acPorts);
        
        for (PortInfoDTO port : portsToEvaluate) {
            EvaluationResult eval = evaluatePort(
                    port,
                    neededKwh,
                    batteryCapacityKwh,
                    batteryPercent,
                    targetPercent,
                    vehicleMaxChargeKw,
                    candidate.distanceKm,
                    averageSpeedKmph
            );
            
            if (eval.totalMinutes < bestTotalMinutes) {
                bestTotalMinutes = eval.totalMinutes;
                bestResult = buildResult(candidate, port, eval, batteryCapacityKwh, batteryPercent, targetPercent, vehicleMaxChargeKw);
            }
        }
        
        return bestResult;
    }
    
    private EvaluationResult evaluatePort(
            PortInfoDTO port,
            double neededKwh,
            double batteryCapacityKwh,
            int batteryPercent,
            int targetPercent,
            double vehicleMaxChargeKw,
            double distanceKm,
            double averageSpeedKmph) {
        
        // Calculate travel time
        int travelMinutes = (int) Math.ceil((distanceKm / averageSpeedKmph) * 60);
        
        // Calculate charge time
        int chargeMinutes = 0;
        
        if (neededKwh > 0) {
            double effectiveKw;
            if (port.getPowerKw() != null) {
                // DC port
                effectiveKw = Math.min(port.getPowerKw().doubleValue(), vehicleMaxChargeKw);
            } else {
                // AC port - assume 7kW typical
                effectiveKw = Math.min(7.0, vehicleMaxChargeKw);
            }
            
            double hours;
            if (targetPercent <= 80) {
                // Constant power
                hours = neededKwh / effectiveKw;
            } else {
                // Split: up to 80% at full power, above 80% at 50% power
                double upTo80Kwh = Math.max(0, batteryCapacityKwh * 0.8 - (batteryCapacityKwh * batteryPercent / 100.0));
                double above80Kwh = neededKwh - upTo80Kwh;
                hours = (upTo80Kwh / effectiveKw) + (above80Kwh / (effectiveKw * 0.5));
            }
            
            chargeMinutes = (int) Math.ceil(hours * 60);
        }
        
        int totalMinutes = travelMinutes + chargeMinutes;
        
        return new EvaluationResult(travelMinutes, chargeMinutes, totalMinutes);
    }
    
    private RecommendationResponseDTO.RecommendationResultDTO buildResult(
            StationWithPortsAndDistance candidate,
            PortInfoDTO chosenPort,
            EvaluationResult eval,
            double batteryCapacityKwh,
            int batteryPercent,
            int targetPercent,
            double vehicleMaxChargeKw) {
        
        // Calculate neededKwh for explanation
        double currentEnergy = batteryCapacityKwh * batteryPercent / 100.0;
        double targetEnergy = batteryCapacityKwh * targetPercent / 100.0;
        double neededKwh = Math.max(0, targetEnergy - currentEnergy);
        
        // Calculate effective kw
        double effectiveKw;
        if (chosenPort.getPowerKw() != null) {
            effectiveKw = Math.min(chosenPort.getPowerKw().doubleValue(), vehicleMaxChargeKw);
        } else {
            effectiveKw = Math.min(7.0, vehicleMaxChargeKw);
        }
        
        // Build explanation
        List<String> explain = new ArrayList<>();
        explain.add(String.format("Total = travel(%dm) + charge(%dm)", eval.travelMinutes, eval.chargeMinutes));
        
        if (chosenPort.getPowerKw() != null) {
            explain.add(String.format("Chọn DC %.0fkW vì vehicleMaxChargeKw=%.0fkW => effective %.0fkW",
                    chosenPort.getPowerKw().doubleValue(), vehicleMaxChargeKw, effectiveKw));
        } else {
            explain.add(String.format("Chọn AC (fallback) vì không có DC, effective %.0fkW", effectiveKw));
        }
        
        if (targetPercent <= 80) {
            explain.add("Sạc đến " + targetPercent + "% nên không áp dụng taper");
        } else {
            explain.add("Sạc đến " + targetPercent + "% nên áp dụng taper (50% power) từ 80% trở lên");
        }
        
        // Build charging summary
        ChargingSummaryDTO chargingSummary = buildChargingSummary(candidate.ports);
        
        return RecommendationResponseDTO.RecommendationResultDTO.builder()
                .stationId(candidate.stationId.toString())
                .name(candidate.name)
                .address(candidate.address)
                .lat(candidate.lat)
                .lng(candidate.lng)
                .trustScore(candidate.trustScore)
                .chosenPort(RecommendationResponseDTO.RecommendationResultDTO.ChosenPortDTO.builder()
                        .powerType(chosenPort.getPowerType())
                        .powerKw(chosenPort.getPowerKw())
                        .assumedEffectiveKw(effectiveKw)
                        .build())
                .estimate(RecommendationResponseDTO.RecommendationResultDTO.EstimateDTO.builder()
                        .distanceKm(round(candidate.distanceKm, 1))
                        .travelMinutes(eval.travelMinutes)
                        .neededKwh(round(neededKwh, 1))
                        .chargeMinutes(eval.chargeMinutes)
                        .totalMinutes(eval.totalMinutes)
                        .build())
                .explain(explain)
                .chargingSummary(chargingSummary)
                .build();
    }
    
    private ChargingSummaryDTO buildChargingSummary(List<PortInfoDTO> ports) {
        int totalPorts = ports.stream().mapToInt(PortInfoDTO::getCount).sum();
        BigDecimal maxPowerKw = ports.stream()
                .filter(p -> "DC".equals(p.getPowerType()) && p.getPowerKw() != null)
                .map(PortInfoDTO::getPowerKw)
                .max(BigDecimal::compareTo)
                .orElse(null);
        
        return ChargingSummaryDTO.builder()
                .totalPorts(totalPorts)
                .maxPowerKw(maxPowerKw)
                .ports(ports)
                .build();
    }
    
    private double round(double value, int places) {
        if (places < 0) throw new IllegalArgumentException();
        BigDecimal bd = BigDecimal.valueOf(value);
        bd = bd.setScale(places, RoundingMode.HALF_UP);
        return bd.doubleValue();
    }
    
    // Helper data class
    private static class StationWithPortsAndDistance {
        final UUID stationId;
        final String name;
        final String address;
        final Double lat;
        final Double lng;
        final Double distanceKm;
        final Integer trustScore;
        final List<PortInfoDTO> ports;
        
        StationWithPortsAndDistance(UUID stationId, String name, String address, Double lat, Double lng,
                                    Double distanceKm, Integer trustScore, List<PortInfoDTO> ports) {
            this.stationId = stationId;
            this.name = name;
            this.address = address;
            this.lat = lat;
            this.lng = lng;
            this.distanceKm = distanceKm;
            this.trustScore = trustScore;
            this.ports = ports;
        }
    }
    
    private static class EvaluationResult {
        final int travelMinutes;
        final int chargeMinutes;
        final int totalMinutes;
        
        EvaluationResult(int travelMinutes, int chargeMinutes, int totalMinutes) {
            this.travelMinutes = travelMinutes;
            this.chargeMinutes = chargeMinutes;
            this.totalMinutes = totalMinutes;
        }
    }
}

