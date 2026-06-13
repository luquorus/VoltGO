path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Remove LEFT JOIN charging_unit (table doesn't exist)
# Replace with just using total_ports as available_ports (optimistic, no unit status tracking)
old1 = "                    COALESCE((SELECT SUM(cp.port_count)\n                        FROM station_service ss\n                        JOIN charging_port cp ON ss.id = cp.station_service_id\n                        LEFT JOIN charging_unit cu ON cp.charging_unit_id = cu.id\n                        WHERE ss.station_version_id = sv.id\n                          AND ss.service_type = 'CHARGING'\n                          AND (cu.id IS NULL OR cu.status = 'ACTIVE')), 0) AS available_ports,"
new1 = "                    COALESCE((SELECT SUM(cp.port_count)\n                        FROM station_service ss\n                        JOIN charging_port cp ON ss.id = cp.station_service_id\n                        WHERE ss.station_version_id = sv.id\n                          AND ss.service_type = 'CHARGING'), 0) AS available_ports,"
content = content.replace(old1, new1)

# Fix 2: Remove LEFT JOIN battery_swap_pricing (table doesn't exist)
old2 = "                LEFT JOIN battery_swap_station_state bss ON bss.station_id = sv.station_id\n                LEFT JOIN battery_swap_pricing bp ON bp.station_id = sv.station_id"
new2 = "                LEFT JOIN battery_swap_station_state bss ON bss.station_id = sv.station_id"
content = content.replace(old2, new2)

# Fix 3: Remove bp.base_price_vnd from SELECT
old3 = "                    bss.avg_charge_power_kw AS avg_charge_power_kw,\n                    COALESCE(bp.base_price_vnd, 5000) AS base_price_vnd"
new3 = "                    bss.avg_charge_power_kw AS avg_charge_power_kw,"
content = content.replace(old3, new3)

# Fix 4: In SELECT and row mapping, remove base_price_vnd (index 14 -> 13)
old4 = "                total_batteries, available_batteries, avg_charge_power_kw, base_price_vnd,"
new4 = "                total_batteries, available_batteries, avg_charge_power_kw,"
content = content.replace(old4, new4)

# Fix 5: Remove basePriceVnd from row processing
old5 = "            long basePriceVnd = row[14] != null ? ((Number) row[14]).longValue() : SWAP_BASE_PRICE_VND;"
new5 = "            long basePriceVnd = SWAP_BASE_PRICE_VND;"
content = content.replace(old5, new5)

# Fix 6: Update row indices (now 14 cols instead of 15, service_type at index 14)
# The SELECT is: station_id(0) name(1) address(2) lat(3) lng(4)
# distance_from_route(5) distance_from_origin(6) total_ports(7) available_ports(8)
# total_power_kw(9) connector_types(10) total_batteries(11) available_batteries(12)
# avg_charge_power_kw(13) service_type(14)
old6 = "            String serviceTypeStr = (String) row[15];"
new6 = "            String serviceTypeStr = (String) row[14];"
content = content.replace(old6, new6)

# Fix 7: Remove .basePriceVnd from builder calls (keep in scoring)
old7 = ".basePriceVnd(basePriceVnd > 0 ? basePriceVnd : null)\n                    .build());"
new7 = ".build());"
content = content.replace(old7, old7)  # Don't remove, keep the field

# Fix 8: In computeUnifiedScore calls, remove basePriceVnd param from swap-specific methods
# Actually let me check what the current state is first
print("Fixes applied. Verifying...")

# Check for remaining issues
for check in ['charging_unit', 'bp.base_price', 'LEFT JOIN battery_swap_pricing']:
    pos = content.find(check)
    print(check + ': ' + ('STILL PRESENT at ' + str(pos) if pos != -1 else 'OK (removed)'))

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Written')
