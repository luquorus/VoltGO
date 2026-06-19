// Probe D2 smoke-test endpoints with the right roles
const ADMIN_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDIiLCJlbWFpbCI6ImFkbWluMkBsb2NhbCIsInJvbGUiOiJBRE1JTiIsInN0YXR1cyI6IkFDVElWRSIsImlhdCI6MTc4MTcwNzQyMCwiZXhwIjoxNzgxNzkzODIwfQ.U2NQ70Xv8ZLmE9OIQabjQDpKhvR6_WHJKVsP-qT3a5Qc3uf86wx5Yx0n_LIOuJsP";
const COLLAB_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyODZjOTNhOS04MzliLTQzOWMtYTRhYS1mOTdkNTQxMjc0MmUiLCJlbWFpbCI6Imx1cXVvcnVzLmF1dGhvckBnbWFpbC5jb20iLCJyb2xlIjoiQ09MTEFCT1JBVE9SIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzA3OTg5LCJleHAiOjE3ODE3OTQzODl9.QFd1MdFwbkFYFKPkY2JHJVI3tt2zBkYQMHBDELuBfs7KtVY_VRqnN6Kb3i7-khyQ";
const EV_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyNzg3M2ZlOS03ZTg5LTQzMDktOTE4OC0yNTdhOWJiMmUyNmMiLCJlbWFpbCI6InRlc3RAMSIsInJvbGUiOiJFVl9VU0VSIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzA3OTg5LCJleHAiOjE3ODE3OTQzODl9.YYyWVUBNfaseg9ce7WaOFUYCJkpKay2g-ZOx6yGiyAvplNcF4YttBWOqFliNZusQ";
const BASE = "http://127.0.0.1:8080";

async function probe(path, init = {}) {
  const res = await fetch(BASE + path, init);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { path, method: init.method || "GET", status: res.status, body: json ?? text };
}

const probes = [
  // 1. Anonymous calls
  probe("/healthz"),
  probe("/api/admin/test"),
  probe("/api/collab/web/test"),
  probe("/api/collab/mobile/test"),
  // 2. Admin role
  probe("/api/admin/test", { headers: { Authorization: `Bearer ${ADMIN_TOKEN}` } }),
  probe("/api/collab/web/test", { headers: { Authorization: `Bearer ${ADMIN_TOKEN}` } }),
  probe("/api/collab/mobile/test", { headers: { Authorization: `Bearer ${ADMIN_TOKEN}` } }),
  // 3. Collaborator role
  probe("/api/admin/test", { headers: { Authorization: `Bearer ${COLLAB_TOKEN}` } }),
  probe("/api/collab/web/test", { headers: { Authorization: `Bearer ${COLLAB_TOKEN}` } }),
  probe("/api/collab/mobile/test", { headers: { Authorization: `Bearer ${COLLAB_TOKEN}` } }),
  // 4. EV user role
  probe("/api/admin/test", { headers: { Authorization: `Bearer ${EV_TOKEN}` } }),
  probe("/api/collab/web/test", { headers: { Authorization: `Bearer ${EV_TOKEN}` } }),
  probe("/api/collab/mobile/test", { headers: { Authorization: `Bearer ${EV_TOKEN}` } }),
];

const results = [];
for (const p of probes) {
  const r = await p;
  results.push(r);
  const role =
    r.body && r.body.message ? r.body.message :
    (r.body && r.body.status ? r.body.status : "");
  console.log(`${r.method.padEnd(5)} ${String(r.status).padEnd(4)} ${r.path.padEnd(35)} ${role}`);
}
import { writeFileSync } from "node:fs";
writeFileSync("d2_probe_responses.json", JSON.stringify(results, null, 2));
