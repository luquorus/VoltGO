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

    @Value("${app.routing.default-station-limit:10}")
    private int defaultStationLimit;

    @Value("${app.routing.corridor-buffer-meters:5000}")
    private double corridorBufferMeters;

    @Value("${app.routing.ev.safety-buffer-percent:5}")
    private double safetyBufferPercent;

    /**
     * Main entry point for route calculation.
     * All route logic is handled server-side; Flutter only renders.
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

            // Call OSRM with retry
            OsrmRouteResponse osrmResponse = callOsrmWithRetry(
                    originLng, originLat, destLng, destLat, traceId);

            // Extract and validate polyline
            List<PolylinePoint> polyline = extractPolyline(osrmResponse);
            validatePolyline(polyline, traceId);

            log.info("OSRM_RESPONSE | distanceM={} durationS={} points={} traceId={}",
                    osrmResponse.distanceMeters(), osrmResponse.durationSeconds(),
                    polyline.size(), traceId);

            double routeDistanceKm = osrmResponse.distanceMeters() / 1000.0;

            // EV-aware range calculation
            EVRangeInfo evRangeInfo = calculateEVRange(
                    request.getBatteryPercent(),
                    request.getVehicleRangeKm(),
                    routeDistanceKm,
                    traceId);

            // Find stations along route corridor
            int stationLimit = request.getStationLimit() != null
                    ? request.getStationLimit() : defaultStationLimit;

            String routeWkt = convertPolylineToWkt(polyline);

            List<RecommendedStationDTO> stationsAlongRoute = findStationsAlongRoute(
                    routeWkt, polyline,
                    request.getMinPowerKw(), stationLimit,
                    request.getBatteryPercent(),
                    request.getVehicleRangeKm(),
                    routeDistanceKm,
                    evRangeInfo,
                    traceId);

            // Select single optimal charging stop if needed
            RecommendedStationDTO optimalStation = selectOptimalStation(
                    stationsAlongRoute,
                    evRangeInfo.needsChargingStop(),
                    traceId);

            log.info("ROUTE_CREATED | distanceM={} durationS={} stations={} needsStop={} optimalStation={} traceId={}",
                    osrmResponse.distanceMeters(),
                    osrmResponse.durationSeconds(),
                    stationsAlongRoute.size(),
                    evRangeInfo.needsChargingStop(),
                    optimalStation != null ? optimalStation.getStationId() : "none",
                    traceId);

            return RouteResponseDTO.builder()
                    .distanceMeters(osrmResponse.distanceMeters())
                    .durationSeconds(osrmResponse.durationSeconds())
                    .polyline(polyline)
                    .boundingBox(buildBoundingBox(polyline))
                    .recommendedStations(stationsAlongRoute)
                    .optimalStation(optimalStation)
                    .needsChargingStop(evRangeInfo.needsChargingStop())
                    .remainingRangeKm(evRangeInfo.remainingRangeKm())
                    .routeDistanceKm(routeDistanceKm)
                    .summary(RouteSummaryDTO.builder()
                            .distanceKm(routeDistanceKm)
                            .durationMinutes((int) Math.ceil(osrmResponse.durationSeconds() / 60.0))
                            .viaRoad(true)
                            .hasChargingStations(!stationsAlongRoute.isEmpty())
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

    /**
     * Selects exactly ONE optimal station for charging stop.
     * Uses EV-aware multi-criteria scoring.
     */
    private RecommendedStationDTO selectOptimalStation(
            List<RecommendedStationDTO> stations,
            boolean needsChargingStop,
            String traceId) {

        if (!needsChargingStop || stations == null || stations.isEmpty()) {
            log.debug("OPTIMAL_STATION_SKIPPED | needsStop={} stations={} traceId={}",
                    needsChargingStop,
                    stations != null ? stations.size() : 0,
                    traceId);
            return null;
        }

        // Already sorted by score (lowest = best) from findStationsAlongRoute
        RecommendedStationDTO optimal = stations.get(0);

        log.info("OPTIMAL_STATION_SELECTED | stationId={} name={} score={} "
                        + "totalPowerKw={} availablePorts={} detourMeters={} traceId={}",
                optimal.getStationId(),
                optimal.getName(),
                optimal.getScore(),
                optimal.getTotalPowerKw(),
                optimal.getAvailablePorts(),
                optimal.getDetourMeters(),
                traceId);

        return optimal;
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

        try {
            List<RecommendedStationDTO> stations = stationQueryRepository.findStationsAlongRoute(
                    routeWkt, corridorBufferMeters, minPowerKw, limit,
                    polyline, batteryPercent, vehicleRangeKm, routeDistanceKm);

            log.debug("STATIONS_ALONG_ROUTE | count={} hasEvParams={} "
                    + "evRemainingRangeKm={} traceId={}",
                    stations.size(), evRangeInfo.hasEvParams(),
                    evRangeInfo.hasEvParams() ? evRangeInfo.remainingRangeKm() : 0,
                    traceId);
            return stations;

        } catch (Exception e) {
            log.error("STATION_QUERY_FAILED | message={} traceId={}",
                    e.getMessage(), traceId);
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
