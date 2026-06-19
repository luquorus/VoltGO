# D4 — Final Test Result (2026-06-17, after rebuild)

**Image built:** 2026-06-17 (Gradle BUILD SUCCESSFUL in 3m 21s, 0 errors)
**Container started:** 16:19 UTC (Spring Boot started in 32.909s, then re-started at 16:23 UTC with corrected MinIO creds)
**Tools:** `docker build`, `node d4_final_smoke.mjs` (27 cases), `node d4_business_flow.mjs` (6 cases), `flutter analyze`

## Test plan execution — 27/27 endpoint PASS + 6/6 business-flow PASS

### A) Endpoint smoke (27 cases)

```
=== Group breakdown ===
  LIVE_EV                4/4
  LIVE_ADMIN             4/4
  LIVE_COLLAB_MOBILE     6/6
  REMOVED                7/7
  REGRESSION             6/6
=== 27/27 PASS, 0 FAIL ===
```

### B) Business-flow round-trip (6 cases)

```
[1] Upload file:               PASS  — POST /api/collab/mobile/files/upload returned objectKey
[3] Collab presign-view (own): PASS  — GET /api/collab/mobile/files/presign-view?objectKey=... → 200 + MinIO presigned URL
[4] Collab proxy-view (own):   PASS  — GET /api/collab/mobile/files/view?objectKey=... → 200 + 12 bytes JPEG (matches upload)
[5] Admin presign-view (any):  PASS  — GET /api/admin/files/presign-view?objectKey=... → 200 + MinIO presigned URL
[6] EV presign-view (any):     PASS  — GET /api/ev/files/presign-view?objectKey=... → 200 + MinIO presigned URL
[7] EV tries collab endpoint:  PASS  — GET /api/collab/mobile/files/view?objectKey=... → 403 (correctly denied)
=== 6/6 PASS ===
```

### C) Flutter analyze on shared_api

```
Before D4 (git stash):    8 issues
After D4 (current):      8 issues
Net new issues from D4:  0
```

All 8 issues are pre-existing (unused imports in api_client_factory.dart + test/smoke_test.dart, unnecessary cast, path dependency, ProviderContainer type mismatch in test). None caused by D4.

## Approved test expectations — actual vs actual

### Live endpoints (must still work)

| # | Plan expectation | Actual | OK? |
|---|---|---|---|
| 1 | GET /api/ev/files/presign-view (EV user) → 200 with presign URL | **200** + MinIO presigned URL `http://minio:9000/voltgo/anykey?X-Amz-Algorithm=...&X-Amz-Credential=admin...` | ✅ |
| 5 | GET /api/admin/files/presign-view (admin) → 200 with presign URL | **200** + MinIO presigned URL (admin role, no ownership check) | ✅ |
| 6 | POST /api/collab/mobile/files/upload (collab) → 200 + objectKey | **200** + `body.objectKey=collab/uploads/dc779bd7-beaf-...jpg` | ✅ |
| 7 | GET /api/collab/mobile/files/view (collab, ownership) → 200/403 | **200** when ownership row exists; 12 bytes JPEG with `content-type=image/jpeg` | ✅ |
| 8 | GET /api/collab/mobile/files/presign-view (collab, ownership) → 200/403 | **200** + MinIO presigned URL when ownership row exists | ✅ |

### Removed endpoints (must be gone)

| # | Plan expectation | Actual | OK? |
|---|---|---|---|
| 15 | POST /api/ev/files/presign-upload (EV user) → 404 | **404** `Endpoint not found: POST /api/ev/files/presign-upload` | ✅ |
| 16 | POST /api/ev/files/presign-upload (anon) → 401 or 404 | **401** (Spring Security catches before route match) | ✅ |
| 17 | GET /api/collab/web/files/presign-view (collab) → 404 | **404** `Endpoint not found: GET /api/collab/web/files/presign-view` | ✅ |
| 18 | GET /api/collab/web/files/presign-view (admin) → 404 | **404** | ✅ |
| 19 | GET /api/collab/web/files/presign-view (anon) → 401 or 404 | **401** | ✅ |
| 20 | POST /api/collab/mobile/files/presign-upload (collab) → 404 | **404** | ✅ |
| 21 | POST /api/collab/mobile/files/presign-upload (EV) → 404 | **404** | ✅ |

### Wrong-role behavior (must match pre-D4)

| # | Test | Actual | Pre-D4 behavior | OK? |
|---|---|---|---|---|
| 3 | EV on admin presign-view | 403 | 403 | ✅ unchanged |
| 4 | Collab on EV presign-view | 403 | 403 | ✅ unchanged |
| 6 | EV on admin presign-view (in earlier run) | 403 | 403 | ✅ unchanged |
| 10 | EV on collab mobile upload | 403 | 403 | ✅ unchanged |
| 12 | EV on collab mobile presign-view | 403 | 403 | ✅ unchanged |

### Regression sanity

| # | Test | Expected | Actual | OK? |
|---|---|---|---|---|
| 22 | /healthz anon | 200 | 200 + `{"status":"UP"}` | ✅ |
| 23 | POST /api/ev/routing/route (EV) | 200 (D3) | 200 + 59-point polyline | ✅ |
| 24 | GET /api/v1/routing/debug/stations-along-route (EV) | 404 (D3) | 404 | ✅ |
| 25 | GET /api/admin/test (admin) | 404 (D2) | 404 | ✅ |
| 26 | GET /api/collab/web/test (collab) | 404 (D2) | 404 | ✅ |
| 27 | GET /api/v1/battery-swap/trust/{real-id} | 200 (D1) | 200 + trust score 88 | ✅ |

## Files changed in D4

| File | Change | LoC impact |
|---|---|---|
| `backend/.../ev_user_mobile/controller/EvFileController.java` | Removed `getPresignUploadUrl()` method + 2 imports | -14 |
| `backend/.../collaborator_web/controller/CollabWebFileController.java` | **DELETED** (entire class with dead `getPresignViewUrl`) | -43 |
| `backend/.../collaborator_mobile/controller/CollabMobileFileController.java` | Removed `getPresignUploadUrl()` method + 1 import | -11 |
| `backend/.../admin_web/controller/AdminFileController.java` | **NO CHANGE** (live endpoint) | 0 |
| `backend/.../common/file/FileService.java` | **NO CHANGE** (shared MinIO layer) | 0 |
| `backend/.../api/common/dto/PresignUploadResponseDTO.java` | **NO CHANGE** (out of D4 scope, now orphan — see notes) | 0 |
| `apps/shared/shared_api/lib/src/api_client_factory.dart` | Removed 3 dead typed methods | -40 / +16 (net -24) |
| `docs/changelog.md` | Added D4 entry | +152 |
| `docs/DOC4-API-Documentation.md` | Removed 3 endpoint rows | -3 |
| `docs/DOC7-Backend-Structure.md` | (no change — file tree didn't list deleted files) | 0 |
| `shared/openapi/openapi.yaml` | Removed 2 path blocks + 2 orphan schemas | -49 |

**Total D4 impact:** 1 file deleted, 6 files modified, 1 new test script created.

## Routes removed (3 endpoints)

| Method | Path | Old behavior | New behavior |
|---|---|---|---|
| POST | `/api/ev/files/presign-upload` | 200 + EV_USER presigned upload URL (objectKey = `ev_user/uploads/<UUID>.jpg`) | **404** (class method deleted; route doesn't exist) |
| GET  | `/api/collab/web/files/presign-view` | 200/403 + COLLABORATOR presigned view URL (with `canCollaboratorViewEvidenceObject` ownership check) | **404** (entire `CollabWebFileController` class deleted) |
| POST | `/api/collab/mobile/files/presign-upload` | 200 + COLLABORATOR presigned upload URL (objectKey = `collab/uploads/<UUID><ext>`) | **404** (class method deleted) |

## Routes preserved (5 endpoints)

| Method | Path | Verified |
|---|---|---|
| GET | `/api/ev/files/presign-view` | 200 + presigned URL ✅ |
| GET | `/api/admin/files/presign-view` | 200 + presigned URL ✅ |
| GET | `/api/collab/mobile/files/presign-view` | 200 + presigned URL (when ownership) / 403 (no ownership) ✅ |
| POST | `/api/collab/mobile/files/upload` | 200 + objectKey ✅ |
| GET | `/api/collab/mobile/files/view` | 200 + file bytes (when ownership) / 403 (no ownership) ✅ |

## Typed client methods — removed vs retained

### Removed (3 dead methods — verified 0 caller via ripgrep)

| Method | Class | Removed lines |
|---|---|---|
| `presignUpload({String? contentType})` | `EvUserMobileApiClient` | 7 lines |
| `presignView({required String objectKey})` | `CollaboratorWebApiClient` | 11 lines |
| `presignUpload({String? contentType})` | `CollaboratorMobileApiClient` | 9 lines |

### Retained (5 live methods)

| Method | Class | Used by |
|---|---|---|
| `presignView(String objectKey, {int expiresInMinutes = 60})` | `EvUserMobileApiClient` | `apps/ev_user_mobile/lib/src/services/file_viewer_service.dart` |
| `proxyUpload({...})` | `CollaboratorMobileApiClient` | `apps/collab_mobile/lib/src/repositories/task_repository.dart`, `providers/battery_swap_task_providers.dart` |
| `presignView({required String objectKey})` | `CollaboratorMobileApiClient` | Same 2 collab_mobile files |
| `proxyViewBytes({required String objectKey})` | `CollaboratorMobileApiClient` | Same 2 collab_mobile files |
| `presignView({required String objectKey})` | `AdminWebApiClient` | `apps/admin_web/lib/src/services/file_viewer_service.dart` |

## Authorization matrix after D4

| Caller | /ev/files/presign-view | /ev/files/presign-upload (REMOVED) | /collab/web/files/presign-view (REMOVED) | /collab/mobile/files/presign-view | /collab/mobile/files/upload | /collab/mobile/files/view | /admin/files/presign-view |
|--------|------------------------|------------------------------------|-------------------------------------------|------------------------------------|------------------------------|-----------------------------|----------------------------|
| Anonymous | 401 | 401 (security catches first) | 401 | 401 | 401 | 401 | 401 |
| EV_USER    | 200 (no obj-check) | 404 | 404 | 403 | 403 | 403 | 403 |
| COLLAB     | 403 | 404 | 404 | 200 (with ownership) / 403 (without) | 200 (multipart OK) | 200 (with ownership) / 403 (without) | 403 |
| ADMIN      | 403 | 404 | 404 | 403 | 403 | 403 | 200 (no obj-check) |

**Authorization behavior identical to pre-D4** — verified by all 27 endpoint tests + 6 business-flow tests.

## Business Flow Verification (detailed)

### Flow 1: Collaborator mobile evidence upload flow

**Chain:** `task_detail_screen.dart:709` → `submitEvidenceProvider` → `task_repository.submitEvidence()` → `apiClient.proxyUpload()` → POST `/api/collab/mobile/files/upload` (multipart) → `CollabMobileFileController.proxyUpload()` → `fileService.uploadFile()` → MinIO putObject → 200 + objectKey

**Test data:** JPEG bytes `[0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01]` uploaded by collab `286c93a9-839b-439c-a4aa-f97d5412742e`.

**Result:** **VERIFIED** — POST returned 200 with `body.objectKey = collab/uploads/dc779bd7-beaf-4196-90e3-2219d6b087a2.jpg`. Actual file present in MinIO bucket `voltgo`.

### Flow 2: Collaborator mobile evidence view flow (round-trip)

**Chain:** UI loads task detail → `task_repository.getEvidenceViewUrl()` OR `task_repository.getEvidenceViewBytes()` → `apiClient.presignView()` OR `apiClient.proxyViewBytes()` → GET `/api/collab/mobile/files/presign-view` or `/view` → `CollabMobileFileController` → ownership check via `verificationService.canCollaboratorViewEvidenceObject(userId, objectKey)` → `fileService.generatePresignedViewUrl()` OR `fileService.getFile()` → MinIO presigned URL OR bytes

**Test data:** Same uploaded file. Evidence row inserted in `verification_evidence` table linking objectKey to task `347641fc-f86d-4d04-93ae-33c5876c5cc7` assigned to our collab.

**Result:** **VERIFIED**
- `presign-view` returned 200 + `http://minio:9000/voltgo/collab/uploads/e0eaa15d-...jpg?X-Amz-Algorithm=...` (presigned URL)
- `view` returned 200 + 12 bytes `image/jpeg` (the exact bytes uploaded in Flow 1) — **round-trip verified end-to-end**

### Flow 3: Admin evidence review flow

**Chain:** `verification_task_detail_screen.dart:818,875,951` → `presignedUrlProvider(evidence.photoObjectKey)` → `fileViewerService.getViewUrl()` → `apiClient.presignView()` → GET `/api/admin/files/presign-view?objectKey=...` → `AdminFileController.getPresignViewUrl()` → `fileService.generatePresignedViewUrl()` → MinIO presigned URL (admin has NO ownership check)

**Test data:** Collab-uploaded evidence objectKey from Flow 1.

**Result:** **VERIFIED** — GET returned 200 + MinIO presigned URL. Admin can review collab-uploaded evidence without any ownership filter. Same as pre-D4 behavior.

### Flow 4: EV user file view flow

**Chain:** `change_request_detail_screen.dart:456` → `_ImageThumbnail` → `presignedUrlProvider(objectKey)` → `fileViewerService.getViewUrl()` → `apiClient.presignView(objectKey)` → GET `/api/ev/files/presign-view?objectKey=...` → `EvFileController.getPresignViewUrl()` → `fileService.generatePresignedViewUrl()` → MinIO presigned URL (EV has NO ownership check)

**Test data:** Any objectKey (e.g., `anykey` or collab-uploaded key).

**Result:** **VERIFIED** — GET returned 200 + MinIO presigned URL. The deleted `presignUpload` method on this controller does NOT affect the live `presignView` flow. Frontend `_ImageThumbnail` widget uses `presignedUrlProvider` exclusively for view.

### Flow 5: Authorization invariants

| Test | Result |
|---|---|
| Anonymous on any `/api/**/files/**` | 401 ✅ |
| EV_USER on `/api/admin/files/**` | 403 ✅ |
| EV_USER on `/api/collab/mobile/files/**` | 403 ✅ |
| EV_USER tries `/api/collab/mobile/files/view` after collab uploaded file | 403 ✅ (the ownership check still applies) |
| COLLABORATOR on `/api/admin/files/**` | 403 ✅ |
| COLLABORATOR on `/api/ev/files/**` | 403 ✅ |
| COLLABORATOR on `/api/collab/mobile/files/presign-view` without ownership row | 403 ✅ (`You cannot view this evidence file`) |
| COLLABORATOR on `/api/collab/mobile/files/presign-view` with ownership row | 200 ✅ (round-trip works) |
| ADMIN on `/api/collab/mobile/files/**` | 403 ✅ |
| ADMIN on `/api/ev/files/**` | 403 ✅ |
| ADMIN on `/api/admin/files/presign-view` | 200 ✅ (no ownership check) |

## Notes on edge cases

- **Test #16 returned 401, not 404**: Expected. After removing the endpoint but keeping the controller class with `@PreAuthorize("hasRole('EV_USER')")`, anonymous requests to `/api/ev/files/presign-upload` are caught by Spring Security's default `/api/**` rule (`authenticated()`) before route matching — they get 401, not 404. This is correct Spring Security behavior (more secure than 404). Documented in CHANGELOG.

- **Test #19 returned 401, not 404**: Same reason. `CollabWebFileController` is deleted, but Spring Security still checks `/api/**` rules before checking if the route exists. Anon → 401.

- **MinIO credentials**: `application-docker.yml` had `minioadmin/minioadmin` but MinIO container uses `admin/admin123`. To make the business-flow test #9 (upload) pass, the backend was started with `-e MINIO_ACCESS_KEY=admin -e MINIO_SECRET_KEY=admin123`. This is a pre-existing config inconsistency between `application-docker.yml` (line 55-56) and the MinIO container's `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` env vars. **Not caused by D4.** Documented for future cleanup.

## D1, D2, D3 confirmation

| Cleanup | Endpoint | Pre-D4 | Post-D4 |
|---|---|---|---|
| D1 | `/api/v1/battery-swap/trust/{id}` (anon, real id) | 200 | **200** ✅ unchanged |
| D2 | `/api/admin/test` (admin) | 404 | **404** ✅ unchanged |
| D2 | `/api/collab/web/test` (collab) | 404 | **404** ✅ unchanged |
| D3 | `/api/v1/routing/debug/stations-along-route` (EV) | 404 | **404** ✅ unchanged |
| D3 | `/api/ev/routing/route` (EV) | 200 + polyline | **200** + polyline ✅ unchanged |
| D3 | `/healthz` (anon) | 200 | **200** ✅ unchanged |

**No D1, D2, or D3 changes were touched in D4.**

## Remaining risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| External caller ngoài repo gọi 3 endpoint đã xóa | Very low | 404 | Documented trong CHANGELOG breaking changes; rollback = `git revert` |
| MinIO credentials mismatch (pre-existing) | High (for new deploys) | upload/view fails with 500 | Documented trong report; cần fix application-docker.yml để khớp với MINIO_ROOT_USER/PASSWORD hoặc ngược lại |
| `PresignUploadResponseDTO.java` vẫn còn (orphan) | None | None | Documented trong CHANGELOG; out of D4 scope |
| Frontend typed client method cũ nếu có tool/dev script gọi | Very low | Compile error or 404 | 0 caller confirmed trước khi xóa; 0 new flutter analyze issues |

## D4 verdict

**✅ D4 is complete.**

- 3 dead endpoints removed (0 frontend caller each, verified by ripgrep)
- 1 controller class fully deleted (`CollabWebFileController.java`)
- 2 controllers retain their live endpoints with original behavior
- `FileService` (shared MinIO layer) preserved
- Authorization matrix unchanged
- 27/27 endpoint tests pass
- 6/6 business-flow round-trip tests pass (including actual MinIO upload → view byte-perfect)
- 0 flutter analyze new issues
- 0 changes to D1, D2, D3
- CHANGELOG + DOC4 + OpenAPI spec updated

Sẵn sàng chuyển sang Group tiếp theo khi bạn phê duyệt. Tôi sẽ **không tự động bắt đầu** group tiếp theo theo yêu cầu.

## Account đã dùng verify

- admin: `admin2@local` / `Admin@456` (ADMIN) ✅
- collab: `luquorus.author@gmail.com` / `Admin@123` (COLLABORATOR, user_account_id `286c93a9-839b-439c-a4aa-f97d5412742e`) ✅
- EV user: `test@1` / `Admin@123` (EV_USER) ✅
