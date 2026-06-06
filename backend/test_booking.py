import requests
import json
import sys

base_url = "http://localhost:8080"

# Login
print("=== LOGIN ===")
login = requests.post(f"{base_url}/auth/login", json={"email": "test@1", "password": "Admin@123"}, timeout=10)
login.raise_for_status()
j = login.json()
tok = j["token"]
h = {"Authorization": f"Bearer {tok}"}
print(f"Logged in: {j['email']}")

# Get station
print("\n=== GET STATION ===")
s = requests.get(f"{base_url}/api/ev/stations?lat=20.990150&lng=105.855610&radiusKm=10&page=0&size=1", headers=h, timeout=10)
s.raise_for_status()
sd = s.json()
station = sd["content"][0]
station_id = station["id"]
print(f"Station: {station['name']} ({station_id})")

# Get charger units
print("\n=== GET CHARGER UNITS ===")
a = requests.get(f"{base_url}/api/ev/stations/{station_id}/availability", headers=h, timeout=10)
a.raise_for_status()
ad = a.json()
unit = ad[0]
unit_id = unit["chargerUnitId"]
print(f"Unit: {unit_id}")

# Create booking
print("\n=== CREATE BOOKING ===")
from datetime import datetime, timedelta
import pytz
start = (datetime.now(pytz.UTC) + timedelta(minutes=60)).isoformat()
end = (datetime.now(pytz.UTC) + timedelta(minutes=120)).isoformat()
booking = requests.post(f"{base_url}/api/ev/bookings", json={
    "stationId": station_id,
    "chargerUnitId": unit_id,
    "startTime": start,
    "endTime": end
}, headers=h, timeout=10)
booking.raise_for_status()
bd = booking.json()
booking_id = bd["id"]
print(f"Booking: {booking_id} ({bd['status']})")

# Create payment intent
print("\n=== CREATE PAYMENT INTENT ===")
pi = requests.post(f"{base_url}/api/ev/payments/bookings/{booking_id}/payment-intent", headers=h, timeout=10)
pi.raise_for_status()
pid = pi.json()
intent_id = pid["id"]
print(f"Payment intent: {intent_id}")

# Simulate success
print("\n=== SIMULATE SUCCESS ===")
try:
    sim = requests.post(f"{base_url}/api/ev/payments/{intent_id}/simulate-success", headers=h, timeout=10)
    sim.raise_for_status()
    res = sim.json()
    print(f"SUCCESS! Status: {res['status']}")

    # Check loyalty
    print("\n=== LOYALTY ===")
    profile = requests.get(f"{base_url}/api/ev/loyalty/me", headers=h, timeout=10)
    profile.raise_for_status()
    p = profile.json()
    print(f"Points: {p['currentPoints']} | Lifetime: {p['lifetimePoints']}")
    print(f"Bookings: {p['totalBookings']} | Ratings: {p['totalRatings']}")
    print(f"Level: {p['level']} - {p['levelName']}")

    # Point history
    print("\n=== POINT HISTORY ===")
    hist = requests.get(f"{base_url}/api/ev/loyalty/points/history?page=0&size=5", headers=h, timeout=10)
    hist.raise_for_status()
    h_data = hist.json()
    print(f"Total transactions: {h_data['totalElements']}")
    for tx in h_data.get("content", []):
        print(f"  {tx['type']} | {tx['source']} | +{tx['points']} pts")
except requests.exceptions.HTTPError as e:
    print(f"HTTP ERROR: {e.response.status_code} - {e.response.text}")
except Exception as e:
    print(f"ERROR: {e}")

print("\n=== DONE ===")
