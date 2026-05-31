#!/usr/bin/env python3
"""
VoltGo Battery Swap — EV User Flow Test
======================================
Flow mới (không có admin/simulator action):
  1. EV User discovers stations and reserves a slot
  2. EV User pays
  3. EV User confirms arrival
  4. EV User starts swap -> backend generates code + WS broadcasts to simulator
  5. Hardware Simulator receives code via WS, displays it
  6. EV User enters code to verify-swap -> COMPLETED
     Backend: pin day user lay, pin cua user duoc dat vao slot & bat dau sac

Prerequisites:
  - Backend and DB running (docker compose up -d)
  - Account: test@1 / Admin@123 (EV_USER)
  - Existing stations with AVAILABLE slots
"""

import requests
import json
import time
import websocket
import threading
import sys

# ── Configuration ────────────────────────────────────────────────────────────
BASE = "http://localhost:8080"
EV_EMAIL = "test@1"
EV_PASSWORD = "Admin@123"
STATION_ID = "f1000000-0000-0000-0000-000000000001"
LAT = 21.0288
LNG = 105.8545


def p(label, data):
    print(f"\n{'='*62}")
    print(f"  {label}")
    print(f"{'='*62}")
    print(json.dumps(data, indent=2, ensure_ascii=False))


def login(email, password):
    r = requests.post(f"{BASE}/auth/login", json={"email": email, "password": password})
    r.raise_for_status()
    resp = r.json()
    return resp["token"], resp["userId"], resp.get("role", "?")


def h(token):
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


# ── Display WebSocket client (hardware simulator side) ─────────────────────────
class DisplayWSClient:
    """Connects to /ws/display/battery-swap to receive swap codes and slot updates."""

    def __init__(self, station_id):
        self.station_id = station_id
        self.ws = None
        self.received_messages = []
        self.connected = False
        self._thread = None

    def connect(self):
        device_key = self._get_device_key()
        ws_url = f"ws://localhost:8080/ws/display/battery-swap?deviceKey={device_key}"
        print(f"\n  [SIMULATOR WS] Connecting to {ws_url}")
        self.ws = websocket.WebSocketApp(
            ws_url,
            on_open=self._on_open,
            on_message=self._on_message,
            on_error=self._on_error,
            on_close=self._on_close,
        )
        self._thread = threading.Thread(target=self.ws.run_forever, daemon=True)
        self._thread.start()
        time.sleep(2)

    def _get_device_key(self):
        try:
            r = requests.get(
                f"{BASE}/api/public/device/stations/{self.station_id}/key",
                params={"deviceName": "TestSimulatorDevice"}
            )
            if r.status_code == 200:
                return r.json().get("deviceKey", "test-device-key")
        except Exception:
            pass
        return "test-device-key"

    def subscribe(self):
        msg = json.dumps({"type": "subscribe", "stationId": self.station_id})
        self.ws.send(msg)
        time.sleep(1)

    def _on_open(self, ws):
        print("  [SIMULATOR WS] Connected!")
        self.connected = True

    def _on_message(self, ws, message):
        data = json.loads(message)
        self.received_messages.append(data)
        msg_type = data.get("type", "?")
        print(f"\n  [SIMULATOR WS] <<<< {msg_type}")
        if msg_type == "SWAP_CODE":
            print(f"       stationId  : {data.get('stationId')}")
            print(f"       slotId     : {data.get('slotId')}")
            print(f"       swapCode   : {data.get('swapCode')}")
            print(f"       deadlineAt : {data.get('deadlineAt')}")
            print("       >>> Simulator should now DISPLAY this code on screen!")
        elif msg_type == "SLOT_UPDATE":
            slot = data.get("slot", {})
            print(f"       slotIndex : {slot.get('slotIndex')}")
            print(f"       status    : {slot.get('status')}")
            print(f"       charge%   : {slot.get('batteryChargePercent')}")
        elif msg_type == "SWAP_COMPLETED":
            print(f"       stationId : {data.get('stationId')}")
            print(f"       newStatus: {data.get('newStatus')}")
            print("       >>> User took full battery, old battery is now charging!")
        elif msg_type == "CONNECTED":
            print(f"       Server confirmed connection")
        elif msg_type == "SUBSCRIBED":
            print(f"       stationId : {data.get('stationId')}")
        elif msg_type == "ERROR":
            print(f"       error     : {data.get('message')}")
        else:
            print(f"       {json.dumps(data, ensure_ascii=False)[:200]}")

    def _on_error(self, ws, error):
        print(f"  [SIMULATOR WS] ERROR: {error}")

    def _on_close(self, ws, code, reason):
        print(f"  [SIMULATOR WS] Closed ({code}): {reason}")
        self.connected = False

    def close(self):
        if self.ws:
            self.ws.close()

    def wait_for_swap_code(self, timeout=30):
        """Block until SWAP_CODE message is received."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            for msg in self.received_messages:
                if msg.get("type") == "SWAP_CODE":
                    return msg
            time.sleep(0.5)
        return None

    def wait_for_swap_completed(self, timeout=30):
        """Block until SWAP_COMPLETED message is received."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            for msg in self.received_messages:
                if msg.get("type") == "SWAP_COMPLETED":
                    return msg
            time.sleep(0.5)
        return None


# ── Public API helpers ───────────────────────────────────────────────────────
def public_get_all_stations():
    """List all published battery swap stations (no auth required)."""
    r = requests.get(f"{BASE}/api/public/battery-swap/stations")
    r.raise_for_status()
    return r.json()


def public_get_station_piles(station_id):
    """Get station piles and slots (no auth required)."""
    r = requests.get(f"{BASE}/api/public/battery-swap/stations/{station_id}/piles")
    r.raise_for_status()
    return r.json()


# ── EV User helpers ──────────────────────────────────────────────────────────
def ev_get_station_detail(token, station_id):
    r = requests.get(f"{BASE}/api/ev/battery-swap/stations/{station_id}", headers=h(token))
    r.raise_for_status()
    return r.json()


# ── Main test ───────────────────────────────────────────────────────────────
def main():
    print("\n" + "="*62)
    print("  VoltGo Battery Swap — EV User Flow Test")
    print("  (No admin/simulator actions — display-only simulator)")
    print("="*62)

    # ── 0. Login ─────────────────────────────────────────────────────────────
    print("\n[STEP 0] Login as EV user")
    ev_token, ev_user_id, ev_role = login(EV_EMAIL, EV_PASSWORD)
    print(f"  Logged in: userId={ev_user_id}, role={ev_role}")

    # ── 0b. Cleanup — cancel existing reservations ───────────────────────────
    print("\n[STEP 0b] Cleanup — cancel existing RESERVED/SWAPPING reservations")
    r = requests.get(f"{BASE}/api/ev/battery-swap/reservations/mine", headers=h(ev_token))
    if r.status_code == 200:
        existing = r.json()
        for res in existing:
            if res["status"] in ("RESERVED", "SWAPPING"):
                print(f"  Cancelling reservation {res['id']} ({res['status']})")
                r2 = requests.post(
                    f"{BASE}/api/ev/battery-swap/reservations/{res['id']}/cancel",
                    headers=h(ev_token)
                )
                print(f"  Cancel: {r2.status_code}")

    # ── 1. Public API — list all published stations ──────────────────────────
    print("\n[STEP 1] Public API — list all published battery swap stations")
    stations = public_get_all_stations()
    print(f"  Found {len(stations)} station(s)")
    for s in stations:
        print(f"    - {s.get('name', s.get('stationId', '?'))} ({s.get('stationId', '?')})")

    # ── 2. EV User — station detail + pick AVAILABLE slot ───────────────────
    print(f"\n[STEP 2] EV User — station detail for {STATION_ID}")
    detail = ev_get_station_detail(ev_token, STATION_ID)
    print(f"  Station: {detail.get('name')}")
    print(f"  Address: {detail.get('address')}")
    print(f"  Piles: {detail.get('totalPiles')}, Slots: {detail.get('totalSlots')}, "
          f"Available: {detail.get('availableSlots')}")

    # Find first AVAILABLE slot
    available_slot = None
    selected_pile_id = None
    selected_pile_index = None
    for pile in detail.get("piles", []):
        for slot in pile.get("slots", []):
            if slot.get("status") == "AVAILABLE":
                available_slot = slot
                selected_pile_id = pile.get("pileId")
                selected_pile_index = pile.get("pileIndex")
                break
        if available_slot:
            break

    if not available_slot:
        print("  FATAL: No AVAILABLE slot found!")
        sys.exit(1)

    slot_id = available_slot["slotId"]
    print(f"  Selected slot: pile={selected_pile_index} (id={selected_pile_id}), "
          f"slot={available_slot['slotIndex']} (id={slot_id}), "
          f"status={available_slot['status']}, charge={available_slot['batteryChargePercent']}%")

    # ── 3. Reserve slot ─────────────────────────────────────────────────────
    print("\n[STEP 3] EV User — reserve slot")
    r = requests.post(
        f"{BASE}/api/ev/battery-swap/reservations",
        headers=h(ev_token),
        json={
            "stationId": STATION_ID,
            "expectedArrivalAt": "2026-06-01T10:00:00Z",
            "requestedBatteryPercent": 20,
            "batteryCapacityKwh": 60.0,
            "pileId": str(selected_pile_id),
            "slotId": str(slot_id),
        }
    )
    if r.status_code not in (200, 201):
        print(f"  ERROR {r.status_code}: {r.text[:500]}")
        sys.exit(1)
    reservation = r.json()
    p("Reservation created", reservation)
    res_id = reservation["id"]
    print(f"  Reservation ID : {res_id}")
    print(f"  Status         : {reservation.get('status')}")
    print(f"  Payment Status : {reservation.get('paymentStatus')}")

    # ── 4. Pay ─────────────────────────────────────────────────────────────
    print("\n[STEP 4] EV User — pay reservation")
    r = requests.post(
        f"{BASE}/api/ev/battery-swap/reservations/{res_id}/pay",
        headers=h(ev_token)
    )
    r.raise_for_status()
    reservation = r.json()
    print(f"  Payment status: {reservation.get('paymentStatus')}")
    print(f"  Base price    : {reservation.get('basePriceVnd')} VND")

    # ── 5. Confirm arrival ─────────────────────────────────────────────────
    print("\n[STEP 5] EV User — confirm arrival")
    r = requests.post(
        f"{BASE}/api/ev/battery-swap/reservations/{res_id}/confirm-arrival",
        headers=h(ev_token)
    )
    r.raise_for_status()
    reservation = r.json()
    print(f"  confirmedArrivalAt: {reservation.get('confirmedArrivalAt')}")
    print(f"  Status             : {reservation.get('status')}")

    # ── 6. Start hardware simulator WebSocket (BEFORE start swap) ────────────
    print("\n[STEP 6] Hardware Simulator — connect WS and subscribe to station")
    ws_client = DisplayWSClient(STATION_ID)
    ws_client.connect()
    ws_client.subscribe()
    time.sleep(1)

    # ── 7. Start swap — backend generates code + WS broadcasts ──────────────
    print("\n[STEP 7] EV User — start swap")
    print("  Backend generates 4-digit code and broadcasts to simulator WS")
    r = requests.post(
        f"{BASE}/api/ev/battery-swap/reservations/{res_id}/start",
        headers=h(ev_token)
    )
    if r.status_code != 200:
        print(f"  ERROR {r.status_code}: {r.text[:500]}")
        sys.exit(1)
    reservation = r.json()
    p("After start (swap code generated)", reservation)
    swap_code = reservation.get("swapCode")
    swap_deadline = reservation.get("swapDeadlineAt")
    print(f"\n  >>> SWAP CODE (from API): {swap_code}")
    print(f"  >>> Deadline             : {swap_deadline}")

    if not swap_code:
        print("  FATAL: No swap code returned!")
        sys.exit(1)

    # ── 8. Wait for simulator WS to receive code ────────────────────────────
    print("\n[STEP 8] Hardware Simulator — wait for SWAP_CODE via WS")
    code_event = ws_client.wait_for_swap_code(timeout=10)
    if code_event:
        print(f"  Simulator received code: {code_event.get('swapCode')}")
        print(f"  Simulator should display this code prominently on screen!")
    else:
        print("  WARNING: Simulator did not receive SWAP_CODE via WS within timeout")

    # ── 9. EV User — verify-swap with code ──────────────────────────────────
    print(f"\n[STEP 9] EV User — verify-swap with code '{swap_code}'")
    print("  User enters code on app -> backend COMPLETES swap")
    print("  Backend: full battery to user, old battery -> slot -> starts charging")
    r = requests.post(
        f"{BASE}/api/ev/battery-swap/reservations/{res_id}/verify-swap",
        headers=h(ev_token),
        json={"swapCode": swap_code}
    )
    print(f"  verify-swap: {r.status_code}")
    if r.status_code == 200:
        result = r.json()
        p("Swap COMPLETED!", result)
        print(f"  Final status        : {result.get('status')}")
        print(f"  Final payment status: {result.get('paymentStatus')}")
        print(f"  completedAt         : {result.get('completedAt')}")
        print("  >>> User got full battery, old battery is now charging in the slot!")
    else:
        print(f"  Response: {r.text[:500]}")

    # ── 10. Wait for SWAP_COMPLETED broadcast ───────────────────────────────
    print("\n[STEP 10] Hardware Simulator — wait for SWAP_COMPLETED via WS")
    completed_event = ws_client.wait_for_swap_completed(timeout=10)
    if completed_event:
        print(f"  Simulator received SWAP_COMPLETED!")
        print(f"  >>> Slot status: {completed_event.get('newStatus')}")
        print("  >>> Old battery is now charging in the slot (SWAPPED_OUT -> CHARGING)")
    else:
        print("  WARNING: Simulator did not receive SWAP_COMPLETED within timeout")

    # ── 11. Public API — check slot status after completion ─────────────────
    print("\n[STEP 11] Public API — check slot status after swap")
    piles = public_get_station_piles(STATION_ID)
    print(f"  Station: {piles.get('stationName')}")
    for pile in piles.get("piles", []):
        print(f"  Pile {pile.get('pileIndex')+1} ({pile.get('status')}):")
        for slot in pile.get("slots", []):
            marker = " <-- SWAPPED_OUT (old battery charging)" if slot.get("status") == "SWAPPED_OUT" else ""
            print(f"    Slot {slot.get('slotIndex')+1}: {slot.get('batteryChargePercent')}% "
                  f"[{slot.get('status')}]{marker}")

    # ── 12. EV User — final reservation state ───────────────────────────────
    print("\n[STEP 12] EV User — final reservation state")
    r = requests.get(f"{BASE}/api/ev/battery-swap/reservations/{res_id}", headers=h(ev_token))
    r.raise_for_status()
    p("Final Reservation State", r.json())

    # ── 13. EV User — list own reservations ─────────────────────────────────
    print("\n[STEP 13] EV User — list own reservations")
    r = requests.get(f"{BASE}/api/ev/battery-swap/reservations/mine", headers=h(ev_token))
    r.raise_for_status()
    mine = r.json()
    print(f"  Total reservations: {len(mine)}")
    for res in mine:
        print(f"    [{res['id'][:8]}] {res.get('stationName', '?')} | "
              f"status={res['status']} | payment={res['paymentStatus']}")

    # ── Cleanup WS ────────────────────────────────────────────────────────────
    ws_client.close()

    print("\n" + "="*62)
    print("  ALL DONE! EV User Battery Swap Flow Complete.")
    print("  Summary: reserve -> pay -> arrive -> start -> verify -> COMPLETED")
    print("="*62)


if __name__ == "__main__":
    main()
