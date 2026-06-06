import requests
from datetime import datetime, timezone, timedelta

# Wait for backend
print("Waiting for backend...")
for i in range(60):
    try:
        r = requests.post('http://localhost:8080/auth/login', json={'email':'test@1','password':'Admin@123'}, timeout=2)
        print(f"Backend ready! Status: {r.status_code}")
        break
    except:
        print('.', end='', flush=True)
        import time; time.sleep(1)
else:
    print("Backend not ready after 60s")
    exit(1)

tok = r.json()['token']
h = {'Authorization': f'Bearer {tok}'}

# Get station
s = requests.get('http://localhost:8080/api/ev/stations?lat=20.990150&lng=105.855610&radiusKm=10&page=0&size=1', headers=h, timeout=10).json()
station_id = s['content'][0]['stationId']
print(f'Station: {station_id}')

unit_id = 'a8507094-87d0-484d-8e13-6190785277ac'
now = datetime.now(timezone.utc)
start = (now + timedelta(hours=5)).isoformat()
end = (now + timedelta(hours=6)).isoformat()

# Create booking
bd = requests.post('http://localhost:8080/api/ev/bookings', json={'stationId': station_id, 'chargerUnitId': unit_id, 'startTime': start, 'endTime': end}, headers=h, timeout=10)
print(f'Booking: {bd.status_code}')
if bd.status_code != 201:
    print('Error:', bd.text[:300])
    exit(1)

bid = bd.json()['id']
print(f'Booking ID: {bid}')

# Create payment intent
pid = requests.post(f'http://localhost:8080/api/ev/bookings/{bid}/payment-intent', headers=h, timeout=10)
print(f'Intent: {pid.status_code}')
if pid.status_code != 201:
    print('Error:', pid.text[:300])
    exit(1)
intent_id = pid.json()['id']
print(f'Intent ID: {intent_id}')

# Simulate success
r2 = requests.post(f'http://localhost:8080/api/ev/payments/{intent_id}/simulate-success', headers=h, timeout=10)
print(f'Simulate: {r2.status_code}')
if r2.status_code != 200:
    print('Error:', r2.text[:500])
    exit(1)

# Check loyalty
p = requests.get('http://localhost:8080/api/ev/loyalty/me', headers=h, timeout=10).json()
print(f'\n=== LOYALTY ===')
print(f'Current Points: {p["currentPoints"]}')
print(f'Lifetime Points: {p["lifetimePoints"]}')
print(f'Total Bookings: {p["totalBookings"]}')
print(f'Level: {p["level"]} - {p["levelName"]}')

h2 = requests.get('http://localhost:8080/api/ev/loyalty/points/history?page=0&size=5', headers=h, timeout=10).json()
print(f'\n=== POINT HISTORY ===')
print(f'Total: {h2["totalElements"]} transactions')
for tx in h2.get('content', []):
    print(f'  {tx["type"]} | {tx["source"]} | +{tx["points"]} pts | {tx.get("description","")}')

print('\n=== DONE ===')
