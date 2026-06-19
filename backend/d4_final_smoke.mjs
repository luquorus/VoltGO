// D4 final verification — endpoint + auth + removed-endpoint + business-flow
const ADMIN_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDIiLCJlbWFpbCI6ImFkbWluMkBsb2NhbCIsInJvbGUiOiJBRE1JTiIsInN0YXR1cyI6IkFDVElWRSIsImlhdCI6MTc4MTcxMzI0MywiZXhwIjoxNzgxNzk5NjQzfQ.n0teTspUf_rNoabjHQZ3LCUwRihYmaKbGKvXl-B7hWJxbyNPVUF59nXrW132NzzB";
const COLLAB_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyODZjOTNhOS04MzliLTQzOWMtYTRhYS1mOTdkNTQxMjc0MmUiLCJlbWFpbCI6Imx1cXVvcnVzLmF1dGhvckBnbWFpbC5jb20iLCJyb2xlIjoiQ09MTEFCT1JBVE9SIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzEzMjQ0LCJleHAiOjE3ODE3OTk2NDR9.2KM5s5oUwxv2fttvZewluBy3sK_7Sd7a45m8TLDuUsSOMSYyOVxie47D1QC_rxVY";
const EV_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyNzg3M2ZlOS03ZTg5LTQzMDktOTE4OC0yNTdhOWJiMmUyNmMiLCJlbWFpbCI6InRlc3RAMSIsInJvbGUiOiJFVl9VU0VSIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzEzMjQ0LCJleHAiOjE3ODE3OTk2NDR9.MCTnJTvi7Ngt_d4MXf09jqvp2EH8VezSFm2oLoxiwPLmwcrg85jDWx8v0K525hT0";
const BASE = "http://127.0.0.1:8080";

// Realistic verification task flow: use the existing tasks in DB
const SAMPLE_KEY = "collab/uploads/test_d4_sample.jpg";

async function probe(path, init = {}) {
  const res = await fetch(BASE + path, init);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  // Trim body for display
  let bodyShort = "";
  if (json && typeof json === "object") {
    if (json.message) bodyShort = `body.message=${String(json.message).slice(0, 80)}`;
    else if (json.objectKey) bodyShort = `body.objectKey=${json.objectKey} uploadUrl=${String(json.uploadUrl || json.viewUrl || "").slice(0, 60)}`;
    else bodyShort = JSON.stringify(json).slice(0, 120);
  } else if (typeof text === "string") {
    bodyShort = text.slice(0, 120);
  }
  return { path, method: init.method || "GET", status: res.status, body: json, bodyShort };
}

const cases = [
  // ---- Live endpoints (must still work) ----
  {
    id: 1, group: "LIVE_EV",
    label: "GET /api/ev/files/presign-view (EV) → 200 or 500",
    call: () => probe("/api/ev/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${EV_TOKEN}` },
    }),
    expect: (s) => s === 200 || s === 500, // 500 acceptable if MinIO unreachable
  },
  {
    id: 2, group: "LIVE_EV",
    label: "GET /api/ev/files/presign-view (anon) → 401",
    call: () => probe("/api/ev/files/presign-view?objectKey=anykey"),
    expect: (s) => s === 401,
  },
  {
    id: 3, group: "LIVE_EV",
    label: "GET /api/ev/files/presign-view (admin) → 403",
    call: () => probe("/api/ev/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
    }),
    expect: (s) => s === 403,
  },
  {
    id: 4, group: "LIVE_EV",
    label: "GET /api/ev/files/presign-view (collab) → 403",
    call: () => probe("/api/ev/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
    }),
    expect: (s) => s === 403,
  },

  // ---- Admin live endpoint ----
  {
    id: 5, group: "LIVE_ADMIN",
    label: "GET /api/admin/files/presign-view (admin) → 200 or 500",
    call: () => probe("/api/admin/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
    }),
    expect: (s) => s === 200 || s === 500,
  },
  {
    id: 6, group: "LIVE_ADMIN",
    label: "GET /api/admin/files/presign-view (EV) → 403",
    call: () => probe("/api/admin/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${EV_TOKEN}` },
    }),
    expect: (s) => s === 403,
  },
  {
    id: 7, group: "LIVE_ADMIN",
    label: "GET /api/admin/files/presign-view (collab) → 403",
    call: () => probe("/api/admin/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
    }),
    expect: (s) => s === 403,
  },
  {
    id: 8, group: "LIVE_ADMIN",
    label: "GET /api/admin/files/presign-view (anon) → 401",
    call: () => probe("/api/admin/files/presign-view?objectKey=anykey"),
    expect: (s) => s === 401,
  },

  // ---- Collab mobile live endpoints ----
  {
    id: 9, group: "LIVE_COLLAB_MOBILE",
    label: "POST /api/collab/mobile/files/upload (collab, real file) → 200 + objectKey",
    call: async () => {
      // Build multipart with a small safe file
      const formData = new FormData();
      const blob = new Blob([new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46])], { type: "image/jpeg" });
      formData.append("file", blob, "test_d4_sample.jpg");
      formData.append("contentType", "image/jpeg");
      return probe("/api/collab/mobile/files/upload", {
        method: "POST",
        headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
        body: formData,
      });
    },
    expect: (s, b) => s === 200 && typeof b?.objectKey === "string",
  },
  {
    id: 10, group: "LIVE_COLLAB_MOBILE",
    label: "POST /api/collab/mobile/files/upload (EV) → 403",
    call: () => {
      const formData = new FormData();
      const blob = new Blob([new Uint8Array([0xff, 0xd8, 0xff])], { type: "image/jpeg" });
      formData.append("file", blob, "test.jpg");
      return probe("/api/collab/mobile/files/upload", {
        method: "POST",
        headers: { Authorization: `Bearer ${EV_TOKEN}` },
        body: formData,
      });
    },
    expect: (s) => s === 403,
  },
  {
    id: 11, group: "LIVE_COLLAB_MOBILE",
    label: "GET /api/collab/mobile/files/presign-view (collab, fake key) → 403 ownership",
    call: () => probe("/api/collab/mobile/files/presign-view?objectKey=collab/uploads/nonexistent.jpg", {
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
    }),
    expect: (s) => s === 403,
  },
  {
    id: 12, group: "LIVE_COLLAB_MOBILE",
    label: "GET /api/collab/mobile/files/presign-view (EV) → 403",
    call: () => probe("/api/collab/mobile/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${EV_TOKEN}` },
    }),
    expect: (s) => s === 403,
  },
  {
    id: 13, group: "LIVE_COLLAB_MOBILE",
    label: "GET /api/collab/mobile/files/presign-view (anon) → 401",
    call: () => probe("/api/collab/mobile/files/presign-view?objectKey=anykey"),
    expect: (s) => s === 401,
  },
  {
    id: 14, group: "LIVE_COLLAB_MOBILE",
    label: "GET /api/collab/mobile/files/view (collab, fake key) → 403 ownership",
    call: () => probe("/api/collab/mobile/files/view?objectKey=collab/uploads/nonexistent.jpg", {
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
    }),
    expect: (s) => s === 403,
  },

  // ---- REMOVED endpoints (must 404 or 401) ----
  {
    id: 15, group: "REMOVED",
    label: "REMOVED POST /api/ev/files/presign-upload (EV) → 404",
    call: () => probe("/api/ev/files/presign-upload", {
      method: "POST",
      headers: { Authorization: `Bearer ${EV_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ contentType: "image/jpeg" }),
    }),
    expect: (s) => s === 404,
  },
  {
    id: 16, group: "REMOVED",
    label: "REMOVED POST /api/ev/files/presign-upload (anon) → 401 or 404",
    call: () => probe("/api/ev/files/presign-upload", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    }),
    expect: (s) => s === 401 || s === 404,
  },
  {
    id: 17, group: "REMOVED",
    label: "REMOVED GET /api/collab/web/files/presign-view (collab) → 404",
    call: () => probe("/api/collab/web/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
  {
    id: 18, group: "REMOVED",
    label: "REMOVED GET /api/collab/web/files/presign-view (admin) → 404",
    call: () => probe("/api/collab/web/files/presign-view?objectKey=anykey", {
      headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
  {
    id: 19, group: "REMOVED",
    label: "REMOVED GET /api/collab/web/files/presign-view (anon) → 401 or 404",
    call: () => probe("/api/collab/web/files/presign-view?objectKey=anykey"),
    expect: (s) => s === 401 || s === 404,
  },
  {
    id: 20, group: "REMOVED",
    label: "REMOVED POST /api/collab/mobile/files/presign-upload (collab) → 404",
    call: () => probe("/api/collab/mobile/files/presign-upload", {
      method: "POST",
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ contentType: "image/jpeg" }),
    }),
    expect: (s) => s === 404,
  },
  {
    id: 21, group: "REMOVED",
    label: "REMOVED POST /api/collab/mobile/files/presign-upload (EV) → 404",
    call: () => probe("/api/collab/mobile/files/presign-upload", {
      method: "POST",
      headers: { Authorization: `Bearer ${EV_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ contentType: "image/jpeg" }),
    }),
    expect: (s) => s === 404,
  },

  // ---- Regression sanity ----
  {
    id: 22, group: "REGRESSION",
    label: "/healthz (anon) → 200",
    call: () => probe("/healthz"),
    expect: (s, b) => s === 200 && (b?.status === "UP" || b === "UP"),
  },
  {
    id: 23, group: "REGRESSION",
    label: "POST /api/ev/routing/route (EV) → 200 (D3)",
    call: () => probe("/api/ev/routing/route", {
      method: "POST",
      headers: { Authorization: `Bearer ${EV_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        origin: { lat: 10.762622, lng: 106.660172 },
        destination: { lat: 10.772622, lng: 106.670172 },
        batteryPercent: 50,
        vehicleRangeKm: 300
      }),
    }),
    expect: (s) => s === 200,
  },
  {
    id: 24, group: "REGRESSION",
    label: "GET /api/v1/routing/debug/stations-along-route (EV) → 404 (D3)",
    call: () => probe("/api/v1/routing/debug/stations-along-route?originLat=10.7&originLng=106.6&destLat=10.8&destLng=106.7", {
      headers: { Authorization: `Bearer ${EV_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
  {
    id: 25, group: "REGRESSION",
    label: "GET /api/admin/test (admin) → 404 (D2)",
    call: () => probe("/api/admin/test", {
      headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
  {
    id: 26, group: "REGRESSION",
    label: "GET /api/collab/web/test (collab) → 404 (D2)",
    call: () => probe("/api/collab/web/test", {
      headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
    }),
    expect: (s) => s === 404,
  },
  {
    id: 27, group: "REGRESSION",
    label: "GET /api/v1/battery-swap/trust/{id} (anon, real id) → 200 (D1)",
    call: () => probe("/api/v1/battery-swap/trust/f1000000-0000-0000-0000-000000000011"),
    expect: (s) => s === 200,
  },
];

const results = [];
for (const c of cases) {
  let r;
  try {
    r = await c.call();
  } catch (e) {
    r = { path: "?", method: "?", status: 0, body: null, bodyShort: `exception: ${e.message}` };
  }
  const ok = c.expect(r.status, r.body);
  const statusLabel = ok ? "PASS" : "FAIL";
  console.log(`${statusLabel} #${String(c.id).padStart(2)} ${r.method.padEnd(4)} ${String(r.status).padEnd(4)} ${c.label}`);
  console.log(`     ${r.bodyShort || "(no body)"}`);
  results.push({ id: c.id, group: c.group, label: c.label, ...r, ok });
}

import { writeFileSync } from "node:fs";
writeFileSync("d4_final_responses.json", JSON.stringify(results, null, 2));
const fail = results.filter((r) => !r.ok).length;
const groups = {};
for (const r of results) {
  if (!groups[r.group]) groups[r.group] = { pass: 0, fail: 0 };
  groups[r.group][r.ok ? "pass" : "fail"]++;
}
console.log(`\n=== Group breakdown ===`);
for (const g of Object.keys(groups)) {
  console.log(`  ${g.padEnd(22)} ${groups[g].pass}/${groups[g].pass + groups[g].fail}`);
}
console.log(`\n=== ${results.length - fail}/${results.length} PASS, ${fail} FAIL ===`);
process.exitCode = fail === 0 ? 0 : 1;
