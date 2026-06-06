import requests
from datetime import datetime, timezone, timedelta

tok = requests.post('http://localhost:8080/auth/login', json={'email':'test@1','password':'Admin@123'}, timeout=10).json()['token']
h = {'Authorization': 'Bearer ' + tok}

s = requests.get('http://localhost:8080/api/ev/stations?lat=20.990150&lng=105.855610&radiusKm=10&page=0&size=1', headers=h, timeout=10).json()
station_id = s['content'][0]['stationId']
print('Station:', station_id)

# Use 2nd unit
unit_id = 'cd4df005-f681-4040-9ae8-3822ac46fd8e'
now = datetime.now(timezone.utc)
start = (now + timedelta(hours=7)).isoformat()
end = (now + timedelta(hours=8)).isoformat()

bd = requests.post('http://localhost:8080/api/ev/bookings', json={'stationId': station_id, 'chargerUnitId': unit_id, 'startTime': start, 'endTime': end}, headers=h, timeout=10)
print('Booking:', bd.status_code)
if bd.status_code != 201:
    print('Error:', bd.text[:300])
    exit(1)

bid = bd.json()['id']
print('Booking ID:', bid)

pid = requests.post('http://localhost:8080/api/ev/bookings/' + bid + '/payment-intent', headers=h, timeout=10)
print('Intent:', pid.status_code)
if pid.status_code != 201:
    print('Error:', pid.text[:300])
    exit(1)
intent_id = pid.json()['id']

r2 = requests.post('http://localhost:8080/api/ev/payments/' + intent_id + '/simulate-success', headers=h, timeout=10)
print('Simulate:', r2.status_code)
if r2.status_code != 200:
    print('Error:', r2.text[:500])
    exit(1)

p = requests.get('http://localhost:8080/api/ev/loyalty/me', headers=h, timeout=10).json()
print('')
print('=== LOYALTY ===')
print('Current Points:', p['currentPoints'])
print('Lifetime Points:', p['lifetimePoints'])
print('Total Bookings:', p['totalBookings'])
print('Level:', p['level'], '-', p['levelName'])

h2 = requests.get('http://localhost:8080/api/ev/loyalty/points/history?page=0&size=5', headers=h, timeout=10).json()
print('')
print('=== POINT HISTORY ===')
print('Total:', h2['totalElements'], 'transactions')
for tx in h2.get('content', []):
    print(' ', tx['type'], '|', tx['source'], '| +', tx['points'], 'pts |', tx.get('description',''))
print('')
print('=== SUCCESS ===')
