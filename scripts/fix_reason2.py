path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace using exact bytes from the file
start = content.find("    private String buildRecommendationReason(")
end_fb = content.find("    private String buildFallbackRecommendationReason(")
if end_fb == -1:
    print("buildFallbackRecommendationReason not found")
    exit(1)
end_end = content.find("\n    }", end_fb + 10)
if end_end == -1:
    print("Closing brace not found")
    exit(1)
end_end += 4

# Extract exact original
orig = content[start:end_end]
print(f"Original block ({start}-{end_end}), length={len(orig)}")

# Build new methods
new_methods = """    /**
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
                sb.append(" \u2022 avg ").append(String.format("%.1f", avgChargePowerKw)).append(" kW");
            }
            if (availableBatteries > 0) {
                sb.append(" \u2022 ").append(availableBatteries).append(" batteries");
            } else {
                sb.append(" \u2022 no batteries available");
            }
            sb.append(" \u2022 ~").append(estimatedSwapMinutes).append(" min swap");
        } else if (serviceType == RecommendedStationDTO.ServiceType.BOTH) {
            if (totalPowerKw > 0) {
                sb.append(" \u2022 ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(" \u2022 ").append(availablePorts).append(" ports");
            }
            if (availableBatteries > 0) {
                sb.append(" \u2022 ").append(availableBatteries).append(" swap batteries");
            }
            if (estimatedChargeMinutes > 0) {
                sb.append(" \u2022 ~").append(estimatedChargeMinutes).append(" min");
            }
        } else {
            if (totalPowerKw > 0) {
                sb.append(" \u2022 ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(" \u2022 ").append(availablePorts).append(" ports available");
            } else {
                sb.append(" \u2022 no available ports");
            }
            if (estimatedChargeMinutes > 0) {
                sb.append(" \u2022 ~").append(estimatedChargeMinutes).append(" min charge");
            }
        }

        sb.append(" \u2022 ~").append(String.format("%.0f", batteryAtArrival)).append("% at arrival");
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
                sb.append(" \u2022 avg ").append(String.format("%.1f", avgChargePowerKw)).append(" kW");
            }
            if (availableBatteries > 0) {
                sb.append(" \u2022 ").append(availableBatteries).append(" batteries available");
            } else {
                sb.append(" \u2022 no batteries available");
            }
        } else {
            if (totalPowerKw > 0) {
                sb.append(" \u2022 ").append(String.format("%.1f", totalPowerKw)).append(" kW DC");
            }
            if (availablePorts > 0) {
                sb.append(" \u2022 ").append(availablePorts).append(" ports available");
            } else {
                sb.append(" \u2022 no available ports");
            }
        }
        return sb.toString();
    }"""

if orig in content:
    content = content.replace(orig, new_methods)
    print("SUCCESS: replaced methods")
else:
    print("FAIL: original block not found in content")
    print("Trying prefix match...")
    if content[start:start+100] == orig[:100]:
        print("Prefix matches but full block doesn't")
    else:
        print("Even prefix doesn't match")

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
print("Written")
