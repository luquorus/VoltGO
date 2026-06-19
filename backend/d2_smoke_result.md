# D2 — Final Test Result (2026-06-17, after rebuild)

**Image built:** 2026-06-17 (Gradle compile 156.5s, 0 errors)
**Container started:** 15:21 UTC (Spring Boot started in 41.191s)
**Tools:** `docker build`, `node d2_final_smoke.mjs`, `curl.exe`

## Test plan execution — 8/8 PASS

```
PASS #1 GET  200  /healthz                                 /healthz anonymous → 200
     body: UP
PASS #2 GET  404  /api/admin/test                          /api/admin/test admin → 404
     body: Endpoint not found: GET /api/admin/test
PASS #3 GET  404  /api/collab/web/test                     /api/collab/web/test collab → 404
     body: Endpoint not found: GET /api/collab/web/test
PASS #4 GET  404  /api/collab/mobile/test                  /api/collab/mobile/test collab → 404
     body: Endpoint not found: GET /api/collab/mobile/test
PASS #5 GET  401  /api/admin/test                          /api/admin/test anonymous (rec actual)
     body: Unauthorized: Full authentication is required to access this resource
PASS #6 GET  404  /api/collab/web/test                     /api/collab/web/test EV user (accept 404)
     body: Endpoint not found: GET /api/collab/web/test
PASS #7 GET  200  /api/collab/web/me/profile               /api/collab/web/me/profile collab → 200 (real endpoint must still work)
     body: (empty — JSON body)
PASS #8 PUT  200  /api/collab/mobile/me/location           /api/collab/mobile/me/location collab → 200 (real endpoint must still work)
     body: (empty — JSON body)

=== 8/8 PASS, 0 FAIL ===
```

All 8 cases pass with the corrected expectations from the user's approval:

| # | Plan expectation | Actual | OK? |
|---|---|---|---|
| 1 | /healthz anonymous → 200 {"status":"UP"} | 200 + body "UP" | ✅ |
| 2 | /api/admin/test admin → 404 | 404 | ✅ |
| 3 | /api/collab/web/test collab → 404 | 404 | ✅ |
| 4 | /api/collab/mobile/test collab → 404 | 404 | ✅ |
| 5 | /api/admin/test anonymous → 401 hoặc 404 | 401 (Spring Security chặn /api/** trước route match) | ✅ |
| 6 | /api/collab/web/test EV user → 404 OK | 404 | ✅ |
| 7 | /api/collab/web/me/profile collab → 200 (real endpoint phải còn) | 200 | ✅ |
| 8 | /api/collab/mobile/me/location collab → 200 (real endpoint phải còn) | 200 | ✅ |

## Account tokens used (issued 2026-06-17 ~15:21 UTC, valid until 15:21 UTC +24h)

- **admin**: `admin2@local` / `Admin@456` — role `ADMIN`, userId `00000000-0000-0000-0000-000000000002`
- **collab**: `luquorus.author@gmail.com` / `Admin@123` — role `COLLABORATOR`, userId `286c93a9-839b-439c-a4aa-f97d5412742e`
- **EV user**: `test@1` / `Admin@123` — role `EV_USER`, userId `27873fe9-7e89-4309-9188-257a9bb2e26c`

All 3 accounts in DB have status `ACTIVE`.

## Notes

- The 401 in test #5 (anonymous) is correct — Spring Security's `SecurityConfig` has `requestMatchers("/api/**").authenticated()` before any controller is matched, so anonymous requests to /api/** are rejected with 401. The 3 deleted endpoints never get a chance to return their static "API is accessible" string.
- Test #8 (`PUT /api/collab/mobile/me/location`) sent a real GPS coordinate (lat=10.762622, lng=106.660172 — HCM City area) and got 200, confirming the real endpoint still works end-to-end with a valid collaborator JWT.

## Scene / flow / caller analysis — ZERO callers

The brief asked specifically: *"Test api và list cho tôi những scene nào call api này, tính năng, flow nào vào trong file result."*

**Result: no scene, no flow, no test, no script, no UI in the entire VoltGO repository calls the 3 deleted `/test` endpoints.** Detailed grep evidence below:

| Search target | Pattern | Files matched | Notes |
|---|---|---|---|
| Path strings | `/api/admin/test` | 5 files, all D2 working files + changelog (1 entry) | No app caller. |
| Path strings | `/api/collab/web/test` | 5 files, all D2 working files + changelog (1 entry) | No app caller. |
| Path strings | `/api/collab/mobile/test` | 5 files, all D2 working files + changelog (1 entry) | No app caller. |
| Variable names | `isAdminWebApiAccessible\|isCollabWebApiAccessible\|isCollabMobileApiAccessible\|adminTest\|webTest\|mobileTest` | 0 | No caller by name. |
| Typed client calls | `admin.test(\|collabWeb.test(\|collabMobile.test(\|api.test(` | 0 | No typed client method exists; no caller. |
| D1.4 caller analysis | full repo `rg` Step 2.1 | 0 | (See D2 Step 2.1 output in the conversation.) |

The 3 endpoints existed as **class-level "API is accessible" smoke pings** that the development team apparently used during initial endpoint setup but never wired into any client, repository, provider, screen, or test. They were dead weight from day one.

## Files changed in D2

| File | Change | LoC impact |
|---|---|---|
| `backend/src/main/java/com/example/evstation/api/admin_web/controller/AdminWebController.java` | DELETED | -25 |
| `backend/src/main/java/com/example/evstation/api/collaborator_web/controller/CollaboratorWebController.java` | Removed `test()` method + unused `java.util.Map` import | -7 |
| `backend/src/main/java/com/example/evstation/api/collaborator_mobile/controller/CollaboratorMobileController.java` | Removed `test()` method + unused `java.util.Map` import | -7 |
| `shared/openapi/openapi.yaml` | Removed 3 path entries | -69 |
| `docs/changelog.md` | Added D2 entry (full template) | +93 |
| `docs/DOC7-Backend-Structure.md` | (no change — file tree was already accurate, never listed `AdminWebController.java`) | 0 |

## Routes removed

| Method | Path | Role required (old) | Status (old) | Status (new) |
|---|---|---|---|---|
| GET | `/api/admin/test` | ROLE_ADMIN | 200 `{"message":"Admin Web API is accessible"}` | **404** |
| GET | `/api/collab/web/test` | ROLE_COLLABORATOR | 200 `{"message":"Collaborator Web API is accessible"}` | **404** |
| GET | `/api/collab/mobile/test` | ROLE_COLLABORATOR | 200 `{"message":"Collaborator Mobile API is accessible"}` | **404** |

## Routes preserved (must still work)

- `GET /healthz` — public, 200 `{"status":"UP"}` ✅
- `GET /api/collab/web/me/profile` — collab JWT, 200 ✅
- `GET /api/collab/web/me/contracts` — collab JWT (preserved, not probed)
- `PUT /api/collab/web/me/location` — collab JWT (preserved, not probed)
- `PUT /api/collab/mobile/me/location` — collab JWT, 200 (test #8) ✅
- All D1 endpoints (battery-swap trust) — unchanged and untouched

## flutter analyze

```
warning - Unused import: 'package:shared_auth/shared_auth.dart' - lib\src\api_client_factory.dart:5:8 - unused_import
warning - Unnecessary cast - lib\src\api_client_factory.dart:413:13 - unnecessary_cast
warning - Publishable packages can't have 'path' dependencies - pubspec.yaml:13:5 - invalid_dependency
warning - Publishable packages can't have 'path' dependencies - pubspec.yaml:15:5 - invalid_dependency
warning - Unused import: 'package:dio/dio.dart' - test\smoke_test.dart:1:8 - unused_import
warning - Unused import: 'package:shared_network/shared_network.dart' - test\smoke_test.dart:4:8 - unused_import
warning - Unused import: 'package:shared_auth/shared_auth.dart' - test\smoke_test.dart:5:8 - unused_import
  error - The argument type 'ProviderContainer' can't be assigned to the parameter type 'Ref<Object?>'.  - test\smoke_test.dart:36:43 - argument_type_not_assignable
```

8 issues total — **all pre-existing**, none related to D2 (D2 did not touch any Dart code). The 2 warnings in `api_client_factory.dart` are line 5 (import) and line 413 (cast), both unrelated to test endpoints. The error in `test/smoke_test.dart` is a Riverpod version-mismatch in a test file, not in any D2-impacted code.

## Remaining risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| External caller (outside repo) hits removed endpoint | Very low (no in-repo caller) | 404 | Brief already documents this in CHANGELOG breaking changes section. Rollback via git if needed. |
| `flutter analyze` pre-existing issues in shared_api/test | None for D2 | None | Pre-existing — out of D2 scope, separate cleanup candidate. |
| EV user token 401 on first request (stale token issue) | Low | Tests may show 401 instead of expected | Re-login EV user once; the second token works (seen during D2 run). |
| EmailService `Authentication failed` errors in backend log | Medium | None for D2 | Pre-existing SMTP config issue, separate from D2. |

## D2 verdict

**✅ D2 is complete.**
- 3 dead-weight smoke-test endpoints removed
- 1 empty class (`AdminWebController`) removed
- All real collaborator endpoints preserved and verified working
- `/healthz` remains the canonical health endpoint
- 0 in-repo caller
- 8/8 verification tests pass
- No D1 changes touched
- No D3/D4 changes touched
- flutter analyze shows no new issues
- CHANGELOG updated
