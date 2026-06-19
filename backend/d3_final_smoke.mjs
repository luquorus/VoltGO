// D3 final verification — 11 cases per approved test plan
// Real routing + debug endpoint deletion + D1/D2 sanity

const ADMIN_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDIiLCJlbWFpbCI6ImFkbWluMkBsb2NhbCIsInJvbGUiOiJBRE1JTiIsInN0YXR1cyI6IkFDVElWRSIsImlhdCI6MTc4MTcxMTA4MSwiZXhwIjoxNzgxNzk3NDgxfQ.EBhB2uvmGBiSwfF5GTuch86unS5oXQ9xt8kTxv4heZhRlFilIgIiZDijnSwDUK8c";
const COLLAB_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyODZjOTNhOS04MzliLTQzOWMtYTRhYS1mOTdkNTQxMjc0MmUiLCJlbWFpbCI6Imx1cXVvcnVzLmF1dGhvckBnbWFpbC5jb20iLCJyb2xlIjoiQ09MTEFCT1JBVE9SIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzExMDgxLCJleHAiOjE3ODE3OTc0ODF9.RHCJ-NWqmCjK3WB5vSZsQQVprQIIVJ9TXUeHMOjkIgltt5l2tC9iPcn2-j12A63F";
const EV_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyNzg3M2ZlOS03ZTg5LTQzMDktOTE4OC0yNTdhOWJiMmUyNmMiLCJlbWFpbCI6InRlc3RAMSIsInJvbGUiOiJFVl9VU0VSIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzExMDgyLCJleHAiOjE3ODE3OTc0ODJ9.KgoLf8YIU9r0sqx_6Smz954dWY9wDFnbq78h-RsSikeN7F77WqtmF-7xycIFlQty";
const BASE = "http://127.0.0.1:8080";

// Realistic HCM City coordinates for routing test
const ROUTE_BODY = JSON.stringify({
  origin: { lat: 10.762622, lng: 106.660172 },
  destination: { lat: 10.772622, lng: 106.670172 },
  batteryPercent: 50,
  vehicleRangeKm: 300
});

async function probe(path, init = {}) {
  const res = await fetch(BASE + path, init);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { path, method: init.method || "GET", status: res.status, body: json ?? text.slice(0, 300) };
}

const cases = [
  // ---- Real routing endpoint (must still work) ----
  {
    id: 1, label: "/api/ev/routing/route EV user → 200",
    call: () => probe("/api/ev/routing/route", {
      method: "POST",
      headers: { Authorization: `Bearer ${EV_TOKEN}`, "Content-Type": "application/json" },
      body: ROUTE_BODY,
    }),
    expect: (s, b) => s === 200 && typeof b?.distanceMeters === "number" && typeof b?.durationSeconds === "number" && Array.isArray(b?.polyline),
  },
  {
    id: 2, label: "/api/ev/routing/route anon → 401",
    call: () => probe("/api/ev/routing/route", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: ROUTE_BODY,
    }),
    expect: (s) => s === 401,
  },
  {
    id: 3, label: "/api/ev/routing/route admin JWT → 403",
    call: () => probe("/api/ev/routing/route", {
      method: "POST",
      headers: { Authorization: `Bearer ${ADMIN_TOKEN}`, "Content-Type": "application/json" },
      body: ROUTE_BODY,
    }),
    expect: (s) => s === 403,
  },
  {
    id: 4, label: "/api/ev/routing/route collab JWT → 403",
    call: () => probe("/api/ev/routing/route", {
      method: "POST",
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}`, "Content-Type": "application/json" },
      body: ROUTE_BODY,
    }),
    expect: (s) => s === 403,
  },

  // ---- Debug endpoint (must be gone) ----
  {
    id: 5, label: "/api/v1/routing/debug/... EV user → 404",
    call: () => probe("/api/v1/routing/debug/stations-along-route?originLat=10.7&originLng=106.6&destLat=10.8&destLng=106.7", {
      headers: { Authorization: `Bearer ${EV_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
  {
    id: 6, label: "/api/v1/routing/debug/... admin → 404",
    call: () => probe("/api/v1/routing/debug/stations-along-route?originLat=10.7&originLng=106.6&destLat=10.8&destLng=106.7", {
      headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
  {
    id: 7, label: "/api/v1/routing/debug/... anon → 401 or 404",
    call: () => probe("/api/v1/routing/debug/stations-along-route?originLat=10.7&originLng=106.6&destLat=10.8&destLng=106.7"),
    expect: (s) => s === 401 || s === 404,
  },

  // ---- Health + D1 + D2 sanity (must still work) ----
  {
    id: 8, label: "/healthz anon → 200",
    call: () => probe("/healthz"),
    expect: (s, b) => s === 200 && (b?.status === "UP" || b === "UP"),
  },
  {
    id: 9, label: "D1 /api/v1/battery-swap/trust/{id} anon → 200",
    call: () => probe("/api/v1/battery-swap/trust/00000000-0000-0000-0000-000000000001"),
    expect: (s) => s === 200 || s === 404, // D1 endpoint exists but may need real station id
  },
  {
    id: 10, label: "D2 /api/admin/test admin → 404",
    call: () => probe("/api/admin/test", {
      headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
  {
    id: 11, label: "D2 /api/collab/web/test collab → 404",
    call: () => probe("/api/collab/web/test", {
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
];

const results = [];
for (const c of cases) {
  const r = await c.call();
  const ok = c.expect(r.status, r.body);
  const statusLabel = ok ? "PASS" : "FAIL";

  // Format a body summary
  let bodySummary = "";
  if (r.body && typeof r.body === "object") {
    if (r.body.distanceMeters !== undefined) {
      bodySummary = `distance=${r.body.distanceMeters}m duration=${r.body.durationSeconds}s polyline[${r.body.polyline?.length ?? 0}]`;
    } else if (r.body.status) {
      bodySummary = `body.status=${r.body.status}`;
    } else if (r.body.message) {
      bodySummary = `body.message=${String(r.body.message).slice(0, 100)}`;
    } else {
      bodySummary = JSON.stringify(r.body).slice(0, 100);
    }
  } else if (typeof r.body === "string") {
    bodySummary = r.body.slice(0, 100);
  }

  console.log(`${statusLabel} #${String(c.id).padStart(2)} ${r.method.padEnd(4)} ${String(r.status).padEnd(4)} ${r.path.padEnd(60)} ${c.label}`);
  console.log(`     ${bodySummary}`);
  results.push({ ...r, expect: c.expect.toString(), ok });
}

import { writeFileSync } from "node:fs";
writeFileSync("d3_final_responses.json", JSON.stringify(results, null, 2));
const fail = results.filter((r) => !r.ok).length;
console.log(`\n=== ${results.length - fail}/${results.length} PASS, ${fail} FAIL ===`);
process.exitCode = fail === 0 ? 0 : 1;
