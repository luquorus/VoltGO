package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.api.ev_user_mobile.dto.*;
import com.example.evstation.station.application.port.StationQueryRepository;
import com.example.evstation.station.domain.PowerType;
import com.example.evstation.trust.infrastructure.jpa.StationTrustEntity;
import com.example.evstation.trust.infrastructure.jpa.StationTrustJpaRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Repository
@RequiredArgsConstructor
public class StationQueryRepositoryImpl implements StationQueryRepository {

    @PersistenceContext
    private final EntityManager entityManager;
    
    private final StationTrustJpaRepository trustRepository;

    @Override
    public Page<StationListItemDTO> findPublishedStationsWithinRadius(
            double lat,
            double lng,
            double radiusKm,
            BigDecimal minPowerKw,
            Boolean hasAC,
            Pageable pageable) {

        // Convert radius from km to meters
        double radiusMeters = radiusKm * 1000;

        // Build base query with PostGIS ST_DWithin
        StringBuilder queryBuilder = new StringBuilder("""
            SELECT 
                sv.station_id,
                sv.name,
                sv.address,
                ST_Y(CAST(sv.location AS geometry)) as lat,
                ST_X(CAST(sv.location AS geometry)) as lng,
                sv.operating_hours,
                sv.parking,
                sv.visibility,
                sv.public_status
            FROM station_version sv
            WHERE sv.workflow_status = 'PUBLISHED'
            AND ST_DWithin(
                CAST(sv.location AS geography),
                CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
                :radiusMeters
            )
            """);

        // Add filters
        if (minPowerKw != null) {
            queryBuilder.append("""
                AND EXISTS (
                    SELECT 1 FROM station_service ss
                    JOIN charging_port cp ON ss.id = cp.station_service_id
                    WHERE ss.station_version_id = sv.id
                    AND cp.power_type = 'DC'
                    AND cp.power_kw >= :minPowerKw
                )
                """);
        }

        if (hasAC != null && hasAC) {
            queryBuilder.append("""
                AND EXISTS (
                    SELECT 1 FROM station_service ss
                    JOIN charging_port cp ON ss.id = cp.station_service_id
                    WHERE ss.station_version_id = sv.id
                    AND cp.power_type = 'AC'
                )
                """);
        }

        // Count query - build same WHERE clause
        StringBuilder countQueryBuilder = new StringBuilder("""
            SELECT COUNT(DISTINCT sv.station_id)
            FROM station_version sv
            WHERE sv.workflow_status = 'PUBLISHED'
            AND ST_DWithin(
                CAST(sv.location AS geography),
                CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
                :radiusMeters
            )
            """);
        
        if (minPowerKw != null) {
            countQueryBuilder.append("""
                AND EXISTS (
                    SELECT 1 FROM station_service ss
                    JOIN charging_port cp ON ss.id = cp.station_service_id
                    WHERE ss.station_version_id = sv.id
                    AND cp.power_type = 'DC'
                    AND cp.power_kw >= :minPowerKw
                )
                """);
        }

        if (hasAC != null && hasAC) {
            countQueryBuilder.append("""
                AND EXISTS (
                    SELECT 1 FROM station_service ss
                    JOIN charging_port cp ON ss.id = cp.station_service_id
                    WHERE ss.station_version_id = sv.id
                    AND cp.power_type = 'AC'
                )
                """);
        }
        
        Query countNativeQuery = entityManager.createNativeQuery(countQueryBuilder.toString());
        countNativeQuery.setParameter("lat", lat);
        countNativeQuery.setParameter("lng", lng);
        countNativeQuery.setParameter("radiusMeters", radiusMeters);
        if (minPowerKw != null) {
            countNativeQuery.setParameter("minPowerKw", minPowerKw);
        }
        long total = ((Number) countNativeQuery.getSingleResult()).longValue();

        // Add pagination
        queryBuilder.append(" ORDER BY ST_Distance(CAST(sv.location AS geography), CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography))");
        queryBuilder.append(" LIMIT :limit OFFSET :offset");

        Query nativeQuery = entityManager.createNativeQuery(queryBuilder.toString());
        nativeQuery.setParameter("lat", lat);
        nativeQuery.setParameter("lng", lng);
        nativeQuery.setParameter("radiusMeters", radiusMeters);
        if (minPowerKw != null) {
            nativeQuery.setParameter("minPowerKw", minPowerKw);
        }
        nativeQuery.setParameter("limit", pageable.getPageSize());
        nativeQuery.setParameter("offset", pageable.getOffset());

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        // Map to DTOs
        List<StationListItemDTO> stations = new ArrayList<>();
        for (Object[] row : results) {
            UUID stationId = (UUID) row[0];
            String name = (String) row[1];
            String address = (String) row[2];
            Double stationLat = ((Number) row[3]).doubleValue();
            Double stationLng = ((Number) row[4]).doubleValue();
            String operatingHours = (String) row[5];
            String parking = (String) row[6];
            String visibility = (String) row[7];
            String publicStatus = (String) row[8];

            // Fetch charging summary
            ChargingSummaryDTO chargingSummary = getChargingSummaryForStationVersion(stationId);
            
            // Get real trust score, default to 50 if not calculated yet
            Integer trustScore = trustRepository.findById(stationId)
                    .map(trust -> trust.getScore())
                    .orElse(50);

            stations.add(StationListItemDTO.builder()
                    .stationId(stationId.toString())
                    .name(name)
                    .address(address)
                    .lat(stationLat)
                    .lng(stationLng)
                    .operatingHours(operatingHours)
                    .parking(parking)
                    .visibility(visibility)
                    .publicStatus(publicStatus)
                    .chargingSummary(chargingSummary)
                    .trustScore(trustScore)
                    .supportsBatterySwap(stationSupportsBatterySwap(stationId))
                    .build());
        }

        return new PageImpl<>(stations, pageable, total);
    }

    @Override
    public Optional<StationDetailDTO> findPublishedStationDetail(UUID stationId) {
        String query = """
            SELECT 
                sv.station_id,
                sv.name,
                sv.address,
                ST_Y(CAST(sv.location AS geometry)) as lat,
                ST_X(CAST(sv.location AS geometry)) as lng,
                sv.operating_hours,
                sv.parking,
                sv.visibility,
                sv.public_status,
                sv.published_at
            FROM station_version sv
            WHERE sv.station_id = :stationId
            AND sv.workflow_status = 'PUBLISHED'
            """;

        Query nativeQuery = entityManager.createNativeQuery(query);
        nativeQuery.setParameter("stationId", stationId);

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        if (results.isEmpty()) {
            return Optional.empty();
        }

        Object[] row = results.get(0);
        UUID foundStationId = (UUID) row[0];
        String name = (String) row[1];
        String address = (String) row[2];
        Double lat = ((Number) row[3]).doubleValue();
        Double lng = ((Number) row[4]).doubleValue();
        String operatingHours = (String) row[5];
        String parking = (String) row[6];
        String visibility = (String) row[7];
        String publicStatus = (String) row[8];
        java.time.Instant publishedAt = row[9] != null ? 
            ((java.sql.Timestamp) row[9]).toInstant() : null;

        // Fetch charging ports
        List<PortInfoDTO> ports = getChargingPortsForStation(stationId);
        
        // Get real trust score, default to 50 if not calculated yet
        Integer trustScore = trustRepository.findById(stationId)
                .map(trust -> trust.getScore())
                .orElse(50);

        Optional<Object[]> swapRow = loadBatterySwapRow(stationId);
        StationDetailDTO.SwapServiceInfoDTO swapInfo = swapRow.map(StationQueryRepositoryImpl::mapSwapServiceInfo).orElse(null);

        return Optional.of(StationDetailDTO.builder()
                .stationId(foundStationId.toString())
                .name(name)
                .address(address)
                .lat(lat)
                .lng(lng)
                .operatingHours(operatingHours)
                .parking(parking)
                .visibility(visibility)
                .publicStatus(publicStatus)
                .publishedAt(publishedAt)
                .ports(ports)
                .trustScore(trustScore)
                .supportsBatterySwap(swapRow.isPresent())
                .batterySwap(swapInfo)
                .build());
    }

    private static StationDetailDTO.SwapServiceInfoDTO mapSwapServiceInfo(Object[] row) {
        Integer total = row[0] != null ? ((Number) row[0]).intValue() : null;
        BigDecimal avg = row[1] != null ? (BigDecimal) row[1] : null;
        Integer available = row[2] != null ? ((Number) row[2]).intValue() : null;
        return StationDetailDTO.SwapServiceInfoDTO.builder()
                .totalBatteries(total)
                .avgChargePowerKw(avg)
                .availableBatteries(available)
                .build();
    }

    private Optional<Object[]> loadBatterySwapRow(UUID stationId) {
        String q = """
                SELECT ss.total_batteries, ss.avg_charge_power_kw, COALESCE(bss.available_batteries, 0)
                FROM station_version sv
                JOIN station_service ss ON ss.station_version_id = sv.id AND ss.service_type = 'BATTERY_SWAP'
                LEFT JOIN battery_swap_station_state bss ON bss.station_id = sv.station_id
                WHERE sv.station_id = :stationId AND sv.workflow_status = 'PUBLISHED'
                """;
        Query nq = entityManager.createNativeQuery(q);
        nq.setParameter("stationId", stationId);
        @SuppressWarnings("unchecked")
        List<Object[]> rows = nq.getResultList();
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(rows.get(0));
    }

    private boolean stationSupportsBatterySwap(UUID stationId) {
        return loadBatterySwapRow(stationId).isPresent();
    }

    private ChargingSummaryDTO getChargingSummaryForStationVersion(UUID stationId) {
        String query = """
            SELECT 
                cp.power_type,
                cp.power_kw,
                cp.port_count
            FROM station_version sv
            JOIN station_service ss ON sv.id = ss.station_version_id
            JOIN charging_port cp ON ss.id = cp.station_service_id
            WHERE sv.station_id = :stationId
            AND sv.workflow_status = 'PUBLISHED'
            ORDER BY cp.power_type, cp.power_kw DESC NULLS LAST
            """;

        Query nativeQuery = entityManager.createNativeQuery(query);
        nativeQuery.setParameter("stationId", stationId);

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        List<PortInfoDTO> ports = new ArrayList<>();
        int totalPorts = 0;
        BigDecimal maxPowerKw = null;

        for (Object[] row : results) {
            String powerType = (String) row[0];
            BigDecimal powerKw = row[1] != null ? (BigDecimal) row[1] : null;
            Integer portCount = ((Number) row[2]).intValue();

            ports.add(PortInfoDTO.builder()
                    .powerType(powerType)
                    .powerKw(powerKw)
                    .count(portCount)
                    .build());

            totalPorts += portCount;

            // Track max DC power
            if (PowerType.DC.name().equals(powerType) && powerKw != null) {
                if (maxPowerKw == null || powerKw.compareTo(maxPowerKw) > 0) {
                    maxPowerKw = powerKw;
                }
            }
        }

        return ChargingSummaryDTO.builder()
                .totalPorts(totalPorts)
                .maxPowerKw(maxPowerKw)
                .ports(ports)
                .build();
    }

    private List<PortInfoDTO> getChargingPortsForStation(UUID stationId) {
        String query = """
            SELECT 
                cp.power_type,
                cp.power_kw,
                cp.port_count
            FROM station_version sv
            JOIN station_service ss ON sv.id = ss.station_version_id
            JOIN charging_port cp ON ss.id = cp.station_service_id
            WHERE sv.station_id = :stationId
            AND sv.workflow_status = 'PUBLISHED'
            ORDER BY cp.power_type, cp.power_kw DESC NULLS LAST
            """;

        Query nativeQuery = entityManager.createNativeQuery(query);
        nativeQuery.setParameter("stationId", stationId);

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        return results.stream()
                .map(row -> PortInfoDTO.builder()
                        .powerType((String) row[0])
                        .powerKw(row[1] != null ? (BigDecimal) row[1] : null)
                        .count(((Number) row[2]).intValue())
                        .build())
                .collect(Collectors.toList());
    }

    @Override
    public Page<StationListItemDTO> searchPublishedStationsByName(
            String nameQuery,
            Pageable pageable) {
        
        // Build search query with case-insensitive LIKE
        String searchPattern = "%" + nameQuery.toLowerCase() + "%";
        
        String query = """
            SELECT 
                sv.station_id,
                sv.name,
                sv.address,
                ST_Y(CAST(sv.location AS geometry)) as lat,
                ST_X(CAST(sv.location AS geometry)) as lng,
                sv.operating_hours,
                sv.parking,
                sv.visibility,
                sv.public_status
            FROM station_version sv
            WHERE sv.workflow_status = 'PUBLISHED'
            AND LOWER(sv.name) LIKE :searchPattern
            ORDER BY sv.name
            LIMIT :limit OFFSET :offset
            """;

        String countQuery = """
            SELECT COUNT(DISTINCT sv.station_id)
            FROM station_version sv
            WHERE sv.workflow_status = 'PUBLISHED'
            AND LOWER(sv.name) LIKE :searchPattern
            """;

        // Count total
        Query countNativeQuery = entityManager.createNativeQuery(countQuery);
        countNativeQuery.setParameter("searchPattern", searchPattern);
        long total = ((Number) countNativeQuery.getSingleResult()).longValue();

        // Get paginated results
        Query nativeQuery = entityManager.createNativeQuery(query);
        nativeQuery.setParameter("searchPattern", searchPattern);
        nativeQuery.setParameter("limit", pageable.getPageSize());
        nativeQuery.setParameter("offset", pageable.getOffset());

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        // Map to DTOs
        List<StationListItemDTO> stations = new ArrayList<>();
        for (Object[] row : results) {
            UUID stationId = (UUID) row[0];
            String name = (String) row[1];
            String address = (String) row[2];
            Double stationLat = ((Number) row[3]).doubleValue();
            Double stationLng = ((Number) row[4]).doubleValue();
            String operatingHours = (String) row[5];
            String parking = (String) row[6];
            String visibility = (String) row[7];
            String publicStatus = (String) row[8];

            // Fetch charging summary
            ChargingSummaryDTO chargingSummary = getChargingSummaryForStationVersion(stationId);
            
            // Get real trust score, default to 50 if not calculated yet
            Integer trustScore = trustRepository.findById(stationId)
                    .map(trust -> trust.getScore())
                    .orElse(50);

            stations.add(StationListItemDTO.builder()
                    .stationId(stationId.toString())
                    .name(name)
                    .address(address)
                    .lat(stationLat)
                    .lng(stationLng)
                    .operatingHours(operatingHours)
                    .parking(parking)
                    .visibility(visibility)
                    .publicStatus(publicStatus)
                    .chargingSummary(chargingSummary)
                    .trustScore(trustScore)
                    .supportsBatterySwap(stationSupportsBatterySwap(stationId))
                    .build());
        }

        return new PageImpl<>(stations, pageable, total);
    }

    @Override
    public List<RecommendedStationDTO> findStationsAlongRoute(
            String routeWkt,
            double bufferMeters,
            Double minPowerKw,
            int limit,
            List<PolylinePoint> polyline,
            Integer batteryPercent,
            Double vehicleRangeKm,
            Double routeDistanceKm) {
        
        log.debug("Finding stations along route with WKT: {}, batteryPercent: {}, vehicleRangeKm: {}", 
                routeWkt, batteryPercent, vehicleRangeKm);
        
        String distanceFilter = minPowerKw != null
                ? " AND total_power_kw >= " + minPowerKw.doubleValue()
                : "";

        String baseQuery = "WITH route_line AS ("
                + " SELECT ST_GeomFromText('" + routeWkt + "', 4326)::geography AS route_geog),"
                + " station_distances AS ("
                + " SELECT"
                + " sv.station_id,"
                + " sv.name,"
                + " sv.address,"
                + " ST_Y(CAST(sv.location AS geometry)) as lat,"
                + " ST_X(CAST(sv.location AS geometry)) as lng,"
                + " CAST(ST_Distance(CAST(sv.location AS geography), rl.route_geog) AS DOUBLE PRECISION) as distance_from_route_meters,"
                + " COALESCE((SELECT SUM(cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id), 0) as total_ports,"
                + " COALESCE((SELECT SUM(cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id LEFT JOIN charging_unit cu ON cp.charging_unit_id = cu.id WHERE ss.station_version_id = sv.id AND cu.status = 'ACTIVE'), 0) as available_ports,"
                + " COALESCE((SELECT SUM(cp.power_kw * cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id AND cp.power_type = 'DC'), 0) as total_power_kw,"
                + " (SELECT ARRAY_AGG(DISTINCT cp.connector_type) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id) as connector_types"
                + " FROM station_version sv, route_line rl"
                + " WHERE sv.workflow_status = 'PUBLISHED'"
                + " AND ST_DWithin(CAST(sv.location AS geography), rl.route_geog, " + bufferMeters + ")"
                + distanceFilter
                + ")"
                + " SELECT station_id, name, address, lat, lng, distance_from_route_meters, total_ports, available_ports, total_power_kw, connector_types"
                + " FROM station_distances"
                + " WHERE total_ports > 0"
                + distanceFilter
                + " ORDER BY distance_from_route_meters ASC"
                + " LIMIT " + limit;

        Query nativeQuery = entityManager.createNativeQuery(baseQuery);
        
        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        // Batch-fetch all trust scores in a single query to avoid N+1
        List<UUID> stationIds = results.stream()
                .map(row -> (UUID) row[0])
                .collect(Collectors.toList());
        Map<UUID, Integer> trustScoreMap = stationIds.isEmpty()
                ? Collections.emptyMap()
                : trustRepository.findAllById(stationIds).stream()
                        .collect(Collectors.toMap(
                                StationTrustEntity::getStationId,
                                StationTrustEntity::getScore));

        // Determine if EV parameters are available
        boolean hasEvParams = batteryPercent != null && vehicleRangeKm != null && routeDistanceKm != null;
        double currentRangeKm = hasEvParams ? (batteryPercent / 100.0) * vehicleRangeKm : 0;
        double defaultConsumption = 0.18; // kWh/km
        
        // Map to RecommendedStationDTO with EV-aware scoring
        List<RecommendedStationDTO> stations = new ArrayList<>();
        for (Object[] row : results) {
            UUID stationId = (UUID) row[0];
            String name = (String) row[1];
            String address = (String) row[2];
            Double lat = ((Number) row[3]).doubleValue();
            Double lng = ((Number) row[4]).doubleValue();
            double distanceFromRouteMeters = ((Number) row[5]).doubleValue();
            int totalPorts = ((Number) row[6]).intValue();
            int availablePorts = ((Number) row[7]).intValue();
            double totalPowerKw = row[8] != null ? ((Number) row[8]).doubleValue() : 0;
            
            // Parse connector types array
            List<String> connectorTypes = new ArrayList<>();
            Object connectorTypesObj = row[9];
            if (connectorTypesObj instanceof Object[]) {
                for (Object ct : (Object[]) connectorTypesObj) {
                    if (ct != null) connectorTypes.add(ct.toString());
                }
            } else if (connectorTypesObj instanceof List) {
                connectorTypes.addAll((List<String>) connectorTypesObj);
            }
            
            // Get trust score from batch-loaded map (N+1 fix)
            Integer trustScore = trustScoreMap.getOrDefault(stationId, 50);
            
            // Calculate detour meters (distance from route to station and back)
            double detourMeters = distanceFromRouteMeters * 2;
            
            // Estimate arrival time based on distance from route
            int estimatedArrivalMinutes = (int) Math.ceil(distanceFromRouteMeters / 500.0); // ~30km/h average
            
            // Estimate wait time (simplified: assume 10 min wait if no ports available)
            int waitTimeMinutes = availablePorts == 0 ? 10 : 0;
            
            // Calculate EV-aware score
            double score;
            int estimatedChargeMinutes;
            double batteryCompatibilityScore = 1.0; // Default: compatible
            
            if (hasEvParams) {
                double distanceToStationKm = distanceFromRouteMeters / 1000.0;
                double rangeAfterArrivalKm = currentRangeKm - (distanceToStationKm * 1.1); // 10% safety buffer
                
                if (rangeAfterArrivalKm <= 0) {
                    // Can't reach this station, very high penalty
                    score = 100000;
                    estimatedChargeMinutes = 60;
                } else {
                    // Calculate how much charge needed to continue to destination
                    // Assuming station is ~50% along the route on average
                    double remainingRouteKm = routeDistanceKm * 0.5;
                    double neededKwh = remainingRouteKm * defaultConsumption;
                    double chargeMinutes = (neededKwh / Math.max(totalPowerKw, 1.0)) * 60.0;
                    estimatedChargeMinutes = (int) Math.min(Math.ceil(chargeMinutes), 120.0); // Cap at 2 hours
                    
                    // New scoring formula for EV-aware routing
                    // score = (detourMeters * 1.0) + (totalPowerKw == 0 ? 10000 : -totalPowerKw * 1.5) 
                    //       + (availablePorts == 0 ? 500 : -availablePorts * 8.0) + (waitTimeMinutes * 2.0) 
                    //       + (totalChargeMinutes * 0.5) + (batteryCompatibilityScore * -200.0)
                    score = (detourMeters * 1.0)
                            + (totalPowerKw == 0 ? 10000 : -totalPowerKw * 1.5)
                            + (availablePorts == 0 ? 500 : -availablePorts * 8.0)
                            + (waitTimeMinutes * 2.0)
                            + (estimatedChargeMinutes * 0.5)
                            + (batteryCompatibilityScore * -200.0);
                }
            } else {
                // Fallback: old scoring logic
                estimatedChargeMinutes = totalPowerKw > 0 ? 30 : 20;
                score = (detourMeters * 1.0) 
                        + (totalPowerKw == 0 ? 10000 : -totalPowerKw * 2.0) 
                        + (availablePorts == 0 ? 500 : -availablePorts * 10.0) 
                        + (waitTimeMinutes * 3.0);
            }
            
            // Calculate optimal charging stop minutes (total time at this stop)
            int optimalChargingStopMinutes = estimatedArrivalMinutes + waitTimeMinutes + estimatedChargeMinutes;
            
            // Calculate remaining range after charging to 80%
            double remainingRangeAfterStopKm = (80.0 / 100.0) * vehicleRangeKm;
            
            // Calculate distance in km
            double distanceKm = distanceFromRouteMeters / 1000.0;
            
            stations.add(RecommendedStationDTO.builder()
                    .stationId(stationId.toString())
                    .name(name)
                    .address(address)
                    .lat(lat)
                    .lng(lng)
                    .distanceFromRouteMeters(distanceFromRouteMeters)
                    .detourMeters(detourMeters)
                    .totalPowerKw(totalPowerKw)
                    .availablePorts(availablePorts)
                    .totalPorts(totalPorts)
                    .connectorTypes(connectorTypes)
                    .rating(trustScore != null ? trustScore / 20.0 : null)
                    .estimatedArrivalMinutes(estimatedArrivalMinutes)
                    .waitTimeMinutes(waitTimeMinutes)
                    .estimatedChargeMinutes(estimatedChargeMinutes)
                    .optimalChargingStopMinutes((double) optimalChargingStopMinutes)
                    .isOptimalStop(false)
                    .remainingRangeAfterStopKm(hasEvParams ? remainingRangeAfterStopKm : null)
                    .score(score)
                    .distanceKm(distanceKm)
                    .build());
        }
        
        // Sort by score (lower is better)
        stations.sort(Comparator.comparingDouble(RecommendedStationDTO::getScore));

        // NOTE: isOptimalStop is set ONLY by RoutingService.selectOptimalStation(),
        // not here. Do NOT mark optimal stop at the repository level —
        // the service has full EV context to make the final decision.
        return stations;
    }
}

