path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_methods = """    private String buildRecommendationReason(
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
            sb.append(" \u2022 Fast charging ").append((int) totalPowerKw).append("kW");
        } else if (totalPowerKw >= 50) {
            sb.append(" \u2022 Power ").append((int) totalPowerKw).append("kW");
        }

        if (availablePorts >= 3) {
            sb.append(" \u2022 Many ports available");
        } else if (availablePorts == 0) {
            sb.append(" \u2022 May wait ~").append(waitTimeMinutes).append(" min");
        } else {
            sb.append(" \u2022 ").append(availablePorts).append(" ports free");
        }

        sb.append(" \u2022 Estimated charge time ").append(estimatedChargeMinutes).append(" min");
        sb.append(String.format(" \u2022 Battery ~%.0f%% at arrival", batteryAtArrival));

        return sb.toString();
    }

    private String buildFallbackRecommendationReason(
            double distanceFromRouteMeters,
            double totalPowerKw,
            int availablePorts) {

        String proximity = distanceFromRouteMeters <= 200 ? "Right on route"
                : distanceFromRouteMeters <= 500 ? "Very close to route"
                : "Near route";
        String power = totalPowerKw >= 50 ? " \u2022 " + (int) totalPowerKw + "kW" : "";
        String ports = availablePorts >= 2 ? " \u2022 " + availablePorts + " ports free"
                : availablePorts == 0 ? " \u2022 May need to wait" : " \u2022 1 port free";
        return proximity + power + ports;
    }"""

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

if old_methods in content:
    content = content.replace(old_methods, new_methods)
    print("FIX 10 OK: replaced buildRecommendationReason methods")
else:
    print("FIX 10 FAIL: pattern not found")
    # Try to find the start of buildRecommendationReason
    idx = content.find("private String buildRecommendationReason(")
    if idx != -1:
        # Find the end - look for the next method
        end_idx = content.find("private String buildFallbackRecommendationReason(", idx)
        if end_idx != -1:
            # Find the end of buildFallbackRecommendationReason
            end_end = content.find("\n    }", end_idx + 10)
            if end_end != -1:
                end_end += 4  # include "    }"
                print(f"Found methods at {idx}-{end_end}")
                print("Content:", repr(content[idx:idx+100]))

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
print("Written")
