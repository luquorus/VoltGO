import requests

BASE_URL = "http://localhost:8080"
collab_login = requests.post(
    f"{BASE_URL}/auth/login",
    json={"email": "collab1@testt", "password": "Admin@123"}
)
collab_token = collab_login.json()["token"]
collab_headers = {"Authorization": f"Bearer {collab_token}"}

object_key = "collab/uploads/2dedc644-6753-482c-892e-d4a777ce0ccf.jpg"
resp = requests.get(
    f"{BASE_URL}/api/collab/mobile/files/view",
    headers=collab_headers,
    params={"objectKey": object_key},
    timeout=30
)
print(f"View: {resp.status_code}")
ct = resp.headers.get("Content-Type", "N/A")
cl = resp.headers.get("Content-Length", "N/A")
print(f"Content-Type: {ct}")
print(f"Content-Length: {cl}")
print(f"First bytes (hex): {resp.content[:8].hex()}")
print(f"Is JPEG: {resp.content[:2] == bytes([0xFF, 0xD8])}")

with open(r"C:\Users\luquo\Downloads\evidenced-viewed.jpg", "wb") as f:
    f.write(resp.content)
print(f"Saved ({len(resp.content)} bytes)")
