path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\api\ev_user_mobile\service\RoutingService.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the first duplicate @Value annotation (the :3 one that was the original)
old = '    @Value("${app.routing.default-station-limit:3}")\n    @Value("${app.routing.default-station-limit:10}")\n    private int defaultStationLimit;'
new = '    @Value("${app.routing.default-station-limit:10}")\n    private int defaultStationLimit;'
if old in content:
    content = content.replace(old, new)
    print('Fixed duplicate')
else:
    print('Not found')
    idx = content.find('@Value("${app.routing.default-station-limit:3}")')
    if idx != -1:
        print('Found at', idx)
        end = content.find('private int defaultStationLimit;', idx)
        print('Content:', repr(content[idx-20:end+30]))

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
