package com.example.evstation.api.ev_user_mobile.service;

import com.example.evstation.api.ev_user_mobile.dto.*;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.application.port.StationQueryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientRequestException;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class RoutingService {

    private final WebClient webClient;
    private final StationQueryRepository stationQueryRepository;

    private static final int MAX_RETRIES = 1;
    private static final int MIN_POLYLINE_POINTS = 2;

    @Value("${app.routing.default-station-limit:3}")
    private int defaultStationLimit;

    @Value("${app.routing.corridor-buffer-meters:1000}")
    private double corridorBufferMeters;

    @Value("${app.routing.safety-buffer-percent:5}")
    private double safetyBufferPercent;

    @Value("${app.routing.default-consumption-kwh-per-km:0.18}")
    private double defaultConsumptionKwhPerKm;

    @Value("${app.routing.default-vehicle-max-charge-kw:120.0}")
    private double defaultMaxChargeKw;

    @Value("${app.routing.default-target-percent:80}")
    private double defaultTargetPercent;

    @Value("${app.routing.default-average-speed-kmph:30.0}")
    private double defaultAverageSpeedKmph;

    @Value("${app.routing.min-battery-percent-at-arrival:10}")
    private double minBatteryPercentAtArrival;

    @Value("${app.routing.diagnostic-logging-enabled:true}")
    private boolean diagnosticLoggingEnabled;

    /**
     * Main entry point for route calculation.
     * All route logic is handled server-side; Flutter only renders.
     *
     * Recommendation logic:
     * 1. If remaining range WITH safety buffer covers the full route distance → no recommendation needed.
     * 2. Otherwise → return up to 3 reachable stations sorted by score (ascending).
     * 3. The #1 station is marked optimal (isOptimalStop=true), all top 3 are marked isRecommended=true.
     */
    public RouteResponseDTO calculateRoute(RouteRequestDTO request) {
        String traceId = UUID.randomUUID().toString().substring(0, 8);
        MDC.put("traceId", traceId);

        try {
            log.info("ROUTE_REQUEST_STARTED | origin=({},{}) destination=({},{}) "
                    + "batteryPercent={} vehicleRangeKm={} traceId={}",
                    request.getOrigin().getLat(), request.getOrigin().getLng(),
                    request.getDestination().getLat(), request.getDestination().getLng(),
                    request.getBatteryPercent(), request.getVehicleRangeKm(), traceId);

            double originLat = request.getOrigin().getLat();
            double originLng = request.getOrigin().getLng();
            double destLat = request.getDestination().getLat();
            double destLng = request.getDestination().getLng();

            validateCoordinates(originLat, originLng, destLat, destLng);

            OsrmRouteResponse osrmResponse = callOsrmWithRetry(
                    originLng, originLat, destLng, destLat, traceId);

            List<PolylinePoint> polyline = extractPolyline(osrmResponse);
            validatePolyline(polyline, traceId);

            log.info("OSRM_RESPONSE | distanceM={} durationS={} points={} traceId={}",
                    osrmResponse.distanceMeters(), osrmResponse.durationSeconds(),
                    polyline.size(), traceId);

            double routeDistanceKm = osrmResponse.distanceMeters() / 1000.0;

            EVRangeInfo evRangeInfo = calculateEVRange(
                    request.getBatteryPercent(),
                    request.getVehicleRangeKm(),
                    routeDistanceKm,
                    traceId);

            int stationLimit = request.getStationLimit() != null
                    ? request.getStationLimit() : defaultStationLimit;

            String routeWkt = convertPolylineToWkt(polyline);

            List<RecommendedStationDTO> allCandidates = findStationsAlongRoute(
                    routeWkt, polyline,
                    request.getMinPowerKw(), stationLimit,
                    request.getBatteryPercent(),
                    request.getVehicleRangeKm(),
                    routeDistanceKm,
                    evRangeInfo,
                    traceId);

            // Top 3 recommendations (already sorted by score ascending from repository)
            int topN = Math.min(3, allCandidates.size());
            List<RecommendedStationDTO> topRecommendations = allCandidates.stream()
                    .limit(topN)
                    .collect(Collectors.toList());

            // Mark recommendation flags
            for (int i = 0; i < topRecommendations.size(); i++) {
                RecommendedStationDTO s = topRecommendations.get(i);
                s.setIsRecommended(true);
                if (i == 0) {
                    s.setIsOptimalStop(true);
                }
            }

            // Primary recommendation = top of the list (if any)
            RecommendedStationDTO primaryRecommendation = topRecommendations.isEmpty()
                    ? null : topRecommendations.get(0);

            boolean needsRecommendation = evRangeInfo.needsChargingStop();

            String primaryReason = primaryRecommendation != null
                    ? primaryRecommendation.getRecommendationReason()
                    : null;

            log.info("ROUTE_CREATED | distanceM={} durationS={} totalCandidates={} "
                            + "topRecommendations={} needsRecommendation={} "
                            + "primaryStation={} traceId={}",
                    osrmResponse.distanceMeters(),
                    osrmResponse.durationSeconds(),
                    allCandidates.size(),
                    topRecommendations.size(),
                    needsRecommendation,
                    primaryRecommendation != null ? primaryRecommendation.getName() : "none",
                    traceId);

            return RouteResponseDTO.builder()
                    .distanceMeters(osrmResponse.distanceMeters())
                    .durationSeconds(osrmResponse.durationSeconds())
                    .polyline(polyline)
                    .boundingBox(buildBoundingBox(polyline))
                    .recommendedStations(topRecommendations)
                    .optimalStation(primaryRecommendation)
                    .needsChargingStop(needsRecommendation)
                    .remainingRangeKm(evRangeInfo.remainingRangeKm())
                    .routeDistanceKm(routeDistanceKm)
                    .summary(RouteSummaryDTO.builder()
                            .distanceKm(routeDistanceKm)
                            .durationMinutes((int) Math.ceil(osrmResponse.durationSeconds() / 60.0))
                            .viaRoad(true)
                            .hasChargingStations(!topRecommendations.isEmpty())
                            .needsChargingRecommendation(needsRecommendation)
                            .primaryRecommendationReason(primaryReason)
                            .build())
                    .build();

        } catch (BusinessException e) {
            log.error("ROUTE_FAILED | code={} message={} traceId={}",
                    e.getErrorCode(), e.getMessage(), MDC.get("traceId"));
            throw e;
        } catch (Exception e) {
            log.error("ROUTE_FAILED | message={} traceId={}",
                    e.getMessage(), MDC.get("traceId"), e);
            throw new BusinessException(ErrorCode.INTERNAL_ERROR,
                    "Route calculation failed: " + e.getMessage());
        } finally {
            MDC.remove("traceId");
        }
    }

    // -------------------------------------------------------------------------
    // OSRM with retry
    // -------------------------------------------------------------------------

    private OsrmRouteResponse callOsrmWithRetry(
            double originLng, double originLat,
            double destLng, double destLat,
            String traceId) {

        Exception lastException = null;

        for (int attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            try {
                log.debug("OSRM_REQUEST | attempt={} url=/route/v1/driving/{},{};{},{} traceId={}",
                        attempt + 1, originLng, originLat, destLng, destLat, traceId);
                return callOsrm(originLng, originLat, destLng, destLat, traceId);
            } catch (BusinessException e) {
                // Non-retryable errors (invalid input, no route)
                if (!isRetryable(e)) {
                    throw e;
                }
                lastException = e;
                log.warn("OSRM_REQUEST_RETRY | attempt={} reason={} traceId={}",
                        attempt + 1, e.getMessage(), traceId);
            } catch (Exception e) {
                lastException = e;
                if (attempt < MAX_RETRIES) {
                    log.warn("OSRM_REQUEST_RETRY | attempt={} reason={} traceId={}",
                            attempt + 1, e.getMessage(), traceId);
                }
            }
        }

        log.error("OSRM_REQUEST_FAILED | after {} attempts traceId={}",
                MAX_RETRIES + 1, traceId);
        throw new BusinessException(ErrorCode.INTERNAL_ERROR,
                "OSRM service unavailable after " + (MAX_RETRIES + 1) + " attempts");
    }

    private boolean isRetryable(BusinessException e) {
        return e.getErrorCode() == ErrorCode.INTERNAL_ERROR
                || e.getErrorCode() == ErrorCode.SERVICE_UNAVAILABLE;
    }

    private OsrmRouteResponse callOsrm(
            double originLng, double originLat,
            double destLng, double destLat,
            String traceId) {

        String url = String.format(
                "/route/v1/driving/%f,%f;%f,%f?overview=full&geometries=geojson",
                originLng, originLat, destLng, destLat);

        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> response = webClient.get()
                    .uri(url)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block();

            if (response == null) {
                throw new BusinessException(ErrorCode.INTERNAL_ERROR, "Empty response from OSRM");
            }

            return parseOsrmResponse(response, traceId);

        } catch (WebClientResponseException e) {
            log.error("OSRM_HTTP_ERROR | status={} traceId={}",
                    e.getStatusCode(), traceId);
            throw new BusinessException(ErrorCode.INTERNAL_ERROR,
                    "OSRM returned " + e.getStatusCode());
        } catch (WebClientRequestException e) {
            log.error("OSRM_CONNECTION_ERROR | traceId={}", traceId);
            throw new BusinessException(ErrorCode.SERVICE_UNAVAILABLE,
                    "Cannot connect to OSRM");
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("OSRM_ERROR | message={} traceId={}", e.getMessage(), traceId);
            throw new BusinessException(ErrorCode.INTERNAL_ERROR,
                    "OSRM request failed: " + e.getMessage());
        }
    }

    @SuppressWarnings("unchecked")
    private OsrmRouteResponse parseOsrmResponse(Map<String, Object> response, String traceId) {
        String code = (String) response.get("code");
        if (!"Ok".equals(code)) {
            String message = (String) response.getOrDefault("message", "Unknown OSRM error");
            log.warn("OSRM_CODE_ERROR | code={} message={} traceId={}",
                    code, message, traceId);
            throw new BusinessException(ErrorCode.ROUTE_NOT_FOUND,
                    "OSRM: " + message + " (code: " + code + ")");
        }

        List<Map<String, Object>> routes = (List<Map<String, Object>>) response.get("routes");
        if (routes == null || routes.isEmpty()) {
            throw new BusinessException(ErrorCode.INVALID_INPUT, "No route found by OSRM");
        }

        Map<String, Object> route = routes.get(0);
        long distanceMeters = ((Number) route.get("distance")).longValue();
        long durationSeconds = ((Number) route.get("duration")).longValue();

        Map<String, Object> geometry = (Map<String, Object>) route.get("geometry");
        if (geometry == null) {
            throw new BusinessException(ErrorCode.INVALID_INPUT,
                    "OSRM returned route without geometry");
        }

        @SuppressWarnings("unchecked")
        List<List<Double>> coordinates = (List<List<Double>>) geometry.get("coordinates");

        if (coordinates == null || coordinates.isEmpty()) {
            throw new BusinessException(ErrorCode.INVALID_INPUT,
                    "OSRM returned empty geometry");
        }

        return new OsrmRouteResponse(distanceMeters, durationSeconds, coordinates);
    }

    // -------------------------------------------------------------------------
    // Validation
    // -------------------------------------------------------------------------

    private void validateCoordinates(double originLat, double originLng,
                                    double destLat, double destLng) {
        if (originLat < -90 || originLat > 90) {
            log.warn("COORD_VALIDATION_FAILED | field=originLat value={} range=[-90,90]", originLat);
            throw new BusinessException(ErrorCode.INVALID_INPUT,
                    "Origin latitude out of range: " + originLat);
        }
        if (originLng < -180 || originLng > 180) {
            log.warn("COORD_VALIDATION_FAILED | field=originLng value={} range=[-180,180]", originLng);
            throw new BusinessException(ErrorCode.INVALID_INPUT,
                    "Origin longitude out of range: " + originLng);
        }
        if (destLat < -90 || destLat > 90) {
            log.warn("COORD_VALIDATION_FAILED | field=destLat value={} range=[-90,90]", destLat);
            throw new BusinessException(ErrorCode.INVALID_INPUT,
                    "Destination latitude out of range: " + destLat);
        }
        if (destLng < -180 || destLng > 180) {
            log.warn("COORD_VALIDATION_FAILED | field=destLng value={} range=[-180,180]", destLng);
            throw new BusinessException(ErrorCode.INVALID_INPUT,
                    "Destination longitude out of range: " + destLng);
        }
    }

    private void validatePolyline(List<PolylinePoint> polyline, String traceId) {
        if (polyline.size() < MIN_POLYLINE_POINTS) {
            log.error("POLYLINE_VALIDATION_FAILED | points={} traceId={}",
                    polyline.size(), traceId);
            throw new BusinessException(ErrorCode.INVALID_INPUT,
                    "Route polyline has insufficient points: " + polyline.size());
        }
    }

    // -------------------------------------------------------------------------
    // Polyline helpers
    // -------------------------------------------------------------------------

    private List<PolylinePoint> extractPolyline(OsrmRouteResponse osrmResponse) {
        return osrmResponse.coordinates().stream()
                .map(coord -> PolylinePoint.builder()
                        .lng(coord.get(0))
                        .lat(coord.get(1))
                        .build())
                .collect(Collectors.toList());
    }

    private String convertPolylineToWkt(List<PolylinePoint> polyline) {
        if (polyline.isEmpty()) {
            return "LINESTRING EMPTY";
        }

        StringBuilder sb = new StringBuilder("LINESTRING(");
        for (int i = 0; i < polyline.size(); i++) {
            if (i > 0) sb.append(", ");
            sb.append(polyline.get(i).getLng())
              .append(" ")
              .append(polyline.get(i).getLat());
        }
        sb.append(")");
        return sb.toString();
    }

    private RouteBoundingBoxDTO buildBoundingBox(List<PolylinePoint> polyline) {
        double minLat = Double.MAX_VALUE, maxLat = -Double.MAX_VALUE;
        double minLng = Double.MAX_VALUE, maxLng = -Double.MAX_VALUE;

        for (PolylinePoint p : polyline) {
            if (p.getLat() < minLat) minLat = p.getLat();
            if (p.getLat() > maxLat) maxLat = p.getLat();
            if (p.getLng() < minLng) minLng = p.getLng();
            if (p.getLng() > maxLng) maxLng = p.getLng();
        }

        return RouteBoundingBoxDTO.builder()
                .minLat(minLat)
                .maxLat(maxLat)
                .minLng(minLng)
                .maxLng(maxLng)
                .build();
    }

    // -------------------------------------------------------------------------
    // EV-aware routing
    // -------------------------------------------------------------------------

    private EVRangeInfo calculateEVRange(
            Integer batteryPercent,
            Double vehicleRangeKm,
            double routeDistanceKm,
            String traceId) {

        if (batteryPercent == null || vehicleRangeKm == null || vehicleRangeKm <= 0) {
            log.debug("EV_RANGE_SKIPPED | missingParams traceId={}", traceId);
            return new EVRangeInfo(false, 0.0, 0.0, false, 0.0);
        }

        double remainingRangeKm = (batteryPercent / 100.0) * vehicleRangeKm;
        double safetyBuffer = vehicleRangeKm * (safetyBufferPercent / 100.0);
        boolean needsChargingStop = remainingRangeKm < routeDistanceKm + safetyBuffer;

        log.info("EV_RANGE_CALCULATED | batteryPercent={} vehicleRangeKm={} "
                        + "remainingRangeKm={} routeDistanceKm={} safetyBuffer={} "
                        + "needsChargingStop={} traceId={}",
                batteryPercent, vehicleRangeKm, remainingRangeKm,
                routeDistanceKm, safetyBuffer, needsChargingStop, traceId);

        return new EVRangeInfo(
                needsChargingStop,
                remainingRangeKm,
                routeDistanceKm,
                true,
                vehicleRangeKm);
    }

    // -------------------------------------------------------------------------
    // Station query
    // -------------------------------------------------------------------------

    private List<RecommendedStationDTO> findStationsAlongRoute(
            String routeWkt,
            List<PolylinePoint> polyline,
            Double minPowerKw,
            int limit,
            Integer batteryPercent,
            Double vehicleRangeKm,
            Double routeDistanceKm,
            EVRangeInfo evRangeInfo,
            String traceId) {

        log.info("[STATION_SEARCH] === STATION SEARCH START === traceId={}", traceId);

        // --- PRE-STATION-SEARCH DIAGNOSTICS ---
        log.info("[STATION_SEARCH] origin | lat={} lng={} traceId={}",
                polyline.get(0).getLat(), polyline.get(0).getLng(), traceId);
        log.info("[STATION_SEARCH] destination | lat={} lng={} traceId={}",
                polyline.get(polyline.size() - 1).getLat(),
                polyline.get(polyline.size() - 1).getLng(), traceId);
        log.info("[STATION_SEARCH] route | distanceKm={} polylinePoints={} traceId={}",
                routeDistanceKm, polyline.size(), traceId);
        log.info("[STATION_SEARCH] routeWkt | length={} sample={} traceId={}",
                routeWkt.length(),
                routeWkt.length() > 200 ? routeWkt.substring(0, 200) + "..." : routeWkt,
                traceId);
        log.info("[STATION_SEARCH] firstPoint | lat={} lng={} traceId={}",
                polyline.get(0).getLat(), polyline.get(0).getLng(), traceId);
        log.info("[STATION_SEARCH] lastPoint | lat={} lng={} traceId={}",
                polyline.get(polyline.size() - 1).getLat(),
                polyline.get(polyline.size() - 1).getLng(), traceId);
        log.info("[STATION_SEARCH] buffer | corridorBufferMeters={} traceId={}",
                corridorBufferMeters, traceId);
        log.info("[STATION_SEARCH] evParams | batteryPercent={} vehicleRangeKm={} "
                        + "routeDistanceKm={} hasEvParams={} traceId={}",
                batteryPercent, vehicleRangeKm, routeDistanceKm,
                evRangeInfo.hasEvParams(), traceId);
        log.info("[STATION_SEARCH] filters | minPowerKw={} limit={} traceId={}",
                minPowerKw, limit, traceId);

        try {
            List<RecommendedStationDTO> stations = stationQueryRepository.findStationsAlongRoute(
                    routeWkt, corridorBufferMeters, minPowerKw, limit,
                    polyline, batteryPercent, vehicleRangeKm, routeDistanceKm, traceId);

            // --- POST-SPATIAL-QUERY DIAGNOSTICS ---
            log.info("[STATION_SEARCH] === STATION SEARCH END === "
                            + "rawCount={} traceId={}",
                    stations.size(), traceId);

            if (stations.isEmpty()) {
                log.warn("[STATION_SEARCH] NO_STATIONS_FOUND | "
                                + "routeDistanceKm={} corridorBufferM={} "
                                + "batteryPercent={} vehicleRangeKm={} "
                                + "hint='Check if station_version table has PUBLISHED stations "
                                + "within corridor buffer of route. "
                                + "Verify ST_DWithin query returns rows in DB directly.' "
                                + "traceId={}",
                        routeDistanceKm, corridorBufferMeters,
                        batteryPercent, vehicleRangeKm, traceId);
            } else {
                log.info("[STATION_SEARCH] stationsReturned | count={} traceId={}",
                        stations.size(), traceId);
                for (int i = 0; i < stations.size(); i++) {
                    RecommendedStationDTO s = stations.get(i);
                    log.info("[STATION_SEARCH] station[{}] | id={} name='{}' "
                                    + "distanceFromRouteM={} totalPowerKw={} "
                                    + "availablePorts={}/{} score={} traceId={}",
                            i, s.getStationId(), s.getName(),
                            s.getDistanceFromRouteMeters(), s.getTotalPowerKw(),
                            s.getAvailablePorts(), s.getTotalPorts(),
                            s.getScore(), traceId);
                }
            }

            // --- FILTERING DIAGNOSTICS ---
            if (!stations.isEmpty()) {
                int unreachableCount = 0;
                int lowPowerCount = 0;
                for (RecommendedStationDTO s : stations) {
                    if (s.getScore() >= 50_000) {
                        unreachableCount++;
                        log.debug("[STATION_SEARCH] filtered | stationId={} reason='batteryAtArrival_below_10_percent' "
                                        + "score={} traceId={}",
                                s.getStationId(), s.getScore(), traceId);
                    }
                    if (s.getTotalPowerKw() == 0) {
                        lowPowerCount++;
                        log.debug("[STATION_SEARCH] filtered | stationId={} reason='no_available_power' "
                                        + "totalPowerKw=0 traceId={}",
                                s.getStationId(), traceId);
                    }
                }
                if (unreachableCount > 0 || lowPowerCount > 0) {
                    log.info("[STATION_SEARCH] filteringSummary | "
                                    + "unreachableCount={} lowPowerCount={} finalCount={} traceId={}",
                            unreachableCount, lowPowerCount, stations.size(), traceId);
                }
            }

            log.info("[STATION_SEARCH] finalStationCount | count={} traceId={}",
                    stations.size(), traceId);
            return stations;

        } catch (Exception e) {
            log.error("[STATION_SEARCH] === STATION SEARCH FAILED === "
                            + "exceptionType={} message={} "
                            + "routeWktLength={} corridorBufferM={} traceId={}",
                    e.getClass().getSimpleName(), e.getMessage(),
                    routeWkt.length(), corridorBufferMeters, traceId, e);

            log.error("[STATION_SEARCH] FAILURE_HINTS | "
                            + "1) Verify PostGIS extension is installed: SELECT PostGIS_Version(); "
                            + "2) Verify station_version has PUBLISHED rows with valid location: "
                            + "SELECT COUNT(*) FROM station_version WHERE workflow_status='PUBLISHED'; "
                            + "3) Test ST_DWithin directly: SELECT ST_DWithin(...) "
                            + "4) Verify route WKT is valid: SELECT ST_IsValidReason(ST_GeomFromText('{}', 4326)); "
                            + "traceId={}",
                    routeWkt, traceId);
            return Collections.emptyList();
        }
    }

    // -------------------------------------------------------------------------
    // Internal records
    // -------------------------------------------------------------------------

    private record OsrmRouteResponse(
            long distanceMeters,
            long durationSeconds,
            List<List<Double>> coordinates) {
    }

    private record EVRangeInfo(
            boolean needsChargingStop,
            double remainingRangeKm,
            double routeDistanceKm,
            boolean hasEvParams,
            double vehicleRangeKm) {
    }
}
