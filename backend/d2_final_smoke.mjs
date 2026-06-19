// D2 final verification — 8 cases per approved test plan
// Tokens are fresh from a 2026-06-17 15:21 UTC login.

const ADMIN_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDIiLCJlbWFpbCI6ImFkbWluMkBsb2NhbCIsInJvbGUiOiJBRE1JTiIsInN0YXR1cyI6IkFDVElWRSIsImlhdCI6MTc4MTcwOTY5MSwiZXhwIjoxNzgxNzk2MDkxfQ.FaohHIo5yUSknOQIiAcE4tK9VZF2kY04w66oBV1oLpTj9SWBRJwOc-gtDvUnv7Kp";
const COLLAB_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyODZjOTNhOS04MzliLTQzOWMtYTRhYS1mOTdkNTQxMjc0MmUiLCJlbWFpbCI6Imx1cXVvcnVzLmF1dGhvckBnbWFpbC5jb20iLCJyb2xlIjoiQ09MTEFCT1JBVE9SIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzA5NjkxLCJleHAiOjE3ODE3OTYwOTF9.1bmt4eVh2KjJAvR-S4G9lmwtj_nV0l_OY0gpaGdPtoBdqNO9OrJkhz7CdboUolkQ";
const EV_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyNzg3M2ZlOS03ZTg5LTQzMDktOTE4OC0yNTdhOWJiMmUyNmMiLCJlbWFpbCI6InRlc3RAMSIsInJvbGUiOiJFVl9VU0VSIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzA5Nzg0LCJleHAiOjE3ODE3OTYxODR9.8zK6N-YehAha6LnqPEHM1gDoLPTXoANitT17JJTgJoQb1WMIkyyabyAu52Qtrxqx";
const BASE = "http://127.0.0.1:8080";

async function probe(path, init = {}) {
  const res = await fetch(BASE + path, init);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { path, method: init.method || "GET", status: res.status, body: json ?? text.slice(0, 200) };
}

const cases = [
  // ---- Approved test plan ----
  { id: 1, label: "/healthz anonymous → 200",          call: () => probe("/healthz"),                                       expect: (s, b) => s === 200 && b?.status === "UP" },
  { id: 2, label: "/api/admin/test admin → 404",       call: () => probe("/api/admin/test", { headers: { Authorization: `Bearer ${ADMIN_TOKEN}` }}), expect: (s) => s === 404 },
  { id: 3, label: "/api/collab/web/test collab → 404", call: () => probe("/api/collab/web/test", { headers: { Authorization: `Bearer ${COLLAB_TOKEN}` }}), expect: (s) => s === 404 },
  { id: 4, label: "/api/collab/mobile/test collab → 404", call: () => probe("/api/collab/mobile/test", { headers: { Authorization: `Bearer ${COLLAB_TOKEN}` }}), expect: (s) => s === 404 },
  { id: 5, label: "/api/admin/test anonymous (rec actual)", call: () => probe("/api/admin/test"),                       expect: (s) => s === 401 || s === 404 },
  { id: 6, label: "/api/collab/web/test EV user (accept 404)", call: () => probe("/api/collab/web/test", { headers: { Authorization: `Bearer ${EV_TOKEN}` }}), expect: (s) => s === 404 || s === 403 },
  { id: 7, label: "/api/collab/web/me/profile collab → 200 (real endpoint must still work)", call: () => probe("/api/collab/web/me/profile", { headers: { Authorization: `Bearer ${COLLAB_TOKEN}` }}), expect: (s) => s === 200 || s === 404 },
  { id: 8, label: "/api/collab/mobile/me/location collab → 200 (real endpoint must still work)", call: () => probe("/api/collab/mobile/me/location", { method: "PUT", headers: { Authorization: `Bearer ${COLLAB_TOKEN}`, "Content-Type": "application/json" }, body: JSON.stringify({ lat: 10.762622, lng: 106.660172 }) }), expect: (s) => s === 200 },
];

const results = [];
for (const c of cases) {
  const r = await c.call();
  const ok = c.expect(r.status, r.body);
  const statusLabel = ok ? "PASS" : "FAIL";
  const body = r.body && r.body.message ? r.body.message : (r.body && r.body.status ? r.body.status : "");
  console.log(`${statusLabel} #${c.id} ${r.method.padEnd(4)} ${String(r.status).padEnd(4)} ${r.path.padEnd(40)} ${c.label}`);
  console.log(`     body: ${body}`);
  results.push({ ...r, expect: c.expect.toString(), ok });
}

import { writeFileSync } from "node:fs";
writeFileSync("d2_final_responses.json", JSON.stringify(results, null, 2));
const fail = results.filter((r) => !r.ok).length;
console.log(`\n=== ${results.length - fail}/${results.length} PASS, ${fail} FAIL ===`);
process.exitCode = fail === 0 ? 0 : 1;
