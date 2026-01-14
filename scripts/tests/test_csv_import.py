#!/usr/bin/env python3
"""Test CSV import for stations"""
import requests
import json
import sys

BASE_URL = "http://localhost:8080"
CSV_FILE = "data/test_stations.csv"

def main():
    # Login
    print("Logging in as admin...")
    login_data = {
        "email": "admin@local",
        "password": "Admin@123"
    }
    
    response = requests.post(f"{BASE_URL}/auth/login", json=login_data)
    if response.status_code != 200:
        print(f"Login failed: {response.status_code}")
        print(response.text)
        sys.exit(1)
    
    token = response.json()["token"]
    print(f"Login successful! Token: {token[:50]}...")
    
    # Import CSV
    print(f"\nTesting CSV Import...")
    print(f"Using file: {CSV_FILE}")
    
    headers = {
        "Authorization": f"Bearer {token}"
    }
    
    with open(CSV_FILE, 'rb') as f:
        files = {
            'file': (CSV_FILE, f, 'text/csv')
        }
        
        response = requests.post(
            f"{BASE_URL}/api/admin/stations/import-csv",
            headers=headers,
            files=files
        )
    
    if response.status_code != 200:
        print(f"\nImport failed: {response.status_code}")
        print(response.text)
        sys.exit(1)
    
    result = response.json()
    
    print("\n=== Import Results ===")
    print(f"Total Rows: {result['totalRows']}")
    print(f"Success: {result['successCount']}")
    print(f"Failed: {result['failureCount']}")
    
    print("\n=== Details ===")
    for item in result['results']:
        if item['success']:
            print(f"[OK] Row {item['rowNumber']}: {item['stationName']}")
            print(f"  Station ID: {item['stationId']}")
        else:
            print(f"[FAIL] Row {item['rowNumber']}: {item['stationName']}")
            print(f"  Error: {item['errorMessage']}")
    
    print("\nTest completed!")
    
    # Show full response
    print("\nFull Response:")
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()

