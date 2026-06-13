path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

print('File size:', len(content), 'chars')
print('Line count:', content.count('\n'), 'lines')

for method in ['computeUnifiedScore', 'computeUnifiedScoreNoEv', 'buildRecommendationReason', 'buildFallbackRecommendationReason', 'parseConnectorTypes']:
    pos = content.find(method)
    status = 'FOUND' if pos != -1 else 'MISSING'
    print(status + ': ' + method + ' at pos ' + str(pos))

old = 'public List<RecommendedStationDTO> findStationsAlongRoute('
count = content.count(old)
print('Old method count: ' + str(count))

# Check for syntax issues
for check in ['SWAP_BASE_PRICE_VND', 'BigDecimal', 'RecommendedStationDTO.ServiceType', 'battery_swap_station_state', 'battery_swap_pricing']:
    pos = content.find(check)
    status = 'FOUND' if pos != -1 else 'MISSING'
    print(status + ': ' + check)
