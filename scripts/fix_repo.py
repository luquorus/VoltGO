NEW_METHOD = r'''
    // -------------------------------------------------------------------------
    // Scoring weights — CHARGING
    // -------------------------------------------------------------------------

    private static final double WEIGHT_DETOUR = 2.0;
    private static final double WEIGHT_POWER = -1.5;
    private static final double WEIGHT_AVAILABLE_PORTS = -5.0;
    private static final double WEIGHT_WAIT_TIME = 1.5;
    private static final double WEIGHT_CHARGE_TIME = 0.3;

    private static final double PENALTY_UNREACHABLE = 100_000;
    private static final double SCORE_UNREACHABLE = 50_000;

    // -------------------------------------------------------------------------
    // Scoring weights — BATTERY SWAP
    // -------------------------------------------------------------------------

    private static final double WEIGHT_SWAP_DETOUR = 2.0;
    private static final double WEIGHT_SWAP_AVAILABLE_BATTERIES = -3.0;
    private static final double WEIGHT_SWAP_PRICE = 0.01;
    private static final int SWAP_SERVICE_TIME_MINUTES = 5;
    private static final long SWAP_BASE_PRICE_VND = 5_000;

    private static final double SWAP_PENALTY_NO_BATTERY = 80_000;

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

        log.info("[REPO] findStationsAlongRoute ENTER | bufferM={} minPower={} limit={} "
                        + "hasEvParams={} batteryPercent={} vehicleRangeKm={} routeDistanceKm={} "
                        + "routeWktLength={} polylineSize={}",
                bufferMeters, minPowerKw, limit, hasEvParams, batteryPercent,
                vehicleRangeKm, routeDistanceKm,
                routeWkt.length(), polyline.size());

        if (routeWkt == null || routeWkt.isEmpty() || "LINESTRING EMPTY".equals(routeWkt)) {
            log.error("[REPO] INVALID_ROUTE_WKT | routeWkt='{}' -- empty or invalid WKT", routeWkt);
            return Collections.emptyList();
        }

        PolylinePoint firstPt = polyline.get(0);
        PolylinePoint lastPt = polyline.get(polyline.size() - 1);
        log.info("[REPO] WKT_BOUNDS | firstPoint=({},{}) lastPoint=({},{}) totalPoints={}",
                firstPt.getLat(), firstPt.getLng(),
                lastPt.getLat(), lastPt.getLng(),
                polyline.size());

        // ==========================================================================
        // QUERY: find ALL published stations within corridor buffer
        // Returns both CHARGING and BATTERY_SWAP stations
        // ==========================================================================

        String distanceFilter = minPowerKw != null
                ? " AND total_power_kw >= " + minPowerKw.doubleValue()
                : "";

        // Build swap data CTEs
        String swapCte = "";
        if (routeWkt.contains("LINESTRING")) {
            swapCte = """, station_swap_data AS (
                SELECT
                    sv.station_id,
                    COALESCE(bss.available_batteries, 0) AS available_batteries,
                    COALESCE(bss.total_batteries, 0) AS total_batteries,
                    COALESCE(bss.avg_charge_power_kw, 0) AS avg_charge_power_kw,
                    COALESCE(bp.base_price_vnd, 5000) AS base_price_vnd
                FROM station_version sv
                LEFT JOIN battery_swap_station_state bss ON bss.station_id = sv.station_id
                LEFT JOIN battery_swap_pricing bp ON bp.station_id = sv.station_id
                WHERE sv.workflow_status = 'PUBLISHED'
                  AND EXISTS (
                      SELECT 1 FROM station_service ss2
                      WHERE ss2.station_version_id = sv.id AND ss2.service_type = 'BATTERY_SWAP'
                  )
            ),""";
        }

        String baseQuery = """
            WITH route_line AS (
                SELECT ST_GeomFromText('%ROUTE_WKT%', 4326)::geography AS route_geog
            ),
            route_origin AS (
                SELECT ST_GeomFromText('POINT(%ORIGIN_LNG% %ORIGIN_LAT%)', 4326)::geography AS origin_geog
            ),
            station_data AS (
                SELECT
                    sv.station_id,
                    sv.name,
                    sv.address,
                    ST_Y(CAST(sv.location AS geometry)) as lat,
                    ST_X(CAST(sv.location AS geometry)) as lng,
                    CAST(ST_Distance(CAST(sv.location AS geography), rl.route_geog) AS DOUBLE PRECISION) AS distance_from_route_meters,
                    CAST(ST_Distance(CAST(sv.location AS geography), ro.origin_geog) AS DOUBLE PRECISION) AS distance_from_origin_meters,

                    -- CHARGING data (only from CHARGING service rows)
                    COALESCE((SELECT SUM(cp.port_count)
                        FROM station_service ss
                        JOIN charging_port cp ON ss.id = cp.station_service_id
                        WHERE ss.station_version_id = sv.id AND ss.service_type = 'CHARGING'), 0) AS total_ports,

                    COALESCE((SELECT SUM(cp.port_count)
                        FROM station_service ss
                        JOIN charging_port cp ON ss.id = cp.station_service_id
                        LEFT JOIN charging_unit cu ON cp.charging_unit_id = cu.id
                        WHERE ss.station_version_id = sv.id
                          AND ss.service_type = 'CHARGING'
                          AND (cu.id IS NULL OR cu.status = 'ACTIVE')), 0) AS available_ports,

                    COALESCE((SELECT SUM(cp.power_kw * cp.port_count)
                        FROM station_service ss
                        JOIN charging_port cp ON ss.id = cp.station_service_id
                        WHERE ss.station_version_id = sv.id
                          AND ss.service_type = 'CHARGING'
                          AND cp.power_type = 'DC'), 0) AS total_power_kw,

                    (SELECT ARRAY_AGG(DISTINCT cp.connector_type)
                        FROM station_service ss
                        JOIN charging_port cp ON ss.id = cp.station_service_id
                        WHERE ss.station_version_id = sv.id AND ss.service_type = 'CHARGING')
                        AS connector_types,

                    -- BATTERY SWAP data
                    COALESCE((SELECT SUM(ss.total_batteries)
                        FROM station_service ss
                        WHERE ss.station_version_id = sv.id AND ss.service_type = 'BATTERY_SWAP'), 0) AS total_batteries,

                    bss.available_batteries AS available_batteries,
                    bss.avg_charge_power_kw AS avg_charge_power_kw,
                    COALESCE(bp.base_price_vnd, 5000) AS base_price_vnd

                FROM station_version sv
                CROSS JOIN route_line rl
                CROSS JOIN route_origin ro
                LEFT JOIN battery_swap_station_state bss ON bss.station_id = sv.station_id
                LEFT JOIN battery_swap_pricing bp ON bp.station_id = sv.station_id
                WHERE sv.workflow_status = 'PUBLISHED'
                  AND ST_DWithin(CAST(sv.location AS geography), rl.route_geog, %BUFFER_METERS%)
                  %DISTANCE_FILTER%
            )
            SELECT
                station_id, name, address, lat, lng,
                distance_from_route_meters, distance_from_origin_meters,
                total_ports, available_ports, total_power_kw, connector_types,
                total_batteries, available_batteries, avg_charge_power_kw, base_price_vnd,
                CASE WHEN total_ports > 0 AND total_power_kw > 0 AND total_batteries > 0 THEN 'BOTH'
                     WHEN total_ports > 0 AND total_power_kw > 0 THEN 'CHARGING'
                     WHEN total_batteries > 0 THEN 'BATTERY_SWAP'
                     ELSE 'CHARGING'
                END AS service_type
            FROM station_data
            WHERE total_ports > 0 OR total_batteries > 0
            ORDER BY distance_from_route_meters ASC
            LIMIT %LIMIT%
            """;

        baseQuery = baseQuery
                .replace("%ROUTE_WKT%", routeWkt)
                .replace("%ORIGIN_LNG%", String.valueOf(firstPt.getLng()))
                .replace("%ORIGIN_LAT%", String.valueOf(firstPt.getLat()))
                .replace("%BUFFER_METERS%", String.valueOf((long) bufferMeters))
                .replace("%LIMIT%", String.valueOf(limit))
                .replace("%DISTANCE_FILTER%", distanceFilter);

        log.info("[REPO] QUERY_DUMP | sql={} traceId={}", baseQuery, traceId);

        // Count total PUBLISHED stations in DB
        try {
            String countSql = "SELECT COUNT(*) FROM station_version WHERE workflow_status = 'PUBLISHED'";
            Query countCheck = entityManager.createNativeQuery(countSql);
            Long totalPublished = ((Number) countCheck.getSingleResult()).longValue();
            log.info("[REPO] PUBLISHED_STATIONS_IN_DB | totalCount={} traceId={}", totalPublished, traceId);
        } catch (Exception e) {
            log.warn("[REPO] COUNT_CHECK_FAILED | message={} traceId={}", e.getMessage(), traceId);
        }

        Query nativeQuery = entityManager.createNativeQuery(baseQuery);

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        log.info("[REPO] POSTGIS_QUERY_RESULT | rawRowsReturned={} limit={} traceId={}",
                results.size(), limit, traceId);

        if (results.isEmpty()) {
            log.warn("[REPO] NO_STATIONS_IN_CORRIDOR | bufferMeters={} routeWktLength={} traceId={}",
                    bufferMeters, routeWkt.length(), traceId);
        }

        // Batch-fetch trust scores
        List<UUID> stationIds = results.stream()
                .map(row -> (UUID) row[0])
                .collect(Collectors.toList());
        Map<UUID, Integer> trustScoreMap = stationIds.isEmpty()
                ? Collections.emptyMap()
                : trustRepository.findAllById(stationIds).stream()
                        .collect(Collectors.toMap(
                                StationTrustEntity::getStationId,
                                StationTrustEntity::getScore));

        // ==========================================================================
        // SCORING: unified scoring for both CHARGING and BATTERY_SWAP
        // ==========================================================================

        List<RecommendedStationDTO> stations = new ArrayList<>();
        for (Object[] row : results) {
            UUID stationId = (UUID) row[0];
            String name = (String) row[1];
            String address = (String) row[2];
            double lat = ((Number) row[3]).doubleValue();
            double lng = ((Number) row[4]).doubleValue();
            double distanceFromRouteMeters = ((Number) row[5]).doubleValue();
            double distanceFromOriginMeters = ((Number) row[6]).doubleValue();
            int totalPorts = row[7] != null ? ((Number) row[7]).intValue() : 0;
            int availablePorts = row[8] != null ? ((Number) row[8]).intValue() : 0;
            double totalPowerKw = row[9] != null ? ((Number) row[9]).doubleValue() : 0;

            // Swap data
            int totalBatteries = row[11] != null ? ((Number) row[11]).intValue() : 0;
            int availableBatteries = row[12] != null ? ((Number) row[12]).intValue() : 0;
            double avgChargePowerKw = row[13] != null ? ((Number) row[13]).doubleValue() : 0;
            long basePriceVnd = row[14] != null ? ((Number) row[14]).longValue() : SWAP_BASE_PRICE_VND;

            String serviceTypeStr = (String) row[15];
            RecommendedStationDTO.ServiceType serviceType;
            if ("BOTH".equals(serviceTypeStr)) {
                serviceType = RecommendedStationDTO.ServiceType.BOTH;
            } else if ("BATTERY_SWAP".equals(serviceTypeStr)) {
                serviceType = RecommendedStationDTO.ServiceType.BATTERY_SWAP;
            } else {
                serviceType = RecommendedStationDTO.ServiceType.CHARGING;
            }

            List<String> connectorTypes = parseConnectorTypes(row[10]);
            Integer trustScore = trustScoreMap.getOrDefault(stationId, 50);

            double detourMeters = distanceFromRouteMeters * 2;
            double avgSpeedMps = 30.0 / 3.6;
            int estimatedArrivalMinutes = (int) Math.ceil(distanceFromOriginMeters / avgSpeedMps / 60.0);

            double batteryAtArrival = 0;
            double score;
            int estimatedChargeMinutes;
            int estimatedSwapMinutes = SWAP_SERVICE_TIME_MINUTES;
            String recommendationReason;

            if (hasEvParams && vehicleRangeKm > 0) {
                double distanceToStationKm = distanceFromOriginMeters / 1000.0;
                double energyUsedKwh = distanceToStationKm * 0.18;
                double batteryUsedPercent = (energyUsedKwh / vehicleRangeKm) * 100.0;
                batteryAtArrival = Math.max(0, batteryPercent - batteryUsedPercent);

                if (batteryAtArrival < 10) {
                    score = SCORE_UNREACHABLE;
                    estimatedChargeMinutes = 0;
                    recommendationReason = "Cannot reach safely -- not enough battery";
                    log.info("[REPO] stationUnreachable | id={} batteryAtArrival={} distanceFromOriginM={} traceId={}",
                            stationId, batteryAtArrival, distanceFromOriginMeters, traceId);
                } else {
                    score = computeUnifiedScore(
                            serviceType, detourMeters, totalPowerKw, availablePorts,
                            totalBatteries, availableBatteries, avgChargePowerKw,
                            batteryAtArrival, vehicleRangeKm, batteryPercent,
                            basePriceVnd, trustScore);
                    estimatedChargeMinutes = totalPowerKw > 0
                            ? (int) Math.min(Math.ceil((100.0 - batteryAtArrival) / 100.0 * vehicleRangeKm / Math.max(totalPowerKw, 1) * 60.0), 120)
                            : 30;
                    recommendationReason = buildRecommendationReason(
                            serviceType, distanceFromRouteMeters, totalPowerKw, availablePorts,
                            availableBatteries, avgChargePowerKw, basePriceVnd,
                            estimatedSwapMinutes, estimatedChargeMinutes, batteryAtArrival);
                }
            } else {
                score = computeUnifiedScoreNoEv(
                        serviceType, detourMeters, totalPowerKw, availablePorts,
                        totalBatteries, availableBatteries, basePriceVnd, trustScore);
                estimatedChargeMinutes = totalPowerKw > 0 ? 30 : 20;
                recommendationReason = buildFallbackRecommendationReason(
                        serviceType, distanceFromRouteMeters, totalPowerKw, availablePorts,
                        availableBatteries, avgChargePowerKw, basePriceVnd);
            }

            log.info("[REPO] stationScored | id={} name='{}' serviceType={} score={} "
                            + "distanceFromRouteM={} batteryAtArrival={} "
                            + "availablePorts={} availableBatteries={} traceId={}",
                    stationId,
                    name.length() > 40 ? name.substring(0, 40) : name,
                    serviceType, score, distanceFromRouteMeters, batteryAtArrival,
                    availablePorts, availableBatteries, traceId);

            int optimalStopMinutes = estimatedArrivalMinutes + estimatedChargeMinutes;
            double remainingRangeAfterStopKm = hasEvParams
                    ? Math.min(100, batteryAtArrival + 50) / 100.0 * vehicleRangeKm
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
                    .rating(trustScore / 20.0)
                    .estimatedArrivalMinutes(estimatedArrivalMinutes)
                    .waitTimeMinutes(availablePorts == 0 ? 10 : 0)
                    .estimatedChargeMinutes(estimatedChargeMinutes)
                    .optimalChargingStopMinutes((double) optimalStopMinutes)
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
                    .estimatedSwapMinutes(estimatedSwapMinutes)
                    .build());
        }

        stations.sort(Comparator.comparingDouble(RecommendedStationDTO::getScore));

        log.info("[REPO] findStationsAlongRoute EXIT | totalScored={} unreachableCount={} "
                        + "chargingCount={} swapCount={} bothCount={} traceId={}",
                stations.size(),
                stations.stream().filter(s -> s.getScore() >= SCORE_UNREACHABLE).count(),
                stations.stream().filter(s -> s.getServiceType() == RecommendedStationDTO.ServiceType.CHARGING).count(),
                stations.stream().filter(s -> s.getServiceType() == RecommendedStationDTO.ServiceType.BATTERY_SWAP).count(),
                stations.stream().filter(s -> s.getServiceType() == RecommendedStationDTO.ServiceType.BOTH).count(),
                traceId);

        return stations;
    }

    /**
     * Unified scoring for stations with EV params.
     * Lower score = better. Considers both charging and swap options.
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
                    ? (int) Math.min(Math.ceil((100.0 - batteryAtArrival) / 100.0 * vehicleRangeKm / Math.max(totalPowerKw, 1) * 60.0), 120)
                    : 30;
            double chargeScore = detourMeters * WEIGHT_DETOUR
                    + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                    + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                    + (availablePorts == 0 ? 10 : 0) * WEIGHT_WAIT_TIME
                    + chargeMinutes * WEIGHT_CHARGE_TIME;
            return Math.min(swapScore, chargeScore);
        }

        // CHARGING
        int chargeMinutes = totalPowerKw > 0
                ? (int) Math.min(Math.ceil((100.0 - batteryAtArrival) / 100.0 * vehicleRangeKm / Math.max(totalPowerKw, 1) * 60.0), 120)
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

        // CHARGING
        return detourMeters * WEIGHT_DETOUR
                + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                + 30 * WEIGHT_CHARGE_TIME;
    }
'''

path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find start of method
method_start = content.find('    @Override\n    public List<RecommendedStationDTO> findStationsAlongRoute(')
if method_start == -1:
    print('ERROR: Method start NOT found')
    exit(1)

# Find end of method
brace_count = 0
method_started = False
end_pos = method_start
for i in range(method_start, len(content)):
    if content[i] == '{':
        brace_count += 1
        method_started = True
    elif content[i] == '}':
        brace_count -= 1
        if method_started and brace_count == 0:
            end_pos = i + 1
            break

old_method = content[method_start:end_pos]
print(f'Old method: {len(old_method)} chars ({method_start} to {end_pos})')

# Find the "// -------------------------------------------------------------------------" comment block right before the method
# The scoring constants are just above the @Override
constants_start = content.rfind('    // -------------------------------------------------------------------------\n    // Scoring weights', 0, method_start)
if constants_start == -1:
    print('ERROR: Scoring constants not found before method')
    exit(1)

print(f'Constants start: {constants_start}')

# Build new content: everything before constants + NEW_METHOD
new_content = content[:constants_start] + NEW_METHOD + '\n'

# Also need to add new helper methods after the old ones
# The old helper methods (parseConnectorTypes, buildRecommendationReason, buildFallbackRecommendationReason)
# need to be replaced with new versions that handle swap
# But for now, let's just keep them and add the new ones

# Actually, let's find where buildFallbackRecommendationReason ends and add the new methods there
helper_end = content.find('\n}\n', end_pos)
if helper_end == -1:
    print('WARNING: Could not find end of file cleanly')
    helper_end = len(content)

# The new helper methods need to replace the old ones
# Old helpers: parseConnectorTypes (lines 770-780), buildRecommendationReason (lines 782-841), buildFallbackRecommendationReason (lines 843-857)

# Find old helper methods
parse_start = content.find('\n    private List<String> parseConnectorTypes(Object obj)', end_pos)
reason_start = content.find('\n    /**\n     * Builds a human-readable recommendation reason', end_pos)
fallback_start = content.find('\n    private String buildFallbackRecommendationReason', end_pos)

print(f'parseConnectorTypes at: {parse_start}')
print(f'buildRecommendationReason at: {reason_start}')
print(f'buildFallbackRecommendationReason at: {fallback_start}')

if parse_start != -1 and reason_start != -1:
    old_helpers = content[parse_start:helper_end]
    print(f'Old helpers: {len(old_helpers)} chars')
else:
    old_helpers = ''
    print('Old helpers not found, appending to end')

NEW_HELPERS = '''
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
                : distanceFromRouteMeters <= 500 ? "Very close to route"
                : "Near route";

        if (serviceType == RecommendedStationDTO.ServiceType.BATTERY_SWAP) {
            String price = basePriceVnd > 0 ? String.format(" %,d VND", basePriceVnd) : "";
            String batteries = availableBatteries >= 3 ? " -- Many batteries ready"
                    : availableBatteries == 1 ? " -- Only 1 battery left"
                    : "";
            return String.format("%s -- Battery swap%s -- ~%d min service%s -- Battery ~%.0f%% at arrival",
                    proximity, price, estimatedSwapMinutes, batteries, batteryAtArrival);
        }

        if (serviceType == RecommendedStationDTO.ServiceType.BOTH) {
            String chargeInfo = totalPowerKw >= 150 ? String.format(" -- Fast %,.0fkW", totalPowerKw)
                    : totalPowerKw >= 50 ? String.format(" -- %,.0fkW", totalPowerKw) : " -- Slow charging";
            String portInfo = availablePorts >= 3 ? " -- Many ports free"
                    : availablePorts == 0 ? " -- May wait" : String.format(" -- %d ports free", availablePorts);
            String price = basePriceVnd > 0 ? String.format(" -- Swap ~%,d VND", basePriceVnd) : "";
            return String.format("%s%s%s%s -- Charge ~%d min -- Battery ~%.0f%% at arrival",
                    proximity, chargeInfo, portInfo, price, estimatedChargeMinutes, batteryAtArrival);
        }

        // CHARGING
        String chargeInfo = totalPowerKw >= 150 ? String.format(" -- Fast %.0fkW", totalPowerKw)
                : totalPowerKw >= 50 ? String.format(" -- %.0fkW", totalPowerKw) : "";
        String portInfo = availablePorts >= 3 ? " -- Many ports free"
                : availablePorts == 0 ? " -- May wait" : String.format(" -- %d ports free", availablePorts);
        return String.format("%s%s%s -- Charge ~%d min -- Battery ~%.0f%% at arrival",
                proximity, chargeInfo, portInfo, estimatedChargeMinutes, batteryAtArrival);
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
                : distanceFromRouteMeters <= 500 ? "Very close to route"
                : "Near route";

        if (serviceType == RecommendedStationDTO.ServiceType.BATTERY_SWAP) {
            String price = basePriceVnd > 0 ? String.format(" -- ~%,d VND", basePriceVnd) : "";
            return String.format("%s -- Battery swap available%s -- %d batteries free",
                    proximity, price, availableBatteries);
        }

        if (serviceType == RecommendedStationDTO.ServiceType.BOTH) {
            String price = basePriceVnd > 0 ? String.format(" -- Swap ~%,d VND", basePriceVnd) : "";
            return String.format("%s -- Charging + Swap available%s -- %d ports, %d batteries",
                    proximity, price, availablePorts, availableBatteries);
        }

        // CHARGING
        String power = totalPowerKw >= 50 ? String.format(" -- %.0fkW", totalPowerKw) : "";
        String ports = availablePorts >= 2 ? String.format(" -- %d ports free", availablePorts) : "";
        return proximity + power + ports;
    }
}
'''

# Build final content
final_content = content[:constants_start] + NEW_METHOD + NEW_HELPERS

with open(path, 'w', encoding='utf-8') as f:
    f.write(final_content)

print(f'Written {len(final_content)} chars')
print('DONE')
