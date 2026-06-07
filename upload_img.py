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

# Upload the image
with open(r"C:\Users\luquo\Downloads\Chương 4_ Mai-snippet.png", "rb") as f:
    files = {
        "file": ("Mai-snippet.png", f, "image/png"),
        "contentType": (None, "image/png"),
    }
    upload_resp = requests.post(
        f"{BASE_URL}/api/collab/mobile/files/upload",
        headers=collab_headers,
        files=files,
        timeout=60
    )

print(f"Upload: {upload_resp.status_code}")
print(f"Response: {upload_resp.text}")
