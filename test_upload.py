import requests
import json

BASE_URL = "http://localhost:8080"

# ============ TEST 1: Collab account ============
print("=" * 60)
print("TEST 1: Collab account (collab1@testt)")
print("=" * 60)

collab_login = requests.post(
    f"{BASE_URL}/auth/login",
    json={"email": "collab1@testt", "password": "Admin@123"}
)
print(f"1. Login: {collab_login.status_code}")
collab_token = collab_login.json()["token"]
collab_headers = {"Authorization": f"Bearer {collab_token}"}

# Get a CHECKED_IN task
tasks_resp = requests.get(
    f"{BASE_URL}/api/collab/mobile/tasks",
    headers=collab_headers
)
print(f"2. Get tasks: {tasks_resp.status_code}")
tasks = tasks_resp.json()
checked_in = [t for t in tasks if t.get("status") == "CHECKED_IN"]
print(f"   Found {len(checked_in)} CHECKED_IN tasks")
for t in checked_in:
    print(f"   - Task ID: {t['id']}, Station: {t.get('stationName')}")

if not checked_in:
    print("No CHECKED_IN tasks available. Testing presign-upload only.")
else:
    task_id = checked_in[0]["id"]

    # Proxy upload
    jpg_bytes = (
        b"\xff\xd8\xff\xe0\x00\x10\x4a\x46\x49\x46\x00\x01\x01\x00\x00\x01"
        b"\x00\x01\x00\x00\xff\xdb\x00\x43\x00\x08\x06\x06\x07\x06\x05\x08"
        b"\x07\x07\x07\x09\x09\x08\x0a\x0c\x14\x0d\x0c\x0b\x0b\x0c\x19\x12"
        b"\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c\x20\x24\x2e\x27\x20"
        b"\x22\x2c\x23\x1c\x1c\x28\x37\x29\x2c\x30\x31\x34\x34\x34\x1f\x27"
        b"\x39\x3d\x38\x32\x3c\x2e\x33\x34\x32\xff\xc0\x00\x0b\x08\x00\x01"
        b"\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01"
        b"\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03"
        b"\x04\x05\x06\x07\x08\x09\x0a\x0b\xff\xc4\x00\xb5\x10\x00\x02\x01"
        b"\x03\x03\x02\x04\x03\x05\x05\x04\x04\x00\x00\x01\x7d\x01\x02\x03"
        b"\x00\x04\x11\x05\x12\x21\x31\x41\x06\x13\x51\x61\x07\x22\x71\x14"
        b"\x32\x81\x91\xa1\x08\x23\x42\xb1\xc1\x15\x52\xd1\xf0\x24\x33\x62"
        b"\x72\x82\x09\x0a\xff\xda\x00\x08\x01\x01\x00\x00\x3f\x00\xfb\xd5"
        b"\xdb\x20\xa8\xa2\x80\x0a\xff\xd9"
    )
    files = {
        "file": ("test.jpg", jpg_bytes, "image/jpeg"),
        "contentType": (None, "image/jpeg"),
    }
    upload_resp = requests.post(
        f"{BASE_URL}/api/collab/mobile/files/upload",
        headers=collab_headers,
        files=files,
        timeout=30
    )
    print(f"3. Proxy upload: {upload_resp.status_code}")
    if upload_resp.status_code == 200:
        obj_key = upload_resp.json()["objectKey"]
        print(f"   ObjectKey: {obj_key}")

        # Submit evidence
        evidence_resp = requests.post(
            f"{BASE_URL}/api/collab/mobile/tasks/{task_id}/submit-evidence",
            headers=collab_headers,
            json={"photoObjectKey": obj_key, "note": "Test via Python script"}
        )
        print(f"4. Submit evidence: {evidence_resp.status_code}")
        print(f"   Response: {evidence_resp.text[:200]}")
    else:
        print(f"   Upload failed: {upload_resp.text}")

# ============ TEST 2: Admin account ============
print("\n" + "=" * 60)
print("TEST 2: Admin account (admin2@local)")
print("=" * 60)

admin_login = requests.post(
    f"{BASE_URL}/auth/login",
    json={"email": "admin2@local", "password": "Admin@456"}
)
print(f"1. Login: {admin_login.status_code}")
admin_token = admin_login.json()["token"]
admin_headers = {"Authorization": f"Bearer {admin_token}"}

# Try to access collab mobile endpoint (should be FORBIDDEN)
forbidden_resp = requests.get(
    f"{BASE_URL}/api/collab/mobile/tasks",
    headers=admin_headers
)
print(f"2. Access collab mobile endpoint: {forbidden_resp.status_code}")
print(f"   Expected: 403 FORBIDDEN (Admin cannot access collab endpoints)")
print(f"   Response: {forbidden_resp.text[:200]}")
