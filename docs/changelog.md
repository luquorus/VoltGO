# VoltGO — Changelog

Tài liệu này ghi lại các thay đổi quan trọng theo từng milestone/feature mới. Mỗi entry bao gồm: phạm vi, các file thay đổi, lý do, tác động, và tài liệu liên quan đã cập nhật.

---

## [Unreleased] — Collaborator Change Request Feature

**Ngày:** 2026-06-14
**Phạm vi:** Backend (Spring Boot) + Flutter collab_mobile + Admin web (Flutter)
**Tính năng:** Cho phép Collaborator (Cộng tác viên hiện trường) tạo và quản lý Change Request (đề xuất chỉnh sửa thông tin trạm sạc / trạm pin swap) — vốn trước đây chỉ dành cho EV User.

### Tổng quan thay đổi

#### Backend — Java / Spring Boot

| File | Thay đổi |
|---|---|
| `api/collaborator_mobile/controller/CollaboratorChangeRequestController.java` | **MỚI** — Controller mới cho phép Collaborator CRUD Change Request qua `/api/collab/mobile/change-requests/**` (charging) và `/api/collab/mobile/battery-swap-change-requests/**` (battery swap). Phân quyền `@PreAuthorize("hasRole('COLLABORATOR')")`. Bao gồm: tạo, cập nhật draft, submit, lấy danh sách của tôi, lấy chi tiết. |
| `station/application/ChangeRequestService.java` | Sửa nhỏ: truyền role từ controller xuống service thay vì hard-code `"EV_USER"` khi ghi audit log, để audit log đúng actor role cho CR do collaborator tạo. |
| `batteryswap/application/BatterySwapChangeRequestService.java` | Sửa tương tự cho battery swap CR — actor role trong audit log. |
| `station/application/AdminChangeRequestService.java` | **MỚI logic notification**: Sau khi admin approve/reject/publish CR, gọi `NotificationService.send()` để bắn notification cho collaborator là `submittedBy` của CR. |
| `batteryswap/application/AdminBatterySwapChangeRequestController.java` hoặc service tương đương | **MỚI logic notification** tương tự cho battery swap CR. |
| `api/admin_web/controller/AdminCollaboratorController.java` | Bổ sung metric `totalChangeRequests`, `publishedChangeRequests`, `rejectedChangeRequests`, `changeRequestPublishRate` vào `buildCollaboratorPerformance()`. Inject thêm `ChangeRequestJpaRepository` + `BatterySwapChangeRequestJpaRepository`. |

#### Shared API — Flutter

| File | Thay đổi |
|---|---|
| `apps/shared/shared_api/lib/src/api_client_factory.dart` | Bổ sung vào `CollaboratorMobileApiClient`: `createChangeRequest()`, `getChangeRequests()`, `getChangeRequest(id)`, `submitChangeRequest(id)`, `updateChangeRequest(id, data)`, mirror cho `batterySwapChangeRequest*`. |

#### collab_mobile — Flutter

| File | Thay đổi |
|---|---|
| `lib/src/repositories/change_request_repository.dart` | **MỚI** — Repository gọi API CR thông qua `CollaboratorMobileApiClient`. |
| `lib/src/repositories/battery_swap_change_request_repository.dart` | **MỚI** — Repository cho battery swap CR. |
| `lib/src/providers/change_request_providers.dart` | **MỚI** — Riverpod providers: `changeRequestRepositoryProvider`, `batterySwapChangeRequestRepositoryProvider`, `changeRequestListProvider`, `changeRequestDetailProvider`. |
| `lib/src/screens/change_request_list_screen.dart` | **MỚI** — Danh sách CR do collaborator tôi tạo (hợp nhất charging + battery swap). |
| `lib/src/screens/change_request_detail_screen.dart` | **MỚI** — Chi tiết CR charging. |
| `lib/src/screens/change_request_create_screen.dart` | **MỚI** — Form tạo CR (hỗ trợ cả 2 loại trạm). |
| `lib/src/screens/battery_swap_change_request_detail_screen.dart` | **MỚI** — Chi tiết CR battery swap. |
| `lib/src/routing/app_router.dart` | Thêm 4 routes: `/change-requests`, `/change-requests/create`, `/change-requests/:id`, `/change-requests/battery-swap/:id`. |
| `lib/src/widgets/bottom_nav_bar.dart` | Chuyển từ `BottomNavigationBar` sang `NavigationBar` (Material 3) để chứa 6 tab. Thêm tab "Requests" (icon `Icons.edit_note` hoặc `Icons.fact_check_outlined`) ở vị trí thứ 5 (sau Swap, trước Notifications). |
| `lib/main.dart` | (không thay đổi logic, nhưng cần verify tích hợp NavigationBar). |

#### Admin web — Flutter (impact nhẹ)

| File | Thay đổi |
|---|---|
| `apps/admin_web/lib/src/screens/collaborator_performance_screen.dart` | Thêm hiển thị 4 field CR metrics mới. |
| `apps/admin_web/lib/src/screens/collaborator_performance_detail_screen.dart` | Thêm section "Change Request Stats" (tổng + breakdown theo status). |
| `apps/admin_web/lib/src/models/collaborator_performance.dart` (nếu có) | Cập nhật model để map các field mới từ backend. |

### Quyết định thiết kế chính

1. **Phạm vi trạm collaborator được tạo CR**: tất cả trạm trong hệ thống (chọn option `all_known`).
2. **Cách tiếp cận controller**: tạo controller mới `CollaboratorChangeRequestController` tại `/api/collab/mobile/change-requests/**` (tách bạch hoàn toàn với EV user).
3. **Loại CR**: cả charging lẫn battery swap.
4. **Entry UI**: thêm tab thứ 6 vào bottom nav (chuyển sang `NavigationBar`).
5. **Metric performance**: tối thiểu — `totalCRs`, `publishedCRs`, `rejectedCRs`, `publishRate`.
6. **Notification**: đầy đủ — bắn notification khi CR được tạo, approve, reject, publish.
7. **Audit log**: actor role phản ánh đúng role người tạo CR (`EV_USER` hoặc `COLLABORATOR`).

### Tác động

- **Database**: không thay đổi schema — chỉ tận dụng các bảng `change_request`, `battery_swap_change_request`, `collaborator_notification` đã có.
- **API**: tổng cộng thêm ~12 endpoint mới trong namespace `/api/collab/mobile/**`.
- **UI**: tăng 4 screens mới, tăng 2 tab ở bottom nav.
- **Performance**: thêm 4 query vào `buildCollaboratorPerformance()` (đã có sẵn các query verification task + review, thêm query cho CR).
- **Bảo trì**: tách bạch hoàn toàn giữa collaborator và EV user, dễ thay đổi từng phía.

### Tài liệu đã cập nhật

| Doc | Mục cập nhật |
|---|---|
| `DOC1-Project-Overview.md` | §Key Features → Collaborator Features (thêm Change Request) |
| `DOC2-System-Architecture.md` | Không thay đổi (architecture không thay đổi) |
| `DOC3-Database-Schema-Detail.md` | Không thay đổi (không thêm bảng mới) |
| `DOC4-API-Documentation.md` | §4.12 Collaborator Mobile API — thêm 12 endpoint mới; §4.29 API Count Summary |
| `DOC5-Tech-Stack.md` | Không thay đổi |
| `DOC6-Frontend-Structure.md` | §6.5 Collaborator Mobile — cập nhật danh sách screens (15 → 19), providers, repositories |
| `DOC7-Backend-Structure.md` | §7.1 Package Structure — thêm controller mới; §7.2 Security — bổ sung role mapping |
| `DOC8-Key-Features.md` | §Feature 3 — bổ sung ghi chú về actor role trong audit log |
| `DOC9-Testing-Evaluation.md` | §9.1 — bổ sung test cases cần viết cho collaborator CR flow |
| `changelog.md` | File này (entry mới) |

### Test cases cần bổ sung (đề xuất)

| # | Test | Mô tả |
|---|---|---|
| 1 | Collaborator tạo CR charging | Gọi POST `/api/collab/mobile/change-requests`, expect 201 + audit log với `actor_role=COLLABORATOR` |
| 2 | Collaborator tạo CR battery swap | Gọi POST `/api/collab/mobile/battery-swap-change-requests`, expect 201 |
| 3 | Collaborator submit CR | Gọi POST `/api/collab/mobile/change-requests/{id}/submit`, expect status DRAFT→PENDING, risk score được tính |
| 4 | Admin approve CR của collaborator | Sau khi approve, kiểm tra `collaborator_notification` có record mới (type=STATION_CHANGE_REQUEST_*) |
| 5 | EV User không thể gọi endpoint collaborator | Expect 403 |
| 6 | Collaborator A không thấy CR của collaborator B | Filter theo `submittedBy == currentUser` |
| 7 | Performance metric | Sau khi collaborator có CR được publish, kiểm tra `changeRequestPublishRate` được tính đúng |

### Breaking changes

Không có. Toàn bộ thay đổi là bổ sung (additive).

### Tài liệu đã cập nhật

|| Doc | Mục cập nhật |
|---|---|---|
|| `DOC1-Project-Overview.md` | Mục *Collaborator Features* — thêm **Change Request** vào feature list, ghi rõ luồng DRAFT→SUBMIT→APPROVED/REJECTED→PUBLISHED và thông báo khi admin xử lý. |
|| `DOC4-API-Documentation.md` | Mục 4.12 *Collaborator Mobile API* — thêm 8 endpoint mới (CR charging + battery-swap) và cập nhật bảng tổng kết số endpoint. |
|| `DOC6-Frontend-Structure.md` | Mục *Collaborator Mobile* — cập nhật số screen (15→19), provider (6→7), repository (2→4); thêm mô tả 4 file mới; ghi chú bottom navigation chuyển từ `BottomNavigationBar` sang Material 3 `NavigationBar` (6 destinations). |
|| `DOC7-Backend-Structure.md` | Cấu trúc thư mục — thêm `CollaboratorChangeRequestController.java` trong `api/collaborator_mobile/controller/`. |
|| `DOC8-Key-Features.md` | Mục *Feature 3 — Station Risk Assessment Engine* — thêm ghi chú 2026-06: collaborator có thể tạo CR cho cả charging & battery-swap, dùng cùng risk engine, nhận thông báo ở mọi quyết định của admin. |
|| `DOC9-Testing-Evaluation.md` | Mục 9.2 — bổ sung 9 manual test case cho luồng CR của collaborator (tạo/submit/approve/reject/publish cho cả 2 loại trạm, kiểm tra metric performance, bottom nav 6 tab, authz negative). |
|| `apps/admin_web/lib/src/models/collaborator_performance.dart` | Thêm 4 trường: `totalChangeRequests`, `publishedChangeRequests`, `rejectedChangeRequests`, `changeRequestPublishRate`. |
|| `apps/admin_web/lib/src/screens/collaborator_performance_screen.dart` | Bảng *Performance Details* — thêm 2 cột *CRs* (published/total) và *CR Publish %*; helper `_buildPublishRateCell()`. |
|| `apps/collab_mobile/lib/src/widgets/bottom_nav_bar.dart` | Chuyển từ `BottomNavigationBar` sang Material 3 `NavigationBar`; thêm tab *Requests* ở vị trí index 3 → route `/change-requests`. |

---

## [Unreleased] — Station Search Auto-fill + Self-Assign Guard

**Ngày:** 2026-06-14
**Phạm vi:** Backend (Spring Boot) + Flutter collab_mobile + Shared API

**Tính năng:**
1. **Station search & auto-fill trong Create-CR form** — collaborator gõ tên trạm vào ô search, chọn 1 kết quả để tự động điền name, address, lat, lng, hours, ports và (nếu có) totalBatteries/avgPowerKw. Hỗ trợ cả trạm sạc và trạm pin.
2. **Ràng buộc không giao verification task cho chính collaborator tạo CR** — khi admin giao task verification sinh ra từ CR của collaborator A, hệ thống chặn và trả `409 Conflict` nếu admin chọn lại A. Audit log riêng (`BLOCK_SELF_ASSIGN`) được ghi lại.

### Tổng quan thay đổi

#### Backend — Java / Spring Boot

|| File | Thay đổi |
|---|---|---|
|| `api/collaborator_mobile/controller/CollaboratorChangeRequestController.java` | **MỚI** 4 endpoint: `GET /stations/search/by-name`, `GET /stations/{id}`, `GET /battery-swap-stations/search/by-name`, `GET /battery-swap-stations/{id}` — phục vụ autocomplete + auto-fill. |
|| `verification/application/VerificationService.java` | Inject thêm `BatterySwapChangeRequestJpaRepository`; thêm helper `assertNotSelfAssigned(...)`; gọi từ `assignTaskByUserId` và `assignBatterySwapTask`. Khi vi phạm, ghi audit log `BLOCK_SELF_ASSIGN` rồi throw `BusinessException(CONFLICT)`. |
|| `common/error/ErrorCode.java` | Thêm `CONFLICT("EVS-0014", "Resource conflict")`. |
|| `common/error/GlobalExceptionHandler.java` | Map `CONFLICT` → HTTP 409. |

#### Shared API — Flutter

|| File | Thay đổi |
|---|---|---|
|| `apps/shared/shared_api/lib/src/api_client_factory.dart` | Bổ sung 4 method vào `CollaboratorMobileApiClient`: `searchChargingStationsByName`, `getChargingStationDetail`, `searchBatterySwapStationsByName`, `getBatterySwapStationDetail`. |

#### Mobile — Flutter

|| File | Thay đổi |
|---|---|---|
|| `apps/collab_mobile/lib/src/repositories/station_search_repository.dart` | **MỚI** — `StationSearchRepository` + 5 DTO (`StationSearchItem`, `StationAutoFillData`, `PortAutoFill`, `BatterySwapStationSearchItem`, `BatterySwapStationAutoFillData`). |
|| `apps/collab_mobile/lib/src/providers/station_search_providers.dart` | **MỚI** — `stationSearchRepositoryProvider`, `chargingStationSearchProvider` (StateNotifier), `batterySwapStationSearchProvider`, `chargingStationDetailProvider.family`, `batterySwapStationDetailProvider.family`. |
|| `apps/collab_mobile/lib/src/screens/change_request_create_screen.dart` | Thêm `_buildChargingStationSearchField` / `_buildBatterySwapStationSearchField` với autocomplete list; thêm `_autoFillFromCharging` / `_autoFillFromBatterySwap` — populate toàn bộ form (name, address, lat/lng, hours, ports, totalBatteries, avgPowerKw). Thêm named constructor `_PortEntry.initial(...)` để tạo port từ dữ liệu auto-fill. |

### Quyết định thiết kế chính

1. **Search theo tên dùng endpoint PUBLISHED.** Chỉ trả về station đang publish (cùng nguồn với EV User search) để tránh collaborator điền dữ liệu từ trạm chưa public.
2. **Auto-fill chỉ khi `_type == UPDATE_STATION`.** Vì create mới thì không có dữ liệu nguồn.
3. **Self-assign guard enforce ở cả 2 method assign** (`assignTaskByUserId` cho charging, `assignBatterySwapTask` cho battery swap). Lấy `submittedBy` từ `ChangeRequestEntity` hoặc `BatterySwapChangeRequestEntity` tùy theo loại task. Nếu task không liên kết CR thì skip.
4. **HTTP 409 thay vì 400** vì đây là xung đột nghiệp vụ (admin cố tình giao lại cho cùng người), không phải input sai.
5. **Audit log riêng** (`BLOCK_SELF_ASSIGN`) giúp admin hệ thống truy vết các lần thử vi phạm.

### Tác động

- Collab: tăng tốc độ tạo CR (không cần nhập tay toàn bộ thông tin trạm đã biết).
- Admin: tăng tính công bằng và giảm rủi ro verification thiên vị khi chính người đề xuất sửa trạm tự xác minh lại.

### Tài liệu đã cập nhật

|| Doc | Mục cập nhật |
|---|---|---|
|| `DOC4-API-Documentation.md` | Mục 4.12 — thêm 4 endpoint mới (`/stations/search/by-name`, `/stations/{id}`, `/battery-swap-stations/search/by-name`, `/battery-swap-stations/{id}`). |
|| `DOC7-Backend-Structure.md` | Liệt kê 4 endpoint mới trong `CollaboratorChangeRequestController`; thêm dependency `VerificationService → BatterySwapChangeRequestJpaRepository`. |
|| `DOC8-Key-Features.md` | Mục *Feature 3* — ghi chú 2026-06-14: auto-fill khi tạo CR; mục *Verification* — bổ sung self-assign guard. |
|| `DOC9-Testing-Evaluation.md` | Mục 9.2 — bổ sung 4 test case: search hiển thị kết quả, auto-fill form, admin self-assign → 409, audit log có row `BLOCK_SELF_ASSIGN`. |

### Breaking changes
Không có. Toàn bộ là bổ sung (additive).

---

---

## Template cho entry mới

```markdown
## [YYYY-MM-DD] — Tên feature

**Ngày:**
**Phạm vi:**
**Tính năng:** Mô tả ngắn gọn

### Tổng quan thay đổi

#### Backend — Java / Spring Boot
| File | Thay đổi |
|---|---|
| ... | ... |

#### Shared API — Flutter
| File | Thay đổi |
|---|---|
| ... | ... |

#### Mobile/Web — Flutter
| File | Thay đổi |
|---|---|
| ... | ... |

### Quyết định thiết kế chính
1. ...

### Tác động
- ...

### Tài liệu đã cập nhật
| Doc | Mục cập nhật |
|---|---|
| ... | ... |

### Test cases cần bổ sung
| # | Test | Mô tả |
|---|---|---|
| ... | ... | ... |

### Breaking changes
...
```
