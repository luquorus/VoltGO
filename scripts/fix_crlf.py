path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'r', encoding='utf-8', newline='') as f:
    content = f.read()

old_block = '        // Build swap data CTEs\r\n        String swapCte = "";\r\n        if (routeWkt.contains("LINESTRING")) {\r\n            swapCte = """, station_swap_data AS (\r\n                SELECT\r\n                    sv.station_id,\r\n                    COALESCE(bss.available_batteries, 0) AS available_batteries,\r\n                    COALESCE(bss.total_batteries, 0) AS total_batteries,\r\n                    COALESCE(bss.avg_charge_power_kw, 0) AS avg_charge_power_kw\r\n                FROM station_version sv\r\n                LEFT JOIN battery_swap_station_state bss ON bss.station_id = sv.station_id\r\n                WHERE sv.workflow_status = \'PUBLISHED\'\r\n                  AND EXISTS (\r\n                      SELECT 1 FROM station_service ss2\r\n                      WHERE ss2.station_version_id = sv.id AND ss2.service_type = \'BATTERY_SWAP\'\r\n                  )\r\n            ),""";\r\n        }\r\n\r\n        String distanceFilter'

new_block = '        String distanceFilter'

if old_block in content:
    content = content.replace(old_block, new_block)
    print('Replaced swapCte block')
else:
    print('Block not found, trying LF-only version')
    old_block2 = old_block.replace('\r\n', '\n')
    if old_block2 in content:
        content = content.replace(old_block2, new_block)
        print('Replaced (LF version)')
    else:
        print('Still not found')
        # Try to find it with a shorter prefix
        idx = content.find('// Build swap data CTEs')
        if idx != -1:
            end_idx = content.find('String distanceFilter', idx)
            print(f'Found block at {idx}-{end_idx}')
            content = content[:idx] + '        String distanceFilter' + content[end_idx:]
            print('Replaced via positional method')
        else:
            print('CRITICAL: Could not find block at all')

with open(path, 'w', encoding='utf-8', newline='') as f:
    f.write(content)
print('Done')
