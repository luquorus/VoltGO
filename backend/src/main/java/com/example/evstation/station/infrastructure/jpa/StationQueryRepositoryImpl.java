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
import org.springframework.beans.factory.annotation.Value;
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

    @Value("${app.routing.min-battery-percent-at-arrival:5}")
    private double minBatteryPercentAtArrival;

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
                    .batterySwap(getBatterySwapSummaryForStation(stationId))
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

    /**
     * Build a BatterySwapSummaryDTO for the station's PUBLISHED version.
     * Returns null if the station does not support battery swap.
     */
    private BatterySwapSummaryDTO getBatterySwapSummaryForStation(UUID stationId) {
        Optional<Object[]> swapRow = loadBatterySwapRow(stationId);
        if (swapRow.isEmpty()) {
            return null;
        }
        Object[] row = swapRow.get();
        Integer totalBatteries = row[0] != null ? ((Number) row[0]).intValue() : null;
        BigDecimal avgChargePowerKw = row[1] != null ? (BigDecimal) row[1] : null;
        Integer availableBatteries = row[2] != null ? ((Number) row[2]).intValue() : null;

        // Count total piles + available slots for the PUBLISHED version
        String q = """
                SELECT
                    (SELECT COUNT(*) FROM swap_pile p
                     WHERE p.station_id = :stationId),
                    COALESCE((
                        SELECT COUNT(*) FROM battery_slot s
                        JOIN swap_pile p ON p.id = s.pile_id
                        WHERE p.station_id = :stationId
                          AND s.status = 'AVAILABLE'
                    ), 0)
                """;
        Query nq = entityManager.createNativeQuery(q);
        nq.setParameter("stationId", stationId);
        @SuppressWarnings("unchecked")
        List<Object> rows = nq.getResultList();
        Integer totalPiles = null;
        Integer availableSlots = null;
        if (!rows.isEmpty() && rows.get(0) != null) {
            Object[] counts = (Object[]) rows.get(0);
            totalPiles = counts[0] != null ? ((Number) counts[0]).intValue() : null;
            availableSlots = counts[1] != null ? ((Number) counts[1]).intValue() : null;
        }

        return BatterySwapSummaryDTO.builder()
                .totalPiles(totalPiles)
                .totalSlots(totalBatteries)
                .availableBatteries(availableBatteries)
                .availableSlots(availableSlots)
                .avgChargePowerKw(avgChargePowerKw)
                .build();
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

        // Only return stations that have at least one CHARGING service.
        // Without this filter, battery-swap-only stations (which still have a
        // row in station_version) would be returned by this endpoint and the
        // EV user change-request form would surface the wrong station kind.
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
            AND EXISTS (
                SELECT 1 FROM station_service ss
                WHERE ss.station_version_id = sv.id
                AND ss.service_type = 'CHARGING'
            )
            ORDER BY sv.name
            LIMIT :limit OFFSET :offset
            """;

        String countQuery = """
            SELECT COUNT(DISTINCT sv.station_id)
            FROM station_version sv
            WHERE sv.workflow_status = 'PUBLISHED'
            AND LOWER(sv.name) LIKE :searchPattern
            AND EXISTS (
                SELECT 1 FROM station_service ss
                WHERE ss.station_version_id = sv.id
                AND ss.service_type = 'CHARGING'
            )
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
                    .batterySwap(getBatterySwapSummaryForStation(stationId))
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

    // Scoring weights - BATTERY SWAP
    private static final double WEIGHT_SWAP_DETOUR = 2.0;
    private static final double WEIGHT_SWAP_AVAILABLE_BATTERIES = -3.0;
    private static final double WEIGHT_SWAP_PRICE = 0.01;
    private static final int SWAP_SERVICE_TIME_MINUTES = 5;
    private static final long SWAP_BASE_PRICE_VND = 5_000;
    private static final double SWAP_PENALTY_NO_BATTERY = 80_000;

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
                + " SELECT CAST(ST_GeomFromText('" + routeWkt + "', 4326) AS geography) AS route_geog),"
                + " route_origin AS ("
                + " SELECT CAST(ST_GeomFromText('POINT("
                + polyline.get(0).getLng() + " " + polyline.get(0).getLat()
                + ")', 4326) AS geography) AS origin_geog),"
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
                + " COALESCE((SELECT SUM(cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id), 0) AS available_ports,"
                + " COALESCE((SELECT SUM(cp.power_kw * cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id AND cp.power_type = 'DC'), 0) AS total_power_kw,"
                + " CAST(NULL AS text[]) AS connector_types"
                + " FROM station_version sv"
                + " INNER JOIN route_line rl ON true"
                + " INNER JOIN route_origin ro ON true"
                + " LEFT JOIN battery_swap_station_state bss ON bss.station_id = sv.station_id"
                + " WHERE sv.workflow_status = 'PUBLISHED'"
                + " AND ST_DWithin(CAST(sv.location AS geography), rl.route_geog, " + bufferMeters + ")"
                + distanceFilter
                + ")"
                + " SELECT station_data.station_id, station_data.name, station_data.address, station_data.lat, station_data.lng,"
                + " station_data.distance_from_route_meters, station_data.distance_from_origin_meters,"
                + " station_data.total_ports, station_data.available_ports, station_data.total_power_kw, station_data.connector_types,"
                + " COALESCE((SELECT SUM(ss.total_batteries) FROM station_service ss WHERE ss.station_version_id = station_data.station_id AND ss.service_type = 'BATTERY_SWAP'), 0) AS total_batteries,"
                + " COALESCE(bss.available_batteries, 0) AS available_batteries,"
                + " COALESCE(bss.avg_charge_power_kw, 0) AS avg_charge_power_kw,"
                + " CASE WHEN station_data.total_ports > 0 AND station_data.total_power_kw > 0 AND (SELECT SUM(ss.total_batteries) FROM station_service ss WHERE ss.station_version_id = station_data.station_id AND ss.service_type = 'BATTERY_SWAP') > 0 THEN 'BOTH'"
                + "      WHEN station_data.total_ports > 0 AND station_data.total_power_kw > 0 THEN 'CHARGING'"
                + "      WHEN (SELECT SUM(ss.total_batteries) FROM station_service ss WHERE ss.station_version_id = station_data.station_id AND ss.service_type = 'BATTERY_SWAP') > 0 THEN 'BATTERY_SWAP'"
                + "      ELSE 'CHARGING'"
                + " END AS service_type"
                + " FROM station_data"
                + " LEFT JOIN battery_swap_station_state bss ON bss.station_id = station_data.station_id"
                + " WHERE (station_data.total_ports > 0 OR (SELECT SUM(ss.total_batteries) FROM station_service ss WHERE ss.station_version_id = station_data.station_id AND ss.service_type = 'BATTERY_SWAP') > 0)"
                + " ORDER BY station_data.distance_from_route_meters ASC"
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

            // Battery swap data
            int totalBatteries = row.length > 11 && row[11] != null ? ((Number) row[11]).intValue() : 0;
            int availableBatteries = row.length > 12 && row[12] != null ? ((Number) row[12]).intValue() : 0;
            double avgChargePowerKw = row.length > 13 && row[13] != null ? ((Number) row[13]).doubleValue() : 0;
            long basePriceVnd = SWAP_BASE_PRICE_VND;
            String serviceTypeStr = row.length > 14 && row[14] != null ? (String) row[14] : "CHARGING";
            RecommendedStationDTO.ServiceType serviceType;
            if ("BOTH".equals(serviceTypeStr)) {
                serviceType = RecommendedStationDTO.ServiceType.BOTH;
            } else if ("BATTERY_SWAP".equals(serviceTypeStr)) {
                serviceType = RecommendedStationDTO.ServiceType.BATTERY_SWAP;
            } else {
                serviceType = RecommendedStationDTO.ServiceType.CHARGING;
            }

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

                if (batteryAtArrival < minBatteryPercentAtArrival) {
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

                    // Unified scoring
                    score = computeUnifiedScore(
                            serviceType, detourMeters, totalPowerKw, availablePorts,
                            totalBatteries, availableBatteries, avgChargePowerKw,
                            batteryAtArrival, vehicleRangeKm, batteryPercent,
                            basePriceVnd, trustScore);

                    estimatedChargeMinutes = totalPowerKw > 0
                            ? (int) Math.min(Math.ceil((Math.min(100, batteryAtArrival + 50) - batteryAtArrival) / 100.0 * vehicleRangeKm / Math.max(totalPowerKw, 1) * 60.0), 120)
                            : 30;

                    recommendationReason = buildRecommendationReason(
                            serviceType, distanceFromRouteMeters, totalPowerKw, availablePorts,
                            availableBatteries, avgChargePowerKw, basePriceVnd,
                            SWAP_SERVICE_TIME_MINUTES, estimatedChargeMinutes, batteryAtArrival);
                    filterReason = "INCLUDED";
                }
            } else {
                // No EV params — fallback to basic scoring
                batteryAtArrival = 0;
                estimatedChargeMinutes = totalPowerKw > 0 ? 30 : 20;
                waitTimeMinutes = availablePorts == 0 ? 10 : 0;
                score = computeUnifiedScoreNoEv(
                        serviceType, detourMeters, totalPowerKw, availablePorts,
                        totalBatteries, availableBatteries, basePriceVnd, trustScore);
                estimatedChargeMinutes = totalPowerKw > 0 ? 30 : 20;
                recommendationReason = buildFallbackRecommendationReason(
                        serviceType, distanceFromRouteMeters, totalPowerKw, availablePorts,
                        availableBatteries, avgChargePowerKw, basePriceVnd);
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
                    .serviceType(serviceType)
                    .availableBatteries(availableBatteries > 0 ? availableBatteries : null)
                    .totalBatteries(totalBatteries > 0 ? totalBatteries : null)
                    .avgChargePowerKw(avgChargePowerKw > 0 ? BigDecimal.valueOf(avgChargePowerKw) : null)
                    .basePriceVnd(basePriceVnd > 0 ? basePriceVnd : null)
                    .estimatedSwapMinutes(SWAP_SERVICE_TIME_MINUTES)
                    .build());
        }

        stations.sort(Comparator.comparingDouble(RecommendedStationDTO::getScore));

        log.info("[REPO] findStationsAlongRoute EXIT | "
                        + "totalScored={} sortedCount={} "
                        + "unreachableCount={} includedCount={} "
                        + "chargingCount={} swapCount={} bothCount={} "
                        + "traceId={}",
                stations.size(), stations.size(),
                stations.stream().filter(s -> s.getScore() >= 50_000).count(),
                stations.stream().filter(s -> s.getScore() < 50_000).count(),
                stations.stream().filter(s -> s.getServiceType() == RecommendedStationDTO.ServiceType.CHARGING).count(),
                stations.stream().filter(s -> s.getServiceType() == RecommendedStationDTO.ServiceType.BATTERY_SWAP).count(),
                stations.stream().filter(s -> s.getServiceType() == RecommendedStationDTO.ServiceType.BOTH).count(),
                traceId);
        return stations;
    }

    @Override
    public long countTotalPublishedStations() {
        try {
            String sql = "SELECT COUNT(*) FROM station_version WHERE workflow_status = 'PUBLISHED'";
            Query query = entityManager.createNativeQuery(sql);
            return ((Number) query.getSingleResult()).longValue();
        } catch (Exception e) {
            log.warn("[REPO] countTotalPublishedStations failed: {}", e.getMessage());
            return 0;
        }
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
    /**
     * Unified scoring for stations with EV params.
     * Lower score = better.
     */
    private double computeUnifiedScore(
            RecommendedStationDTO.ServiceType serviceType,
            double detourMeters,
            double totalPowerKw,
            int availablePorts,
            int totalBatteries,
            int availableBatteries,
            double avgChargePowerKw,
            double batteryAtArrival,
            double vehicleRangeKm,
            int batteryPercent,
            long basePriceVnd,
            int trustScore) {

        if (serviceType == RecommendedStationDTO.ServiceType.BATTERY_SWAP) {
            if (availableBatteries <= 0) {
                return SWAP_PENALTY_NO_BATTERY;
            }
            return detourMeters * WEIGHT_SWAP_DETOUR
                    + availableBatteries * WEIGHT_SWAP_AVAILABLE_BATTERIES
                    + basePriceVnd * WEIGHT_SWAP_PRICE;
        }

        if (serviceType == RecommendedStationDTO.ServiceType.BOTH) {
            double swapScore = availableBatteries <= 0 ? SWAP_PENALTY_NO_BATTERY
                    : detourMeters * WEIGHT_SWAP_DETOUR
                    + availableBatteries * WEIGHT_SWAP_AVAILABLE_BATTERIES
                    + basePriceVnd * WEIGHT_SWAP_PRICE;

            int chargeMinutes = totalPowerKw > 0
                    ? (int) Math.min(Math.ceil((Math.min(100, batteryAtArrival + 50) - batteryAtArrival) / 100.0 * vehicleRangeKm / Math.max(totalPowerKw, 1) * 60.0), 120)
                    : 30;
            double chargeScore = detourMeters * WEIGHT_DETOUR
                    + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                    + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                    + (availablePorts == 0 ? 10 : 0) * WEIGHT_WAIT_TIME
                    + chargeMinutes * WEIGHT_CHARGE_TIME;
            return Math.min(swapScore, chargeScore);
        }

        int chargeMinutes = totalPowerKw > 0
                ? (int) Math.min(Math.ceil((Math.min(100, batteryAtArrival + 50) - batteryAtArrival) / 100.0 * vehicleRangeKm / Math.max(totalPowerKw, 1) * 60.0), 120)
                : 30;
        return detourMeters * WEIGHT_DETOUR
                + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                + (availablePorts == 0 ? 10 : 0) * WEIGHT_WAIT_TIME
                + chargeMinutes * WEIGHT_CHARGE_TIME;
    }

    /**
     * Unified scoring without EV params (fallback).
     */
    private double computeUnifiedScoreNoEv(
            RecommendedStationDTO.ServiceType serviceType,
            double detourMeters,
            double totalPowerKw,
            int availablePorts,
            int totalBatteries,
            int availableBatteries,
            long basePriceVnd,
            int trustScore) {

        if (serviceType == RecommendedStationDTO.ServiceType.BATTERY_SWAP) {
            if (availableBatteries <= 0) {
                return SWAP_PENALTY_NO_BATTERY;
            }
            return detourMeters * WEIGHT_SWAP_DETOUR
                    + availableBatteries * WEIGHT_SWAP_AVAILABLE_BATTERIES
                    + basePriceVnd * WEIGHT_SWAP_PRICE;
        }

        if (serviceType == RecommendedStationDTO.ServiceType.BOTH) {
            double swapScore = availableBatteries <= 0 ? SWAP_PENALTY_NO_BATTERY
                    : detourMeters * WEIGHT_SWAP_DETOUR
                    + availableBatteries * WEIGHT_SWAP_AVAILABLE_BATTERIES
                    + basePriceVnd * WEIGHT_SWAP_PRICE;
            double chargeScore = detourMeters * WEIGHT_DETOUR
                    + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                    + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                    + 30 * WEIGHT_CHARGE_TIME;
            return Math.min(swapScore, chargeScore);
        }

        return detourMeters * WEIGHT_DETOUR
                + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                + 30 * WEIGHT_CHARGE_TIME;
    }

    /**
     * Builds a human-readable recommendation reason for both charging and swap stations.
     */
    private String buildRecommendationReason(
            RecommendedStationDTO.ServiceType serviceType,
            double distanceFromRouteMeters,
            double totalPowerKw,
            int availablePorts,
            int availableBatteries,
            double avgChargePowerKw,
            long basePriceVnd,
            int estimatedSwapMinutes,
            int estimatedChargeMinutes,
            double batteryAtArrival) {

        String proximity = distanceFromRouteMeters <= 200 ? "Right on route"
                : distanceFromRouteMeters <= 1000 ? "Slightly off route"
                : "Off route (" + String.format("%.1f km", distanceFromRouteMeters / 1000.0) + ")";

        StringBuilder sb = new StringBuilder(proximity);

        if (serviceType == RecommendedStationDTO.ServiceType.BATTERY_SWAP) {
            if (avgChargePowerKw > 0) {
                sb.append(" • avg ").append(String.format("%.1f", avgChargePowerKw)).append(" kW");
            }
            if (availableBatteries > 0) {
                sb.append(" • ").append(availableBatteries).append(" batteries");
            } else {
                sb.append(" • no batteries available");
            }
            sb.append(" • ~").append(estimatedSwapMinutes).append(" min swap");
        } else if (serviceType == RecommendedStationDTO.ServiceType.BOTH) {
            if (totalPowerKw > 0) {
                sb.append(" • ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(" • ").append(availablePorts).append(" ports");
            }
            if (availableBatteries > 0) {
                sb.append(" • ").append(availableBatteries).append(" swap batteries");
            }
            if (estimatedChargeMinutes > 0) {
                sb.append(" • ~").append(estimatedChargeMinutes).append(" min");
            }
        } else {
            if (totalPowerKw > 0) {
                sb.append(" • ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(" • ").append(availablePorts).append(" ports available");
            } else {
                sb.append(" • no available ports");
            }
            if (estimatedChargeMinutes > 0) {
                sb.append(" • ~").append(estimatedChargeMinutes).append(" min charge");
            }
        }

        sb.append(" • ~").append(String.format("%.0f", batteryAtArrival)).append("% at arrival");
        return sb.toString();
    }

    private String buildFallbackRecommendationReason(
            RecommendedStationDTO.ServiceType serviceType,
            double distanceFromRouteMeters,
            double totalPowerKw,
            int availablePorts,
            int availableBatteries,
            double avgChargePowerKw,
            long basePriceVnd) {

        String proximity = distanceFromRouteMeters <= 200 ? "Right on route"
                : distanceFromRouteMeters <= 1000 ? "Slightly off route"
                : "Off route (" + String.format("%.1f km", distanceFromRouteMeters / 1000.0) + ")";

        StringBuilder sb = new StringBuilder(proximity);

        if (serviceType == RecommendedStationDTO.ServiceType.BATTERY_SWAP) {
            if (avgChargePowerKw > 0) {
                sb.append(" • avg ").append(String.format("%.1f", avgChargePowerKw)).append(" kW");
            }
            if (availableBatteries > 0) {
                sb.append(" • ").append(availableBatteries).append(" batteries available");
            } else {
                sb.append(" • no batteries available");
            }
        } else {
            if (totalPowerKw > 0) {
                sb.append(" • ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(" • ").append(availablePorts).append(" ports available");
            } else {
                sb.append(" • no available ports");
            }
        }
        return sb.toString();
    }
}

