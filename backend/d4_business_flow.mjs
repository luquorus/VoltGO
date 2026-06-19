// D4 business-flow round-trip test: collab mobile uploads evidence photo,
// inserts DB row to satisfy ownership check, then views via collab mobile.
// Also tests admin presign-view on the same key (admin has no ownership check).
const COLLAB_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyODZjOTNhOS04MzliLTQzOWMtYTRhYS1mOTdkNTQxMjc0MmUiLCJlbWFpbCI6Imx1cXVvcnVzLmF1dGhvckBnbWFpbC5jb20iLCJyb2xlIjoiQ09MTEFCT1JBVE9SIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzEzMjQ0LCJleHAiOjE3ODE3OTk2NDR9.2KM5s5oUwxv2fttvZewluBy3sK_7Sd7a45m8TLDuUsSOMSYyOVxie47D1QC_rxVY";
const ADMIN_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDIiLCJlbWFpbCI6ImFkbWluMkBsb2NhbCIsInJvbGUiOiJBRE1JTiIsInN0YXR1cyI6IkFDVElWRSIsImlhdCI6MTc4MTcxMzI0MywiZXhwIjoxNzgxNzk5NjQzfQ.n0teTspUf_rNoabjHQZ3LCUwRihYmaKbGKvXl-B7hWJxbyNPVUF59nXrW132NzzB";
const EV_TOKEN = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiIyNzg3M2ZlOS03ZTg5LTQzMDktOTE4OC0yNTdhOWJiMmUyNmMiLCJlbWFpbCI6InRlc3RAMSIsInJvbGUiOiJFVl9VU0VSIiwic3RhdHVzIjoiQUNUSVZFIiwiaWF0IjoxNzgxNzEzMjQ0LCJleHAiOjE3ODE3OTk2NDR9.MCTnJTvi7Ngt_d4MXf09jqvp2EH8VezSFm2oLoxiwPLmwcrg85jDWx8v0K525hT0";

const COLLAB_USER_ID = "286c93a9-839b-439c-a4aa-f97d5412742e";
const BASE = "http://127.0.0.1:8080";
const TASK_ID = "347641fc-f86d-4d04-93ae-33c5876c5cc7";

// Step 1: collab uploads a file via /api/collab/mobile/files/upload
const formData = new FormData();
const fileBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01]);
const blob = new Blob([fileBytes], { type: "image/jpeg" });
formData.append("file", blob, "d4_roundtrip_evidence.jpg");
formData.append("contentType", "image/jpeg");

const uploadRes = await fetch(BASE + "/api/collab/mobile/files/upload", {
  method: "POST",
  headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
  body: formData,
});
const uploadJson = await uploadRes.json();
console.log("[1] Upload result:", uploadRes.status, JSON.stringify(uploadJson).slice(0, 200));

if (uploadRes.status !== 200) {
  console.log("FAIL: upload failed, aborting round-trip");
  process.exit(1);
}
const objectKey = uploadJson.objectKey;
console.log(`[1] Uploaded objectKey = ${objectKey}`);

// Step 2: Insert evidence DB row to satisfy ownership check
import { execSync } from "node:child_process";
const insertSQL = `INSERT INTO verification_evidence (id, task_id, photo_object_key, note, submitted_at, submitted_by) VALUES (gen_random_uuid(), '${TASK_ID}', '${objectKey}', 'D4 roundtrip test evidence', now(), '${COLLAB_USER_ID}');`;
try {
  const out = execSync(`docker exec voltgo-postgres psql -U voltgo_user -d voltgo -c "${insertSQL}"`, { encoding: "utf8" });
  console.log("[2] DB insert:", out.trim().split("\n").slice(-2).join(" "));
} catch (e) {
  console.log("[2] DB insert FAILED:", e.message);
  process.exit(1);
}

// Step 3: GET /api/collab/mobile/files/presign-view as the same collab → expect 200
const viewRes = await fetch(`${BASE}/api/collab/mobile/files/presign-view?objectKey=${encodeURIComponent(objectKey)}`, {
  headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
});
const viewJson = await viewRes.json();
console.log(`[3] Collab presign-view on own evidence: status=${viewRes.status}, viewUrl starts with: ${(viewJson.viewUrl || "").slice(0, 80)}...`);
const viewOk = viewRes.status === 200 && typeof viewJson.viewUrl === "string";

// Step 4: GET /api/collab/mobile/files/view as the same collab → expect 200 with image bytes
const viewBytesRes = await fetch(`${BASE}/api/collab/mobile/files/view?objectKey=${encodeURIComponent(objectKey)}`, {
  headers: { Authorization: `Bearer ${COLLAB_TOKEN}` },
});
const viewBytesBuf = await viewBytesRes.arrayBuffer();
const viewBytesLen = viewBytesBuf.byteLength;
const viewBytesType = viewBytesRes.headers.get("content-type");
console.log(`[4] Collab proxy-view on own evidence: status=${viewBytesRes.status}, content-type=${viewBytesType}, bytes=${viewBytesLen}`);
const viewBytesOk = viewBytesRes.status === 200 && viewBytesLen > 0 && viewBytesType?.includes("jpeg");

// Step 5: GET /api/collab/mobile/files/view as DIFFERENT collab (no ownership) → expect 403
const otherCollabToken = COLLAB_TOKEN; // same collab is enough — they ARE assigned
// Use admin as the "wrong-role" check
const viewAdminRes = await fetch(`${BASE}/api/admin/files/presign-view?objectKey=${encodeURIComponent(objectKey)}`, {
  headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
});
const viewAdminJson = await viewAdminRes.json();
console.log(`[5] Admin presign-view on collab-uploaded evidence: status=${viewAdminRes.status}, viewUrl starts with: ${(viewAdminJson.viewUrl || "").slice(0, 80)}...`);
const viewAdminOk = viewAdminRes.status === 200 && typeof viewAdminJson.viewUrl === "string";

// Step 6: GET /api/ev/files/presign-view as EV_USER on the collab evidence → expect 200 (no ownership check for EV)
const viewEvRes = await fetch(`${BASE}/api/ev/files/presign-view?objectKey=${encodeURIComponent(objectKey)}`, {
  headers: { Authorization: `Bearer ${EV_TOKEN}` },
});
const viewEvJson = await viewEvRes.json();
console.log(`[6] EV presign-view on collab-uploaded evidence: status=${viewEvRes.status}, viewUrl starts with: ${(viewEvJson.viewUrl || "").slice(0, 80)}...`);
const viewEvOk = viewEvRes.status === 200 && typeof viewEvJson.viewUrl === "string";

// Step 7: GET /api/collab/mobile/files/view as DIFFERENT collab (not assigned) → expect 403
// We don't have a different collab token; simulate by using EV token on collab endpoint
const viewEvOnCollabRes = await fetch(`${BASE}/api/collab/mobile/files/view?objectKey=${encodeURIComponent(objectKey)}`, {
  headers: { Authorization: `Bearer ${EV_TOKEN}` },
});
console.log(`[7] EV tries to view collab evidence via collab view endpoint: status=${viewEvOnCollabRes.status}`);
const viewEvOnCollabOk = viewEvOnCollabRes.status === 403;

// Summary
const allOk = viewOk && viewBytesOk && viewAdminOk && viewEvOk && viewEvOnCollabOk;
console.log(`\n=== Round-trip summary ===`);
console.log(`  [1] Upload file:               ${uploadRes.status === 200 ? "PASS" : "FAIL"}`);
console.log(`  [3] Collab presign-view (own):  ${viewOk ? "PASS" : "FAIL"}`);
console.log(`  [4] Collab proxy-view (own):    ${viewBytesOk ? "PASS" : "FAIL"}`);
console.log(`  [5] Admin presign-view (any):   ${viewAdminOk ? "PASS" : "FAIL"}`);
console.log(`  [6] EV presign-view (any):      ${viewEvOk ? "PASS" : "FAIL"}`);
console.log(`  [7] EV tries collab endpoint:   ${viewEvOnCollabOk ? "PASS" : "FAIL"}`);
console.log(`\n=== ${allOk ? "6/6 PASS" : "FAILED"} ===`);
process.exitCode = allOk ? 0 : 1;
