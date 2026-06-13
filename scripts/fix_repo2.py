import re

path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'r', encoding='utf-8', newline='') as f:
    content = f.read()

# Convert CRLF to LF for Java text block compatibility

# Convert CRLF to LF for Java text block compatibility
content = content.replace('\r\n', '\n')

# ==========================================================================
# FIX 1: Remove LEFT JOIN charging_unit from available_ports subquery
# ==========================================================================
old_available_ports = (
    "+ \" COALESCE((SELECT SUM(cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id LEFT JOIN charging_unit cu ON cp.charging_unit_id = cu.id WHERE ss.station_version_id = sv.id AND cu.status = 'ACTIVE'), 0) AS available_ports,\""
)
new_available_ports = (
    "+ \" COALESCE((SELECT SUM(cp.port_count) FROM station_service ss JOIN charging_port cp ON ss.id = cp.station_service_id WHERE ss.station_version_id = sv.id), 0) AS available_ports,\""
)
if old_available_ports in content:
    content = content.replace(old_available_ports, new_available_ports)
    print("FIX 1 OK: removed LEFT JOIN charging_unit")
else:
    print("FIX 1 FAIL: pattern not found")

# ==========================================================================
# FIX 2: Add battery swap columns to SELECT
# ==========================================================================
old_select_end = (
    "+ \" total_ports, available_ports, total_power_kw, connector_types\""
    "\n                + \" FROM station_data\""
    "\n                + \" WHERE total_ports > 0\""
)
new_select_end = (
    "+ \" total_ports, available_ports, total_power_kw, connector_types,\""
    "\n                + \" COALESCE((SELECT SUM(ss.total_batteries) FROM station_service ss WHERE ss.station_version_id = station_data.station_id AND ss.service_type = 'BATTERY_SWAP'), 0) AS total_batteries,\""
    "\n                + \" COALESCE(bss.available_batteries, 0) AS available_batteries,\""
    "\n                + \" COALESCE(bss.avg_charge_power_kw, 0) AS avg_charge_power_kw,\""
    "\n                + \" CASE WHEN total_ports > 0 AND total_power_kw > 0 AND (SELECT SUM(ss.total_batteries) FROM station_service ss WHERE ss.station_version_id = station_data.station_id AND ss.service_type = 'BATTERY_SWAP') > 0 THEN 'BOTH'\""
    "\n                + \"      WHEN total_ports > 0 AND total_power_kw > 0 THEN 'CHARGING'\""
    "\n                + \"      WHEN (SELECT SUM(ss.total_batteries) FROM station_service ss WHERE ss.station_version_id = station_data.station_id AND ss.service_type = 'BATTERY_SWAP') > 0 THEN 'BATTERY_SWAP'\""
    "\n                + \"      ELSE 'CHARGING'\""
    "\n                + \" END AS service_type\""
    "\n                + \" FROM station_data\""
    "\n                + \" LEFT JOIN battery_swap_station_state bss ON bss.station_id = station_data.station_id\""
    "\n                + \" WHERE (total_ports > 0 OR (SELECT SUM(ss.total_batteries) FROM station_service ss WHERE ss.station_version_id = station_data.station_id AND ss.service_type = 'BATTERY_SWAP') > 0)\""
)
if old_select_end in content:
    content = content.replace(old_select_end, new_select_end)
    print("FIX 2 OK: added battery swap columns to SELECT")
else:
    print("FIX 2 FAIL: pattern not found")

# ==========================================================================
# FIX 3: Add battery swap station_state join to FROM clause
# ==========================================================================
old_from = (
    "+ \" FROM station_version sv, route_line rl, route_origin ro\""
)
new_from = (
    "+ \" FROM station_version sv, route_line rl, route_origin ro\""
    "\n                + \" LEFT JOIN battery_swap_station_state bss ON bss.station_id = sv.station_id\""
)
if old_from in content:
    content = content.replace(old_from, new_from)
    print("FIX 3 OK: added bss LEFT JOIN")
else:
    print("FIX 3 FAIL: pattern not found")

# ==========================================================================
# FIX 4: Add SWAP_* scoring constants at top of file (after last WEIGHT_* line)
# ==========================================================================
swap_constants = """
    // Scoring weights - BATTERY SWAP
    private static final double WEIGHT_SWAP_DETOUR = 2.0;
    private static final double WEIGHT_SWAP_AVAILABLE_BATTERIES = -3.0;
    private static final double WEIGHT_SWAP_PRICE = 0.01;
    private static final int SWAP_SERVICE_TIME_MINUTES = 5;
    private static final long SWAP_BASE_PRICE_VND = 5_000;
    private static final double SWAP_PENALTY_NO_BATTERY = 80_000;
"""

# Find the last existing WEIGHT constant
last_weight_match = None
for m in re.finditer(r'private static final double WEIGHT_\w+', content):
    last_weight_match = m

if last_weight_match:
    pos = last_weight_match.end()
    content = content[:pos] + swap_constants + content[pos:]
    print("FIX 4 OK: added swap constants")
else:
    print("FIX 4 FAIL: could not find WEIGHT constants")

# ==========================================================================
# FIX 5: Update row processing to handle new columns (after totalPowerKw = row[9])
# ==========================================================================
old_row_proc = """            double totalPowerKw = row[9] != null ? ((Number) row[9]).doubleValue() : 0;

            // Parse connector types
            List<String> connectorTypes = parseConnectorTypes(row[10]);"""
new_row_proc = """            double totalPowerKw = row[9] != null ? ((Number) row[9]).doubleValue() : 0;

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
            }"""
if old_row_proc in content:
    content = content.replace(old_row_proc, new_row_proc)
    print("FIX 5 OK: updated row processing")
else:
    print("FIX 5 FAIL: row processing pattern not found")

# ==========================================================================
# FIX 6: Update scoring logic to handle both types
# ==========================================================================
old_scoring = """                    // Score = detour*2 + (-power*1.5) + (-availablePorts*5) + waitTime*1.5 + chargeTime*0.3
                    score = (detourMeters * WEIGHT_DETOUR)
                            + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                            + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                            + (waitTimeMinutes * WEIGHT_WAIT_TIME)
                            + (estimatedChargeMinutes * WEIGHT_CHARGE_TIME);

                    recommendationReason = buildRecommendationReason(
                            distanceFromRouteMeters, totalPowerKw, availablePorts,
                            waitTimeMinutes, estimatedChargeMinutes, batteryAtArrival);"""
new_scoring = """                    // Unified scoring
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
                            SWAP_SERVICE_TIME_MINUTES, estimatedChargeMinutes, batteryAtArrival);"""
if old_scoring in content:
    content = content.replace(old_scoring, new_scoring)
    print("FIX 6 OK: updated scoring logic")
else:
    print("FIX 6 FAIL: scoring pattern not found")

# ==========================================================================
# FIX 7: Update fallback scoring
# ==========================================================================
old_fallback = """                score = (detourMeters * WEIGHT_DETOUR)
                        + (totalPowerKw == 0 ? PENALTY_UNREACHABLE : totalPowerKw * WEIGHT_POWER)
                        + (availablePorts == 0 ? 200 : availablePorts * WEIGHT_AVAILABLE_PORTS)
                        + (waitTimeMinutes * WEIGHT_WAIT_TIME)
                        + (estimatedChargeMinutes * WEIGHT_CHARGE_TIME);
                recommendationReason = buildFallbackRecommendationReason(
                        distanceFromRouteMeters, totalPowerKw, availablePorts);"""
new_fallback = """                score = computeUnifiedScoreNoEv(
                        serviceType, detourMeters, totalPowerKw, availablePorts,
                        totalBatteries, availableBatteries, basePriceVnd, trustScore);
                estimatedChargeMinutes = totalPowerKw > 0 ? 30 : 20;
                recommendationReason = buildFallbackRecommendationReason(
                        serviceType, distanceFromRouteMeters, totalPowerKw, availablePorts,
                        availableBatteries, avgChargePowerKw, basePriceVnd);"""
if old_fallback in content:
    content = content.replace(old_fallback, new_fallback)
    print("FIX 7 OK: updated fallback scoring")
else:
    print("FIX 7 FAIL: fallback scoring pattern not found")

# ==========================================================================
# FIX 8: Update DTO builder to include new fields
# ==========================================================================
old_builder_end = """                    .score(score)
                    .distanceKm(distanceFromRouteMeters / 1000.0)
                    .build());"""
new_builder_end = """                    .score(score)
                    .distanceKm(distanceFromRouteMeters / 1000.0)
                    .serviceType(serviceType)
                    .availableBatteries(availableBatteries > 0 ? availableBatteries : null)
                    .totalBatteries(totalBatteries > 0 ? totalBatteries : null)
                    .avgChargePowerKw(avgChargePowerKw > 0 ? BigDecimal.valueOf(avgChargePowerKw) : null)
                    .basePriceVnd(basePriceVnd > 0 ? basePriceVnd : null)
                    .estimatedSwapMinutes(SWAP_SERVICE_TIME_MINUTES)
                    .build());"""
if old_builder_end in content:
    content = content.replace(old_builder_end, new_builder_end)
    print("FIX 8 OK: updated DTO builder")
else:
    print("FIX 8 FAIL: builder end pattern not found")

# ==========================================================================
# FIX 9: Update EXIT log to show swap counts
# ==========================================================================
old_exit_log = """        log.info("[REPO] findStationsAlongRoute EXIT | "
                        + "totalScored={} sortedCount={} "
                        + "unreachableCount={} includedCount={} "
                        + "traceId={}",
                stations.size(), stations.size(),
                stations.stream().filter(s -> s.getScore() >= 50_000).count(),
                stations.stream().filter(s -> s.getScore() < 50_000).count(),
                traceId);"""
new_exit_log = """        log.info("[REPO] findStationsAlongRoute EXIT | "
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
                traceId);"""
if old_exit_log in content:
    content = content.replace(old_exit_log, new_exit_log)
    print("FIX 9 OK: updated exit log")
else:
    print("FIX 9 FAIL: exit log pattern not found")

# ==========================================================================
# FIX 10: Replace buildRecommendationReason with new signature
# ==========================================================================
old_build_reason = '''    private String buildRecommendationReason(
            double distanceFromRouteMeters,
            double totalPowerKw,
            int availablePorts,
            int waitTimeMinutes,
            int estimatedChargeMinutes,
            double batteryAtArrival) {

        String proximity = distanceFromRouteMeters <= 200 ? "Right on route"
                : distanceFromRouteMeters <= 1000 ? "Slightly off route"
                : "Off route (" + String.format("%.1f km", distanceFromRouteMeters / 1000.0) + ")";

        StringBuilder sb = new StringBuilder(proximity);
        if (totalPowerKw > 0) {
            sb.append(", ").append(String.format("%.1f kW DC", totalPowerKw));
        }
        if (availablePorts > 0) {
            sb.append(", ").append(availablePorts).append(" ports available");
        } else {
            sb.append(", no available ports");
        }
        if (estimatedChargeMinutes > 0) {
            sb.append(", ~").append(estimatedChargeMinutes).append(" min charge");
        }
        sb.append(", ~").append(String.format("%.0f", batteryAtArrival)).append("% at arrival");
        return sb.toString();
    }

    private String buildFallbackRecommendationReason(
            double distanceFromRouteMeters,
            double totalPowerKw,
            int availablePorts) {

        String proximity = distanceFromRouteMeters <= 200 ? "Right on route"
                : distanceFromRouteMeters <= 1000 ? "Slightly off route"
                : "Off route (" + String.format("%.1f km", distanceFromRouteMeters / 1000.0) + ")";

        StringBuilder sb = new StringBuilder(proximity);
        if (totalPowerKw > 0) {
            sb.append(", ").append(String.format("%.1f kW DC", totalPowerKw));
        }
        if (availablePorts > 0) {
            sb.append(", ").append(availablePorts).append(" ports available");
        } else {
            sb.append(", no available ports");
        }
        return sb.toString();
    }'''

new_build_reason = '''    /**
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

        // CHARGING
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

        // CHARGING
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
                sb.append(", avg ").append(String.format("%.1f", avgChargePowerKw)).append(" kW");
            }
            if (availableBatteries > 0) {
                sb.append(", ").append(availableBatteries).append(" batteries");
            } else {
                sb.append(", no batteries available");
            }
            sb.append(", ~").append(estimatedSwapMinutes).append(" min swap");
        } else if (serviceType == RecommendedStationDTO.ServiceType.BOTH) {
            if (totalPowerKw > 0) {
                sb.append(", ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(", ").append(availablePorts).append(" ports");
            }
            if (availableBatteries > 0) {
                sb.append(", ").append(availableBatteries).append(" swap batteries");
            }
            if (estimatedChargeMinutes > 0) {
                sb.append(", ~").append(estimatedChargeMinutes).append(" min");
            }
        } else {
            if (totalPowerKw > 0) {
                sb.append(", ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(", ").append(availablePorts).append(" ports available");
            } else {
                sb.append(", no available ports");
            }
            if (estimatedChargeMinutes > 0) {
                sb.append(", ~").append(estimatedChargeMinutes).append(" min charge");
            }
        }

        sb.append(", ~").append(String.format("%.0f", batteryAtArrival)).append("% at arrival");
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
                sb.append(", avg ").append(String.format("%.1f", avgChargePowerKw)).append(" kW");
            }
            if (availableBatteries > 0) {
                sb.append(", ").append(availableBatteries).append(" batteries available");
            } else {
                sb.append(", no batteries available");
            }
        } else {
            if (totalPowerKw > 0) {
                sb.append(", ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(", ").append(availablePorts).append(" ports available");
            } else {
                sb.append(", no available ports");
            }
        }
        return sb.toString();
    }'''

if old_build_reason in content:
    content = content.replace(old_build_reason, new_build_reason)
    print("FIX 10 OK: replaced buildRecommendationReason methods")
else:
    print("FIX 10 FAIL: buildRecommendationReason pattern not found")

# ==========================================================================
# Write back
# ==========================================================================
with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
print("\nDone writing file (LF line endings)")
