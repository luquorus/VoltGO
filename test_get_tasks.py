import requests

BASE_URL = "http://localhost:8080"

# Login as collab
collab_login = requests.post(
    f"{BASE_URL}/auth/login",
    json={"email": "collab1@testt", "password": "Admin@123"}
)
print(f"Login: {collab_login.status_code}")
collab_token = collab_login.json()["token"]
collab_headers = {"Authorization": f"Bearer {collab_token}"}

# Get tasks for collab
resp = requests.get(
    f"{BASE_URL}/api/collab/mobile/tasks",
    headers=collab_headers,
    params={"status": "PENDING", "page": 0, "size": 10},
    timeout=30
)
print(f"Tasks: {resp.status_code}")
import json
data = resp.json()
print(json.dumps(data, indent=2, ensure_ascii=False))
