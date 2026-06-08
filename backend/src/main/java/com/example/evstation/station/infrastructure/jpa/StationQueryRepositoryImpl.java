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

    // -------------------------------------------------------------------------
    // Constants for scoring weights
    // -------------------------------------------------------------------------

    /**
     * Scoring weight: detour distance (meters).
     * Penalty grows linearly with detour — low detour = low penalty.
     */
    private static final double WEIGHT_DETOUR = 2.0;

    /**
     * Scoring weight: charging power (kW).
     * Reward for high-power stations — faster charging.
     */
    private static final double WEIGHT_POWER = -1.5;

    /**
     * Scoring weight: available ports (count).
     * Reward for availability — fewer queues expected.
     */
    private static final double WEIGHT_AVAILABLE_PORTS = -5.0;

    /**
     * Scoring weight: estimated wait time (minutes).
     * Penalty for expected wait — busy stations are penalized.
     */
    private static final double WEIGHT_WAIT_TIME = 1.5;

    /**
     * Scoring weight: estimated charging time (minutes).
     * Penalty for slower charging sessions.
     */
    private static final double WEIGHT_CHARGE_TIME = 0.3;

    /**
     * Penalty applied when a station cannot be reached with current battery.
     * This is an order-of-magnitude higher than any normal score to ensure
     * unreachable stations are always ranked last.
     */
    private static final double PENALTY_UNREACHABLE = 100_000;

    /**
     * Score assigned to unreachable stations (constant penalty).
     */
    private static final double SCORE_UNREACHABLE = 50_000;

    @Override
    public List<RecommendedStationDTO> findStationsAlongRoute(
            String routeWkt,
            double bufferMeters,
            Double minPowerKw,
            int limit,
            List<PolylinePoint> polyline,
            Integer batteryPercent,
            Double vehicleRangeKm,
            Double routeDistanceKm,
            String traceId) {

        boolean hasEvParams = batteryPercent != null && vehicleRangeKm != null && routeDistanceKm != null;
        double currentRangeKm = hasEvParams ? (batteryPercent / 100.0) * vehicleRangeKm : 0;

        log.info("[REPO] findStationsAlongRoute ENTER | bufferM={} minPower={} limit={} "
                        + "hasEvParams={} batteryPercent={} vehicleRangeKm={} routeDistanceKm={} "
                        + "routeWktLength={} polylineSize={}",
                bufferMeters, minPowerKw, limit, hasEvParams, batteryPercent,
                vehicleRangeKm, routeDistanceKm,
                routeWkt.length(), polyline.size());

        // Diagnostic: validate WKT before passing to DB
        if (routeWkt == null || routeWkt.isEmpty() || "LINESTRING EMPTY".equals(routeWkt)) {
            log.error("[REPO] INVALID_ROUTE_WKT | routeWkt='{}' — empty or invalid WKT", routeWkt);
            return Collections.emptyList();
        }

        // Diagnostic: first/last point validation
        if (!polyline.isEmpty()) {
            PolylinePoint first = polyline.get(0);
            PolylinePoint last = polyline.get(polyline.size() - 1);
            log.info("[REPO] WKT_BOUNDS | firstPoint=({},{}) lastPoint=({},{}) "
                            + "totalPoints={}",
                    first.getLat(), first.getLng(),
                    last.getLat(), last.getLng(),
                    polyline.size());

            // Validate coordinate ranges
            if (Math.abs(first.getLat()) > 90 || Math.abs(first.getLng()) > 180 ||
                    Math.abs(last.getLat()) > 90 || Math.abs(last.getLng()) > 180) {
                log.error("[REPO] INVALID_COORDINATES | first=({},{}) last=({},{})",
                        first.getLat(), first.getLng(), last.getLat(), last.getLng());
            }
        }

        String distanceFilter = minPowerKw != null
                ? " AND total_power_kw >= " + minPowerKw.doubleValue()
                : "";

        String baseQuery = "WITH route_line AS ("
                + " SELECT ST_GeomFromText('" + routeWkt + "', 4326)::geography AS route_geog),"
                + " route_origin AS ("
                + " SELECT ST_GeomFromText('POINT("
                + polyline.get(0).getLng() + " " + polyline.get(0).getLat()
                + ")' , 4326)::geography AS origin_geog),"
                + " station_data AS ("
                + " SELECT"
                + " sv.station_id,"
                + " sv.name,"
                + " sv.address,"
                + " ST_Y(CAST(sv.location AS geometry)) as lat,"
                + " ST_X(CAST(sv.location AS geometry)) as lng,"
                + " CAST(ST_Distance(CAST(sv.location AS geography), rl.route_geog) AS DOUBLE PRECISION) AS distance_from_route_meters,"
                + " CAST(ST_Distance(CAST(sv.location AS geography), ro.origin_geog) AS DOUBLE PRECISION) AS distance_from_origin_meters,"
                + " COALESCE((SELECT SUM(cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id), 0) AS total_ports,"
                + " COALESCE((SELECT SUM(cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id LEFT JOIN charging_unit cu ON cp.charging_unit_id = cu.id WHERE ss.station_version_id = sv.id AND cu.status = 'ACTIVE'), 0) AS available_ports,"
                + " COALESCE((SELECT SUM(cp.power_kw * cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id AND cp.power_type = 'DC'), 0) AS total_power_kw,"
                + " (SELECT ARRAY_AGG(DISTINCT cp.connector_type) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id) AS connector_types"
                + " FROM station_version sv, route_line rl, route_origin ro"
                + " WHERE sv.workflow_status = 'PUBLISHED'"
                + " AND ST_DWithin(CAST(sv.location AS geography), rl.route_geog, " + bufferMeters + ")"
                + distanceFilter
                + ")"
                + " SELECT station_id, name, address, lat, lng,"
                + " distance_from_route_meters, distance_from_origin_meters,"
                + " total_ports, available_ports, total_power_kw, connector_types"
                + " FROM station_data"
                + " WHERE total_ports > 0"
                + " ORDER BY distance_from_route_meters ASC"
                + " LIMIT " + limit;

        // Dump the exact SQL for direct psql debugging
        log.info("[REPO] QUERY_DUMP | sql={} traceId={}", baseQuery, traceId);

        // Count check: how many PUBLISHED stations exist total?
        try {
            String countSql = "SELECT COUNT(*) FROM station_version WHERE workflow_status = 'PUBLISHED'";
            Query countCheck = entityManager.createNativeQuery(countSql);
            Long totalPublished = ((Number) countCheck.getSingleResult()).longValue();
            log.info("[REPO] PUBLISHED_STATIONS_IN_DB | totalCount={} traceId={}", totalPublished, traceId);
            if (totalPublished == 0) {
                log.error("[REPO] ZERO_PUBLISHED_STATIONS | "
                                + "The station_version table has NO PUBLISHED stations! "
                                + "This is the root cause of stations=0. "
                                + "Publish stations via admin panel first. traceId={}",
                        traceId);
            }
        } catch (Exception e) {
            log.warn("[REPO] COUNT_CHECK_FAILED | message={} traceId={}", e.getMessage(), traceId);
        }

        Query nativeQuery = entityManager.createNativeQuery(baseQuery);

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        log.info("[REPO] POSTGIS_QUERY_RESULT | rawRowsReturned={} limit={} traceId={}",
                results.size(), limit, traceId);

        if (results.isEmpty()) {
            log.warn("[REPO] NO_STATIONS_IN_CORRIDOR | "
                            + "bufferMeters={} routeWktLength={} "
                            + "hint='Run this query directly in psql to debug: "
                            + "SELECT COUNT(*) FROM station_version sv "
                            + "WHERE sv.workflow_status = ''PUBLISHED'' "
                            + "AND ST_DWithin(CAST(sv.location AS geography), "
                            + "CAST(ST_GeomFromText('''{}''', 4326) AS geography), {})'",
                    bufferMeters, routeWkt.length(), routeWkt, bufferMeters);
        } else {
            log.info("[REPO] STATIONS_FOUND | count={}", results.size());
            for (int i = 0; i < Math.min(results.size(), 5); i++) {
                Object[] row = results.get(i);
                log.info("[REPO] stationRow[{}] | id={} name='{}' "
                                + "distanceFromRouteM={} totalPowerKw={} availablePorts={}",
                        i, row[0],
                        row[1] != null ? ((String) row[1]).substring(0, Math.min(30, ((String) row[1]).length())) : "null",
                        row[5], row[9], row[8]);
            }
        }

        // Batch-fetch trust scores to avoid N+1
        List<UUID> stationIds = results.stream()
                .map(row -> (UUID) row[0])
                .collect(Collectors.toList());
        Map<UUID, Integer> trustScoreMap = stationIds.isEmpty()
                ? Collections.emptyMap()
                : trustRepository.findAllById(stationIds).stream()
                        .collect(Collectors.toMap(
                                StationTrustEntity::getStationId,
                                StationTrustEntity::getScore));

        List<RecommendedStationDTO> stations = new ArrayList<>();
        for (Object[] row : results) {
            UUID stationId = (UUID) row[0];
            String name = (String) row[1];
            String address = (String) row[2];
            double lat = ((Number) row[3]).doubleValue();
            double lng = ((Number) row[4]).doubleValue();
            double distanceFromRouteMeters = ((Number) row[5]).doubleValue();
            double distanceFromOriginMeters = ((Number) row[6]).doubleValue();
            int totalPorts = ((Number) row[7]).intValue();
            int availablePorts = ((Number) row[8]).intValue();
            double totalPowerKw = row[9] != null ? ((Number) row[9]).doubleValue() : 0;

            // Parse connector types
            List<String> connectorTypes = parseConnectorTypes(row[10]);

            // Trust score
            Integer trustScore = trustScoreMap.getOrDefault(stationId, 50);

            // Detour: round-trip distance from route to station
            double detourMeters = distanceFromRouteMeters * 2;

            // Estimated arrival time from origin (~30 km/h avg urban speed)
            double avgSpeedMps = 30.0 / 3.6;
            int estimatedArrivalMinutes = (int) Math.ceil(distanceFromOriginMeters / avgSpeedMps / 60.0);

            // Estimated wait: 10 min if no ports available
            int waitTimeMinutes = availablePorts == 0 ? 10 : 0;

            // Battery at arrival (EV-aware)
            double batteryAtArrival = 0;
            double score;
            int estimatedChargeMinutes;
            String recommendationReason;
            String filterReason = null; // For diagnostic logging

            if (hasEvParams && vehicleRangeKm > 0) {
                double distanceToStationKm = distanceFromOriginMeters / 1000.0;
                double energyUsedKwh = distanceToStationKm * 0.18; // 0.18 kWh/km consumption
                double batteryUsedPercent = (energyUsedKwh / vehicleRangeKm) * 100.0;
                batteryAtArrival = Math.max(0, batteryPercent - batteryUsedPercent);

                if (batteryAtArrival < 10) {
                    // Cannot reach safely — assign unreachable score
                    score = SCORE_UNREACHABLE;
                    estimatedChargeMinutes = 0;
                    recommendationReason = "Cannot reach - not enough battery for the detour distance";
                    filterReason = "BATTERY_TOO_LOW";
                    log.info("[REPO] stationExcluded | id={} reason={} batteryAtArrival={} "
                                    + "distanceFromOriginM={} traceId={}",
                            stationId, filterReason, batteryAtArrival, distanceFromOriginMeters, traceId);
                } else {
                    // Distance remaining along route from this station
                    double remainingRouteKm = Math.max(0, routeDistanceKm - distanceToStationKm);
                    double energyNeededKwh = remainingRouteKm * 0.18;
                    double chargeNeededPercent = Math.min(100, (energyNeededKwh / vehicleRangeKm) * 100.0);
                    double targetPercent = Math.min(100, batteryAtArrival + chargeNeededPercent);

                    estimatedChargeMinutes = totalPowerKw > 0
                            ? (int) Math.min(Math.ceil((chargeNeededPercent / 100.0 * vehicleRangeKm) / Math.max(totalPowerKw, 1) * 60.0), 120)
                            : 30;

                    // Score = detour*2 + (-power*1.5) + (-availablePorts*5) + waitTime*1.5 + chargeTime*0.3
                    score = (detourMeters * WEIGHT_DETOUR)
                            + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                            + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                            + (waitTimeMinutes * WEIGHT_WAIT_TIME)
                            + (estimatedChargeMinutes * WEIGHT_CHARGE_TIME);

                    recommendationReason = buildRecommendationReason(
                            distanceFromRouteMeters, totalPowerKw, availablePorts,
                            waitTimeMinutes, estimatedChargeMinutes, batteryAtArrival);
                    filterReason = "INCLUDED";
                }
            } else {
                // No EV params — fallback to basic scoring
                batteryAtArrival = 0;
                estimatedChargeMinutes = totalPowerKw > 0 ? 30 : 20;
                waitTimeMinutes = availablePorts == 0 ? 10 : 0;
                score = (detourMeters * WEIGHT_DETOUR)
                        + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                        + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                        + (waitTimeMinutes * WEIGHT_WAIT_TIME)
                        + (estimatedChargeMinutes * WEIGHT_CHARGE_TIME);
                recommendationReason = buildFallbackRecommendationReason(
                        distanceFromRouteMeters, totalPowerKw, availablePorts);
                filterReason = "INCLUDED_NO_EV_PARAMS";
            }

            log.info("[REPO] stationScored | id={} name='{}' score={} filterReason={} "
                            + "distanceFromRouteM={} batteryAtArrival={} totalPowerKw={} "
                            + "availablePorts={}/{} traceId={}",
                    stationId,
                    name.length() > 40 ? name.substring(0, 40) : name,
                    score, filterReason, distanceFromRouteMeters, batteryAtArrival,
                    totalPowerKw, availablePorts, totalPorts, traceId);

            int optimalChargingStopMinutes = estimatedArrivalMinutes + waitTimeMinutes + estimatedChargeMinutes;
            double remainingRangeAfterStopKm = hasEvParams
                    ? Math.min(100, batteryAtArrival + (vehicleRangeKm * 0.5)) / 100.0 * vehicleRangeKm
                    : null;

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
                    .remainingRangeAfterStopKm(remainingRangeAfterStopKm)
                    .estimatedBatteryAtArrival(hasEvParams ? batteryAtArrival : null)
                    .recommendationReason(recommendationReason)
                    .score(score)
                    .distanceKm(distanceFromRouteMeters / 1000.0)
                    .build());
        }

        stations.sort(Comparator.comparingDouble(RecommendedStationDTO::getScore));

        log.info("[REPO] findStationsAlongRoute EXIT | "
                        + "totalScored={} sortedCount={} "
                        + "unreachableCount={} includedCount={} "
                        + "traceId={}",
                stations.size(), stations.size(),
                stations.stream().filter(s -> s.getScore() >= 50_000).count(),
                stations.stream().filter(s -> s.getScore() < 50_000).count(),
                traceId);
        return stations;
    }

    private List<String> parseConnectorTypes(Object obj) {
        List<String> connectorTypes = new ArrayList<>();
        if (obj instanceof Object[]) {
            for (Object ct : (Object[]) obj) {
                if (ct != null) connectorTypes.add(ct.toString());
            }
        } else if (obj instanceof List) {
            connectorTypes.addAll((List<String>) obj);
        }
        return connectorTypes;
    }

    /**
     * Builds a human-readable recommendation reason in English.
     */
    private String buildRecommendationReason(
            double distanceFromRouteMeters,
            double totalPowerKw,
            int availablePorts,
            int waitTimeMinutes,
            int estimatedChargeMinutes,
            double batteryAtArrival) {

        StringBuilder sb = new StringBuilder();

        if (distanceFromRouteMeters <= 200) {
            sb.append("Right on route");
        } else if (distanceFromRouteMeters <= 500) {
            sb.append("Very close to route");
        } else {
            sb.append("Near route");
        }

        if (totalPowerKw >= 150) {
            sb.append(" • Fast charging ").append((int) totalPowerKw).append("kW");
        } else if (totalPowerKw >= 50) {
            sb.append(" • Power ").append((int) totalPowerKw).append("kW");
        }

        if (availablePorts >= 3) {
            sb.append(" • Many ports available");
        } else if (availablePorts == 0) {
            sb.append(" • May wait ~").append(waitTimeMinutes).append(" min");
        } else {
            sb.append(" • ").append(availablePorts).append(" ports free");
        }

        sb.append(" • Estimated charge time ").append(estimatedChargeMinutes).append(" min");
        sb.append(String.format(" • Battery ~%.0f%% at arrival", batteryAtArrival));

        return sb.toString();
    }

    private String buildFallbackRecommendationReason(
            double distanceFromRouteMeters,
            double totalPowerKw,
            int availablePorts) {

        String proximity = distanceFromRouteMeters <= 200 ? "Right on route"
                : distanceFromRouteMeters <= 500 ? "Very close to route"
                : "Near route";
        String power = totalPowerKw >= 50 ? " • " + (int) totalPowerKw + "kW" : "";
        String ports = availablePorts >= 2 ? " • " + availablePorts + " ports free"
                : availablePorts == 0 ? " • May need to wait" : " • 1 port free";

        return proximity + power + ports;
    }
}

