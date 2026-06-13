path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\api\ev_user_mobile\service\RoutingService.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix line 85: callOsrmWithRetry call
old1 = 'callOsrmWithRetry(\n                    originLng, originLat, destLng, destLat, traceId);'
new1 = 'callOsrmWithRetry(\n                    originLng, originLat, destLng, destLat, traceId);'

# Fix line 201: callOsrm call
old2 = 'return callOsrm(originLng, originLat, destLng, destLat, traceId);'
new2 = 'return callOsrm(originLng, originLat, destLng, destLat, traceId);'

# The actual bug: 4th arg should be destLat but is destLng
# destLng = getLng(), destLat = getLat()
# So the 4th arg in the call currently passes destLng where destLat should go
# FIX: replace the 4th occurrence of destLng with destLat

# For callOsrmWithRetry (line 85):
old_c1 = 'callOsrmWithRetry(\n                    originLng, originLat, destLng, destLng, traceId);'
new_c1 = 'callOsrmWithRetry(\n                    originLng, originLat, destLng, destLat, traceId);'
if old_c1 in content:
    content = content.replace(old_c1, new_c1)
    print("FIX 1 OK: callOsrmWithRetry")
else:
    print("FIX 1 FAIL")

# For callOsrm (line 201):
old_c2 = 'return callOsrm(originLng, originLat, destLng, destLng, traceId);'
new_c2 = 'return callOsrm(originLng, originLat, destLng, destLat, traceId);'
if old_c2 in content:
    content = content.replace(old_c2, new_c2)
    print("FIX 2 OK: callOsrm")
else:
    print("FIX 2 FAIL")

# Fix log too
old_log = 'url=/route/v1/driving/{},{};{},{} traceId={}",\n                        attempt + 1, originLng, originLat, destLng, destLng, traceId'
new_log = 'url=/route/v1/driving/{},{};{},{} traceId={}",\n                        attempt + 1, originLng, originLat, destLng, destLat, traceId'
if old_log in content:
    content = content.replace(old_log, new_log)
    print("FIX 3 OK: log")
else:
    print("FIX 3 FAIL")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
