// Detailed real-routing flow test — capture full response shape
const EV_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyNzg3M2ZlOS03ZTg5LTQzMDktOTE4OC0yNTdhOWJiMmUyNmMiLCJlbWFpbCI6InRlc3RAMSIsInJvbGUiOiJFVl9VU0VSIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzExMDgyLCJleHAiOjE3ODE3OTc0ODJ9.KgoLf8YIU9r0sqx_6Smz954dWY9wDFnbq78h-RsSikeN7F77WqtmF-7xycIFlQty";

const BASE = "http://127.0.0.1:8080";
const req = {
  origin: { lat: 10.762622, lng: 106.660172 },
  destination: { lat: 10.772622, lng: 106.670172 },
  batteryPercent: 50,
  vehicleRangeKm: 300
};

const res = await fetch(BASE + "/api/ev/routing/route", {
  method: "POST",
  headers: { Authorization: `Bearer ${EV_TOKEN}`, "Content-Type": "application/json" },
  body: JSON.stringify(req),
});
const json = await res.json();
console.log("Status:", res.status);
console.log("Response keys:", Object.keys(json).sort().join(", "));
console.log("distanceMeters:", json.distanceMeters);
console.log("durationSeconds:", json.durationSeconds);
console.log("polyline.length:", json.polyline?.length);
console.log("first 3 polyline points:", JSON.stringify(json.polyline?.slice(0, 3)));
console.log("recommendedStations.length:", json.recommendedStations?.length);
console.log("needsChargingStop:", json.needsChargingStop);
console.log("optimalStation:", json.optimalStation ? "present" : "null");
console.log("remainingRangeKm:", json.remainingRangeKm);
console.log("routeDistanceKm:", json.routeDistanceKm);
console.log("summary keys:", json.summary ? Object.keys(json.summary).sort().join(", ") : "missing");
console.log("summary.distanceKm:", json.summary?.distanceKm);
console.log("summary.durationMinutes:", json.summary?.durationMinutes);
console.log("boundingBox:", JSON.stringify(json.boundingBox));

// Verify frontend model fields are all present
const frontendExpectedFields = [
  "distanceMeters",
  "durationSeconds",
  "polyline",
  "recommendedStations",
  "optimalStation",
  "needsChargingStop",
];
const missing = frontendExpectedFields.filter((f) => !(f in json));
console.log("\nMissing frontend-required fields:", missing.length ? missing : "NONE — all fields present");

import { writeFileSync } from "node:fs";
writeFileSync("d3_real_routing_response.json", JSON.stringify(json, null, 2));
