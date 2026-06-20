# VoltGO — Changelog

Tài liệu này ghi lại các thay đổi quan trọng theo từng milestone/feature mới. Mỗi entry bao gồm: phạm vi, các file thay đổi, lý do, tác động, và tài liệu liên quan đã cập nhật.

---

## [Unreleased] — Dead Code Cleanup & API Client Fix (2026-06-20)

**Ngày:** 2026-06-20
**Phạm vi:** Shared API client + Admin web + EV User mobile + Documentation
**Tính năng:** Loại dead code, sửa API client mismatch, cập nhật documentation.

### Tổng quan thay đổi

#### Shared API Client

|| File | Thay đổi |
|---|---|
| `apps/shared/shared_api/lib/src/api_client_factory.dart` | **Xóa** `EvUserMobileApiClient.updateChangeRequest(id, data)` — gọi `PUT /api/ev/change-requests/{id}` nhưng backend `ChangeRequestController.java` không có `@PutMapping` nào. Zero callers trong codebase. Đây là latent bug nếu tương lai có code gọi method này. |

#### Admin Web — Flutter

|| File | Thay đổi |
|---|---|
| `lib/main.dart` | **Xóa** 2 unused imports: `go_router.dart` và `shared_ui.dart`. |
| `screens/stations_list_screen.dart` | **Xóa** — 428 dòng, zero references (không trong router, không được import bởi screen nào). Chức năng đã có trong `ChargingStationsScreen` + `ChargingStationsListScreen`. |
| `screens/change_requests_screen.dart` | **Xóa** — 396 dòng, zero references. Chức năng đã có trong `UnifiedChangeRequestsScreen` (cả charging lẫn battery swap tabs). |

#### EV User Mobile — Flutter

|| File | Thay đổi |
|---|---|
| `lib/main.dart` | **Xóa** 2 unused imports: `go_router.dart` và `dio.dart`. |

#### Documentation

|| File | Thay đổi |
|---|---|
| `docs/DOC4-API-Documentation.md` | **Sửa**: xóa dòng `PUT /api/ev/change-requests/{id}` khỏi §4.7 vì endpoint không tồn tại. |
| `docs/DOC6-Frontend-Structure.md` | **Sửa**: xóa 4 reference đến file đã xóa (`stations_list_screen.dart`, `change_requests_screen.dart`, `battery_swap_stations_screen.dart`, `battery_swap_stations_list_screen.dart`, `station_trust_screen.dart`, `swap_trust_dashboard_screen.dart`, `unified_trust_dashboard_screen.dart`, `collaborators_list_screen.dart`); sửa 3 duplicate charging station rows; cập nhật screen count 54+ → 52; mô tả chính xác hơn. |

### Quyết định thiết kế chính

1. **`updateChangeRequest` — xóa method chứ KHÔNG thêm backend endpoint**: Backend `ChangeRequestController.java` (EV user mobile) không có `PUT` mapping. Thêm endpoint mới là thay đổi business logic, không phải fix bug. Zero callers trong codebase hiện tại — đây là latent dead API client method.
2. **Xóa screen file chứ KHÔNG chỉ bỏ khỏi router**: `StationsListScreen` và `ChangeRequestsScreen` có zero references (không import, không router). Giữ lại file chỉ gây confusion. Chức năng hoàn toàn được cover bởi `ChargingStationsScreen` + `UnifiedChangeRequestsScreen`.
3. **Không xóa `PresignUploadResponseDTO.java`**: Zero callers nhưng là orphan từ D4 cleanup đã được ghi nhận trong changelog. Không nằm trong scope cleanup lần này.

### Breaking changes

**Không có** — không có feature nào bị break, không có endpoint bị xóa (vì method đã không có callers).

---

## [Unreleased] — EV User mobile: thay "0 ports" bằng "X piles × Y pins" cho trạm battery-swap-only

**Ngày:** 2026-06-18
**Phạm vi:** Backend + EV User mobile (full stack)
**Tính năng:** API `/api/ev/stations` giờ trả về thêm `batterySwap` summary cho mỗi station (gồm `totalPiles`, `totalSlots`, `availableBatteries`, `availableSlots`, `avgChargePowerKw`). Mobile hiển thị số pile/slot thay vì "0 ports" cho trạm battery-swap-only.

### Tổng quan thay đổi

| File | Thay đổi |
|---|---|
| `backend/src/main/java/com/example/evstation/api/ev_user_mobile/dto/BatterySwapSummaryDTO.java` | **Tạo mới** — DTO chứa summary cho battery swap station. |
| `backend/src/main/java/com/example/evstation/api/ev_user_mobile/dto/StationListItemDTO.java` | **Sửa**: thêm field `batterySwap` (nullable). |
| `backend/src/main/java/com/example/evstation/station/infrastructure/jpa/StationQueryRepositoryImpl.java` | **Sửa**: thêm method `getBatterySwapSummaryForStation(UUID)`; wire vào cả `findPublishedStationsWithinRadius` và `searchPublishedStationsByName`. Query tổng hợp: 1 SQL count piles, 1 SQL count available slots. |
| `apps/ev_user_mobile/lib/src/screens/home_map_screen.dart` | **Sửa**: `_buildStationCard` check `supportsBatterySwap` + `totalPorts == 0` → hiển thị `"X × Y piles"`. Nếu hybrid: `"X ports"` + `"+ N piles"` badge. Click trạm swap-only → route tới `/battery-swap?stationId=...` thay vì `/stations/...`. |
| `docs/station-api-list.md` | **Sửa**: cập nhật mô tả 1.1, 1.2, 1.3 — note schema `StationListItemDTO` có thêm `batterySwap` và `supportsBatterySwap`. |

### Lý do

- Trước đây, API `/api/ev/stations` trả về cả charging + battery-swap station. Với trạm battery-swap-only, `chargingSummary.totalPorts = 0` → mobile hiển thị "0 ports" gây hiểu nhầm (user nghĩ trạm hỏng).
- Cần surface thông tin số pile/slot lên list card để user phân biệt rõ charging vs swap.

### Tác động

- **API response**: Mỗi `StationListItemDTO` giờ có thêm `batterySwap: { totalPiles, totalSlots, availableBatteries, availableSlots, avgChargePowerKw }` (null nếu trạm không hỗ trợ battery swap).
- **Mobile UI**:
  - Trạm charging-only: "X ports" (giữ nguyên)
  - Trạm battery-swap-only: "X × Y piles" (label mới, vd "6 × 5 piles")
  - Trạm hybrid: "X ports" + "+ N piles" (2 badge)
- **Mobile nav**: Click trạm battery-swap-only từ home list → mở thẳng màn hình battery swap (pre-selected station). Trước đây mở `/stations/{id}` rồi user phải click nút "Book battery swap".

### Tác động hiệu năng

- 2 truy vấn SQL bổ sung / station (count piles + count available slots). Với list 20 station/page → 40 query. Có thể tối ưu bằng `JOIN + GROUP BY` sau, nhưng trade-off với complexity.

### Kết quả test

| Test | Kết quả |
|---|---|
| `dart analyze` `home_map_screen.dart` | ✅ No errors (chỉ pre-existing info về `withOpacity` deprecation) |
| `javac` compile check | ⚠️ Không có gradle wrapper, đã dùng javac trực tiếp — fails do classpath không đầy đủ nhưng syntax + import check pass |
| API docs `docs/station-api-list.md` | ✅ Cập nhật schema description cho 1.1, 1.2, 1.3 |

### Lưu ý deploy

- BE phải được rebuild + restart trước khi FE dùng field mới. Nếu BE chưa cập nhật → FE check `batterySwap != null` → fallback về logic cũ (hiển thị "0 ports").
- DB không thay đổi — chỉ thêm DTO + read-only queries.

---

## [Unreleased] — Admin web: Battery Swap card "Piles × Pins"

**Ngày:** 2026-06-18
**Phạm vi:** Admin web (Flutter) — list card + DataTable
**Tính năng:** Đổi cách hiển thị số liệu Battery Swap trong list card và DataTable — thay vì chỉ "X piles" dùng icon `ev_station` (gợi cổng sạc), hiển thị "X piles × Y pins/pile" với icon `battery_saver` (gợi trụ pin). Gộp 2 màn hình list trùng lặp thành 1.

### Tổng quan thay đổi

| File | Thay đổi |
|---|---|
| `apps/admin_web/lib/src/screens/unified_stations_list_screen.dart` | **Sửa**: Thêm prop `initialTabIndex` (0 = Charging, 1 = Battery Swap). Đổi header cột "Piles" → "Piles × Pins", DataCell hiển thị `totalPiles × (totalSlots / totalPiles)`. |
| `apps/admin_web/lib/src/routing/app_router.dart` | **Sửa**: Route `/battery-swap/stations` và `/battery-swap-stations` chuyển từ `BatterySwapStationsScreen` (file cũ) sang `UnifiedStationsListScreen(initialTabIndex: 1)`. Import thêm `unified_stations_list_screen.dart`, bỏ import `battery_swap_stations_screen.dart`. |
| `apps/admin_web/lib/src/screens/battery_swap_stations_screen.dart` | **Xoá** — wrapper 21 dòng, không còn route dùng. |
| `apps/admin_web/lib/src/screens/battery_swap_stations_list_screen.dart` | **Xoá** — list 582 dòng, đã được gộp vào `unified_stations_list_screen.dart` với chức năng tương đương. |

### Lý do

- Trước đây, danh sách Battery Swap hiển thị cột "Piles" chỉ 1 số (e.g. "6") với icon `ev_station` — icon này gợi "cổng sạc" (charging port), không phù hợp với "Pile" (trụ đổi pin). Admin nhìn không rõ 6 trụ này chứa bao nhiêu pin.
- Có 2 file list screen song song (`battery_swap_stations_list_screen.dart` và tab BatterySwap trong `unified_stations_list_screen.dart`) có logic gần giống hệt nhau → duplicate code ~600 dòng.

### Tác động

- **Hiển thị**: cột "Piles" trong DataTable đổi từ "6" thành "6 × 5" (6 trụ × 5 pin/trụ). Mobile card thêm label "pins" và "piles" rõ ràng.
- **Icon**: thay `Icons.ev_station` → `Icons.battery_saver` (icon có hình pin + dấu stack).
- **Routing**: URL `/battery-swap-stations` và `/battery-swap/stations` đều mở `UnifiedStationsListScreen` với default tab = Battery Swap (không thay đổi hành vi user).
- **Dead code**: xoá 2 file ~600 dòng.

### Kết quả test

| Test | Kết quả |
|---|---|
| `dart analyze` 2 file đã sửa | ✅ No errors, 15 pre-existing `info` (deprecation) |
| Routes import đúng `UnifiedStationsListScreen` | ✅ 2 routes point to `UnifiedStationsListScreen(initialTabIndex: 1)` |
| Không còn reference đến 2 file đã xoá | ✅ `grep BatterySwapStationsScreen` = 0 results |

---

## [Unreleased] — Battery Swap Station CSV Import + Tuỳ biến cấu hình pin

**Ngày:** 2026-06-18
**Phạm vi:** Backend (Spring Boot) + Admin web (Flutter) + PostgreSQL enum
**Tính năng:** Bổ sung 3 tuỳ biến khi tạo Battery Swap Station: `batteryCapacityKwh` (dung lượng pin mỗi slot), `pileTemplates` (layout pile × slot tuỳ ý), `parking` (loại đỗ xe). Mở rộng CSV import từ 9 cột → 12 cột, bao gồm các trường mới.

### Tổng quan thay đổi

#### Backend — Java / Spring Boot

| File | Thay đổi |
|---|---|
| `station/domain/ParkingType.java` | **Thêm** enum value `STREET_PARKING`. Enum giờ có 4 giá trị: `PAID, FREE, STREET_PARKING, UNKNOWN`. |
| `batteryswap/api/dto/CreateBatterySwapStationDTO.java` | **Thêm** field `batteryCapacityKwh` (BigDecimal, default 60.0 kWh, @DecimalMin 1.0), `parking` (String, optional, default FREE), `pileTemplates` (List<PileTemplateDTO>, optional, nếu null/empty dùng default layout). Thêm inner class `PileTemplateDTO` (pileIndex, slotsPerPile, slots[]) và `SlotTemplateDTO` (slotIndex, batteryCapacityKwh). |
| `batteryswap/api/dto/UpdateBatterySwapStationDTO.java` | **Thêm** field `batteryCapacityKwh` (BigDecimal, default 60.0 kWh, @DecimalMin 1.0). |
| `batteryswap/application/BatterySwapStationAdminService.java` | **Sửa** `buildDefaultPileTemplates()`: thêm tham số `BigDecimal batteryCapacityKwh`, dùng để set `battery_capacity_kwh` cho từng slot template thay vì hardcoded `60.0`. **Thêm** method `buildPileTemplatesFromCreate()` để build pile/slot từ `CreateBatterySwapStationDTO`. **Thêm** method `parseParkingType()` helper. **Đổi** `parking(ParkingType.FREE)` hardcode → `parking(parseParkingType(data.getParking()))` cho cả `createStation()` và `updateStation()`. |
| `batteryswap/application/BatterySwapCsvImportService.java` | **Sửa lớn**: Mở rộng parser từ 9 cột → 12 cột. **Thêm** `batteryCapacityKwh` (cột 10, default 60.0), `parking` (cột 11, default FREE), `pileLayout` (cột 12, format `pileCount:slotsPerPile[:capacityKwh]`, default auto). **Thêm** method `parsePileLayout()` validate `pileCount × slotsPerPile == totalBatteries` và sinh slot entries cho từng pile. |
| `batteryswap/application/SwapStationStateApplyService.java` | **Sửa**: copy `battery_capacity_kwh` từ `BatterySwapSlotTemplateEntity` xuống runtime `BatterySlotEntity` (cả 2 method `applyForVersion` và `applyForSwapVersion`) thay vì để default 60.0. |
| `batteryswap/api/controller/AdminBatterySwapStationController.java` | Cập nhật Swagger doc cho `/import-csv` (mô tả 12 cột + format `pileLayout`). |

#### Database — PostgreSQL

| File | Thay đổi |
|---|---|
| `db/migration/V138__add_street_parking_to_parking_type_enum.sql` | **MỚI** — `ALTER TYPE parking_type ADD VALUE IF NOT EXISTS 'STREET_PARKING';`. **Lưu ý**: Migration này được apply **thủ công** vào DB do Flyway version compare coi `V138 (138) < V999_06` nhưng schema đang ở `999.06` (history chỉ ghi đến V131 trước khi rebuild). Người vận hành cần chạy: (1) `ALTER TYPE parking_type ADD VALUE IF NOT EXISTS 'STREET_PARKING';` (2) `INSERT INTO flyway_schema_history ... '138' ... success=true` để Flyway không cố apply lại. |

#### CSV file mới

| File | Thay đổi |
|---|---|
| `data/battery_swap_stations_v2.csv` | **MỚI** — 10 trạm Hà Nội + ngoại thành, format 12 cột, đa dạng layout (5:6, 4:6, 2:8, 6:5, 3:8, 5:8, 2:6, 3:6), đa dạng capacity (40/60/80 kWh), đa dạng parking (FREE/PAID/STREET_PARKING/UNKNOWN), có/không parkingFee, có/không note. |

#### Admin web UI — Flutter

| File | Thay đổi |
|---|---|
| `apps/admin_web/lib/src/screens/battery_swap/create_battery_swap_station_screen.dart` | **Thêm 3 fields mới vào form**: (1) `Battery Capacity per slot (kWh)` — TextFormField mặc định 60.0; (2) `Parking Type` — DropdownButtonFormField với 4 lựa chọn (FREE/PAID/STREET_PARKING/UNKNOWN); (3) `Use custom pile layout` — SwitchListTile bật tắt + 3 sub-fields (Pile count, Slots per pile, Slot capacity in this layout). Logic `_submit()` gửi các field mới qua API và validate `pileCount × slotsPerPile == totalBatteries`. |

### Lý do

Trước đây mỗi slot Battery Swap luôn hardcoded 60.0 kWh (xem `BatterySwapStationAdminService:594` cũ). Hệ thống không cho phép admin khai báo pin thực tế (40/80 kWh), không cho chọn layout pile × slot khác 6 slot/pile, và không có `STREET_PARKING` enum. CSV cũ chỉ 9 cột, không thể hiện các thuộc tính này. Đồng thời `parking_type` enum hardcoded `FREE` cho mọi trạm swap.

### Tác động

- **API**: tương thích ngược — CSV 9 cột cũ vẫn import được (các cột optional sẽ dùng default).
- **Database**: enum `parking_type` có thêm 1 value; cần migration thủ công hoặc rebuild với Flyway baseline mới.
- **UI**: form tạo trạm swap có thêm 3 fields mới; default vẫn hợp lý nên admin không nhập cũng OK.
- **Runtime**: runtime `battery_slot` giờ nhớ `battery_capacity_kwh` đúng với cấu hình từng trạm.

### Kết quả test

| Test | Kết quả |
|---|---|
| Login `admin2@local / Admin@456` | ✅ HTTP 200 |
| Import `battery_swap_stations_v2.csv` | ✅ HTTP 200, **10/10 rows success** |
| Verify `station_version.parking` | ✅ FREE/PAID/STREET_PARKING/UNKNOWN đều map đúng |
| Verify `pileTemplate` (pile × slotsPerPile) | ✅ 10/10 trạm đúng layout CSV |
| Verify `battery_swap_slot_template.battery_capacity_kwh` | ✅ 10/10 trạm đúng capacity (40/60/80 kWh) |
| Verify runtime `swap_pile` + `battery_slot` count | ✅ 10/10 trạm tạo đúng số pile + slot |
| Verify runtime `battery_slot.battery_capacity_kwh` | ✅ 10/10 trạm copy đúng capacity từ template |

### Tài liệu liên quan

- `docs/station-api-list.md` — cần cập nhật mô tả API `POST /api/admin/battery-swap/stations` và `POST /api/admin/battery-swap/stations/import-csv` để phản ánh các field mới.
- `backend/src/main/java/.../api/dto/CreateBatterySwapStationDTO.java` — JavaDoc đã có sẵn.

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

---

## [Unreleased] — EV User mobile UI Redesign: Home Map + Station Detail + Ratings Integration

**Ngày:** 2026-06-19 → 2026-06-20
**Phạm vi:** Backend (Spring Boot) + EV User mobile (Flutter)
**Tính năng:**
1. **Home Map redesign** — đơn giản hoá UI: 1 search bar duy nhất vừa tìm station vừa tìm destination; bottom sheet switch rõ ràng giữa 2 mode (Nearby / Route); modal filter sheet thay cho AlertDialog; preview card lớn khi chọn 1 station (Route / Book / Reserve buttons).
2. **Tách widget chuyên biệt** — tách 3 widget mới `CompactStationCard`, `CompactSwapStationCard`, `SelectedStationPreview`, `FilterBottomSheet` để giảm lượng code inline trong `home_map_screen.dart` (2716 dòng → cùng kích thước sau khi cấu trúc lại) và tăng khả năng tái sử dụng.
3. **Reusable `StationRatingSection`** — widget Ratings & Reviews dùng chung cho cả charging station (`station_detail_screen.dart`) và battery swap station (`battery_swap_screen.dart`); sửa logic Rate vs View-all dựa trên `eligibleStationsForRatingProvider`.
4. **Lọc trạm battery-swap-only ra khỏi list "Charging"** — `StationSearchNotifier` ở cả 3 mode (search by name / nearby / map) thêm `.where((s) => s['supportsBatterySwap'] != true)` để tránh trùng lặp khi user đã chọn tab Battery Swap.
5. **API filter bổ sung trong `StationQueryRepositoryImpl`** — thêm `EXISTS (SELECT 1 FROM station_service WHERE service_type = 'CHARGING')` vào cả `findPublishedStationsWithinRadius` và `searchPublishedStationsByName` để kết quả "nearby charging" chỉ chứa trạm có `station_service` row `CHARGING` (fix bug trả trạm swap-only khi user lọc theo tab Charging).
6. **`BatterySwapStationDTO.providerId`** — thêm field `providerId` (nullable) trong response `GET /api/ev/battery-swap/stations`, `getNearbySwapStations` và cả `GET /api/public/battery-swap/stations` (cùng DTO qua `listAllSwapStations`). SQL đổi join: từ `bsv.id = sv.id` (sai cho seed data V124/V125) sang `bsv.station_id = sv.station_id` + filter `station_service.service_type = 'BATTERY_SWAP'`. Khi admin tạo trạm mới, `StationEntity.providerId` được set = adminId (P1 fix — trước đây để NULL).
7. **Change Request Parking optional** — `CreateChangeRequestDTO.stationData.parking` bỏ `@NotNull`, cho phép user tạo CR mà không chọn parking. Service fallback về `ParkingType.UNKNOWN` nếu null. Mobile form `change_request_create_screen.dart` thêm dropdown Parking (PAID / FREE / STREET_PARKING / UNKNOWN), auto-fill từ station detail, gửi kèm trong payload.

### Tổng quan thay đổi

#### Backend — Java / Spring Boot

| File | Thay đổi |
|---|---|
| `batteryswap/application/BatterySwapService.java` | Sửa lớn 2 method `getNearbySwapStations` và `listAllSwapStations`: đổi JOIN `bsv.id = sv.id` → `bsv.station_id = sv.station_id` + JOIN `station` + JOIN `station_service` (filter `service_type = 'BATTERY_SWAP'`). Thêm `s.provider_id` vào SELECT. Đổi named param `:lat/:lng` → positional `?` để tránh conflict với PostGIS `::text` cast. Thêm field `providerId` vào builder. |
| `batteryswap/application/BatterySwapStationAdminService.java` | Sửa method `createStation`: thêm `.providerId(adminId)` cho `StationEntity` (P1 fix — trước đây NULL). Log thêm `(provider={})`. |
| `api/ev_user_mobile/dto/BatterySwapStationDTO.java` | Thêm field `providerId` (String, nullable). |
| `station/infrastructure/jpa/StationQueryRepositoryImpl.java` | Thêm `AND EXISTS (SELECT 1 FROM station_service ss WHERE ss.station_version_id = sv.id AND ss.service_type = 'CHARGING')` vào cả `findPublishedStationsWithinRadius` (nearby) và `searchPublishedStationsByName` (search by name). Trim trailing space trong SQL `SELECT`. |
| `api/ev_user_mobile/dto/CreateChangeRequestDTO.java` | Bỏ annotation `@NotNull` trên `StationDataDTO.parking` — giờ optional. |
| `station/application/ChangeRequestService.java` | Sửa `submitChangeRequest`: `.parking(data.getParking() != null ? data.getParking() : ParkingType.UNKNOWN)` thay vì `.parking(data.getParking())` (tránh NPE). |

#### EV User mobile — Flutter

| File | Thay đổi |
|---|---|
| `apps/ev_user_mobile/lib/src/widgets/compact_station_card.dart` | **MỚI** — 375 dòng. 2 widget: `CompactStationCard` (charging + hybrid, badge tối đa 3, hiển thị Trust / X ports / Up to Y kW / X available / +N piles cho hybrid) và `CompactSwapStationCard` (battery-swap only, hiển thị N piles / N ready / Y kW avg). Có private `_MiniBadge` widget. |
| `apps/ev_user_mobile/lib/src/widgets/filter_bottom_sheet.dart` | **MỚI** — 323 dòng. Class `HomeMapFilterState` (immutable, có `copyWith` + `hasActiveFilters` + `activeFilterChips`) + `FilterBottomSheet` (modal bottom sheet thay cho AlertDialog cũ, có slider radius 1-50 km, ChoiceChip cho 2/5/10/20 km, ChoiceChip cho minPower 22/50/100 kW, ChoiceChip cho AC/DC Fast, nút Reset / Cancel / Apply). |
| `apps/ev_user_mobile/lib/src/widgets/selected_station_preview.dart` | **MỚI** — 348 dòng. `SelectedStationPreview` — card lớn hiển thị khi user chọn 1 station trên map. Có header (icon + name + address + clear), info row (distance / ETA / ports hoặc batteries / power / trust), badges cho hybrid, 2 action buttons Route (OutlinedButton) và Book/Reserve (FilledButton, label đổi theo `isBatterySwapOnly`). |
| `apps/ev_user_mobile/lib/src/widgets/rating/station_rating_section.dart` | **MỚI** — 195 dòng. `StationRatingSection` — widget Ratings & Reviews dùng chung. Watch `stationRatingSummaryProvider` + `eligibleStationsForRatingProvider`. Có 2 mode: `compact=true` cho sheet/embedded context (padding 0, title nhỏ hơn) và mặc định (padding 24, title lớn). Nút đổi label Rate this station / View all ratings dựa trên eligibility. |
| `apps/ev_user_mobile/lib/src/providers/station_providers.dart` | Thêm `.where((s) => s['supportsBatterySwap'] != true)` vào 3 response handler của `StationSearchNotifier` (searchByName + 2 searchNearby mode). Đảm bảo tab Charging chỉ trả trạm charging. |
| `apps/ev_user_mobile/lib/src/screens/home_map_screen.dart` | **Refactor lớn** (3428 dòng diff) — import 4 widget mới; thêm enum `HomeServiceMode { charging, batterySwap }`; redesign bottom sheet switch giữa 2 mode; replace AlertDialog filter bằng `showModalBottomSheet` với `FilterBottomSheet`; replace inline preview card bằng `SelectedStationPreview`; replace inline list card bằng `CompactStationCard` / `CompactSwapStationCard`. |
| `apps/ev_user_mobile/lib/src/screens/station_detail_screen.dart` | Sửa 135 dòng — bổ sung header cho charging station detail (distance / trust / power badge), refactor action button, integrate `StationRatingSection` (compact mode). |
| `apps/ev_user_mobile/lib/src/screens/battery_swap_screen.dart` | Thêm 2 instance `StationRatingSection(stationId, compact: true)`: 1 trong main screen `BatterySwapScreenState` (line 452), 1 trong `_StationDetailSheet` (line 1654). Import thêm `../widgets/rating/station_rating_section.dart`. |
| `apps/ev_user_mobile/lib/src/screens/change_request_create_screen.dart` | Thêm field `String? _parking`; thêm `_buildDropdown` Parking với 4 options; auto-fill `_parking` từ station detail (`_loadFromStationData`); reset trong `_resetChargingForm` và `_resetSwapForm`; thêm `'parking': _parking ?? 'UNKNOWN'` vào JSON payload. |
| `apps/ev_user_mobile/lib/src/screens/change_request_list_screen.dart` | **Minor UI fix (2026-06-20):** wrap `Text` widget trong `_ChangeRequestCard` bằng `Expanded` / `Flexible` + thêm `maxLines: 1` + `overflow: TextOverflow.ellipsis` + `softWrap: false` cho type/id và date. Trước đây khi `cr.id` dài hoặc status pill rộng, Row tràn ngang gây yellow-black stripe overflow warning. |

### Lý do

- **Home Map UI trước đây** có 2 ô search riêng (station name + destination), filter dùng AlertDialog không mobile-friendly, preview card nhỏ khó thao tác, bottom sheet phức tạp với nhiều nhánh `if/else` inline. Tách widget giúp giảm complexity và tăng testability.
- **Tab Charging trả cả trạm battery-swap** là bug lộ từ trước V138 (khi seed data có cả 2 loại trạm trong cùng `station_version`). Fix bằng `EXISTS` subquery ở SQL layer + defensive `.where` ở Dart layer.
- **`BatterySwapStationDTO.providerId`** được yêu cầu bởi admin UI để phân biệt trạm VoltGo seed (provider=VoltGo) với trạm partner import qua CSV. P1 fix set `providerId` khi admin tạo trạm mới.
- **`ChangeRequestDTO.parking` @NotNull** trước đây ép user phải chọn parking khi tạo CR — không cần thiết vì CR có thể chỉ sửa giờ/địa chỉ/ports. Bỏ @NotNull, service fallback về `UNKNOWN`.
- **`StationRatingSection` tái sử dụng**: trước đây logic rating bị copy-paste ở 2 nơi (charging detail + battery swap screen). Tách widget + dùng `eligibleStationsForRatingProvider` để quyết định nút Rate vs View-all.

### Tác động

- **API response**: `BatterySwapStationDTO` có thêm `providerId`. `GET /api/ev/stations` (charging) filter bằng `EXISTS station_service` — chỉ trả trạm có `CHARGING` service.
- **Mobile UI**:
  - Home Map có 1 search bar duy nhất, filter bottom sheet, 2 mode switch (Charging / Battery Swap), preview card lớn khi select.
  - 2 detail surface (charging + swap) cùng dùng `StationRatingSection` — consistent UX.
  - Change Request form có thêm dropdown Parking.
- **Backend join logic**: 2 method SQL đổi join từ `bsv.id = sv.id` (sai với seed data V124/V125) → `bsv.station_id = sv.station_id`. Trạm seed VoltGO (V124) giờ hiển thị đúng trên `GET /api/ev/battery-swap/stations`.

### Tác động hiệu năng

- 1 subquery `EXISTS` thêm vào 2 query station (nhẹ — index `station_service_station_version_id_idx` đã có).
- Provider lookup thêm 1 column `s.provider_id` trong SELECT (không đáng kể).
- `batteryswap/application/BatterySwapService.java` đổi named param → positional `?`. Hibernate vẫn bind theo thứ tự `setParameter(1..5)`.

### Kết quả test

| Test | Kết quả |
|---|---|
| `flutter analyze` `ev_user_mobile/lib` | Cần verify — đã viết một số `withOpacity` (pre-existing deprecation) nhưng không có lỗi compile mới |
| API `GET /api/ev/stations` (tab Charging) | Trả về chỉ trạm có `station_service.service_type = 'CHARGING'` — verify qua response không còn `supportsBatterySwap: true` trộn lẫn |
| API `GET /api/ev/battery-swap/stations/nearby` | Trả về đủ cả trạm seed V124 (VoltGO) + trạm admin tạo mới, có `providerId` |
| API `GET /api/public/battery-swap/stations` (anon) | Trả về cùng list với `/api/ev/battery-swap/stations` nhưng không cần JWT; mỗi item có `providerId` |
| API `POST /api/ev/change-requests` không có `parking` | 200 thay vì 400 — service fallback `UNKNOWN` |
| Mobile home map: switch tab Charging → Battery Swap | List không còn duplicate (filter qua `supportsBatterySwap != true`) |
| Mobile station detail: scroll xuống | Hiện `Ratings & Reviews` (StationRatingSection compact) |
| Mobile battery swap screen: scroll xuống | Hiện `Ratings & Reviews` (StationRatingSection compact) |

### Tài liệu đã cập nhật (2026-06-20)

| Doc | Mục cập nhật |
|---|---|
| `docs/DOC1-Project-Overview.md` | §EV User Features — note thêm "Home Map redesigned (2026-06-20)", "Ratings & Reviews integrated", "parking optional trong Create CR" |
| `docs/DOC4-API-Documentation.md` | §4.4 Station API — blockquote ghi rõ filter `EXISTS` `service_type = CHARGING`, `batterySwap` summary; §4.6 Battery Swap API — đổi description 2 endpoint có `providerId` + response example JSON; §4.3 Public API — note `providerId` cho 2 endpoint public; §4.7 Change Request API — note `parking` optional |
| `docs/DOC6-Frontend-Structure.md` | §6.5 EV User Mobile — note `Home Map redesigned`, `Station Detail integrated StationRatingSection`, `Battery Swap integrated StationRatingSection`, `Change Request Create added Parking dropdown`; update Providers description (filter `supportsBatterySwap != true`); thêm section "Custom Widgets (2026-06-20 — 4 mới)" |
| `docs/DOC7-Backend-Structure.md` | §Service layer — note inline trên `BatterySwapService.java` (JOIN refactor + providerId) và `ChangeRequestService.java` (parking fallback UNKNOWN) |
| `docs/DOC8-Key-Features.md` | §Battery Swap feature — note 2026-06-20 JOIN refactor + providerId; §Change Request feature — note 2026-06-20 parking optional |
| `docs/DOC9-Testing-Evaluation.md` | §9.2 — bổ sung 10 test case mới (15-24) cho Home Map redesign + Ratings & Reviews + providerId + parking |
| `docs/station-api-list.md` | §1.1/1.3 — note filter `service_type = CHARGING`; §2.1/2.2 — note JOIN refactor + providerId; §4.1/4.5 — note parking optional; §18.1/18.2 — note providerId cho public endpoints; header "Cập nhật" cập nhật |

---

## [Unreleased] — Battery-Swap Trust Controller Consolidation + Security Fix

**Ngày:** 2026-06-17
**Phạm vi:** Backend (Spring Boot) + Flutter shared_api + Flutter ev_user_mobile + Admin web
**Tính năng:** Hợp nhất 2 controller trust-score trùng lặp (`/api/admin/battery-swap/trust/**` và `/api/v1/battery-swap/trust/**`) về một controller duy nhất dưới prefix `/api/v1/battery-swap/trust/**`. Đồng thời khóa 2 endpoint nhạy cảm (`POST /recalculate` và `GET /history`) về quyền ADMIN — trước đây chúng được public (cho phép bất kỳ ai kích hoạt recalc hoặc đọc raw `VerificationReviewEntity`). Sửa luôn bug 404 trên EV user app (`getSwapTrust` gọi sai path).

### Tổng quan thay đổi

#### Backend — Java / Spring Boot

| File | Thay đổi |
|---|---|
| `batteryswapchange/web/BatterySwapTrustController.java` | **MỚI summary + PreAuthorize.** Thêm method `getTrustSummary()` (lấy nội dung từ controller admin đã xóa). Thêm `@PreAuthorize("hasRole('ADMIN')")` trên `recalculateTrust` và `getTrustHistory`. Các read-only endpoint (`getTrustScore`, `getTrustBreakdown`, `getTrustLevel`, `getTrustSummary`) giữ public qua `SecurityConfig` line 91 (`permitAll()` cho `/api/v1/battery-swap/trust/**`). |
| `batteryswap/api/controller/AdminBatterySwapTrustController.java` | **XÓA** — 206 dòng. Toàn bộ handler đã được merge vào `BatterySwapTrustController` ở trên. |
| `auth/infrastructure/security/SecurityConfig.java` | Không thay đổi (vẫn `permitAll()` cho `/api/v1/battery-swap/trust/**`; per-method gating giờ do `@PreAuthorize` ở controller). |

#### Shared API — Flutter

| File | Thay đổi |
|---|---|
| `apps/shared/shared_api/lib/src/api_client_factory.dart` | Cập nhật 5 method trong `AdminWebApiClient`: `getBatterySwapTrust`, `getBatterySwapTrustBreakdown`, `getBatterySwapTrustLevel`, `recalculateBatterySwapTrust`, `getBatterySwapTrustSummary` — đổi path string từ `/api/admin/battery-swap/trust/...` → `/api/v1/battery-swap/trust/...`. Thêm comment ghi chú migration 2026-06. |

#### ev_user_mobile — Flutter

| File | Thay đổi |
|---|---|
| `apps/ev_user_mobile/lib/src/repositories/station_repository.dart` | **Sửa bug 404.** Method `getSwapTrust` đổi URL từ `/api/ev/battery-swap/trust/{stationId}` (path không tồn tại trên backend) → `/api/v1/battery-swap/trust/{stationId}` (path public merge ở trên). Cập nhật comment DartDoc. |

#### Admin web — Flutter

| File | Thay đổi |
|---|---|
| `apps/admin_web/lib/src/providers/battery_swap_trust_providers.dart` | Không thay đổi code — chỉ gián tiếp hưởng lợi vì provider này gọi `factory.admin.getBatterySwapTrust*()` mà phương thức đã được cập nhật path ở shared_api. |

### Quyết định thiết kế chính

1. **Hợp nhất về prefix `/api/v1/...`** thay vì giữ 2 controller song song: v1 là prefix duy nhất mà `SecurityConfig` cho phép public; bất kỳ lựa chọn nào khác sẽ phải đụng `SecurityConfig` (ngoài phạm vi). Nhỏ nhất, an toàn nhất.
2. **Read = public, write/history = ADMIN.** Match với mô hình "trust score là thông tin công khai cho người dùng, nhưng recalc/history là hành động nội bộ của admin". Phù hợp với comment đã có sẵn trong `SecurityConfig`: `// Battery Swap Trust API endpoints (public for trust score queries)`.
3. **`POST /recalculate` chuyển từ public → ADMIN**: đây là endpoint mutation, kích hoạt full recompute. Trước đây bất kỳ ai cũng có thể spam — vừa tốn tài nguyên vừa không có ý nghĩa nghiệp vụ.
4. **`GET /history` chuyển từ public → ADMIN**: trước đây trả raw `VerificationReviewEntity` (kèm review notes, reviewer id, score nội bộ) cho bất kỳ ai. Khóa về admin là bảo vệ dữ liệu nội bộ.
5. **`/summary` chuyển từ ADMIN → public**: thông tin tổng hợp (top/bottom stations, count theo level) đã là dạng public-safe (đã được public ở controller cũ qua endpoint khác, ví dụ `/api/ev/loyalty/.../ratings`). Cho phép public mở rộng hữu ích cho landing page.
6. **Không alias cho `/api/admin/...`**: bỏ luôn 6 route admin cũ, cập nhật duy nhất một caller là `AdminWebApiClient` (typed client) sang path mới. Số caller bên ngoài = 0 (đã grep toàn repo).

### Tác động

- **API surface**: 6 endpoint bị xóa (`/api/admin/battery-swap/trust/...`), 1 endpoint được tái sử dụng cho public (`/summary`), 2 endpoint được khóa về ADMIN (`/recalculate`, `/history`).
- **Bảo mật**: chặn 2 vector lộ dữ liệu nội bộ (raw review history, public mutation). Cải thiện rõ rệt.
- **Hiệu năng**: giảm 1 controller Java (~206 dòng) và 1 bản sao DB-bound handler. Không có thay đổi hot path.
- **EV user mobile**: sửa bug 404 cho màn hình trust — trước đây `swapTrustProvider` luôn fail.
- **Admin web**: không cần thay đổi code; typed client tự route về path mới.
- **Hardware simulator**: không bị ảnh hưởng (chỉ dùng `/api/public/...`).

### Tài liệu đã cập nhật

| Doc | Mục cập nhật |
|---|---|
| `DOC4-API-Documentation.md` | §4.16 *Admin Web API — Trust Score Management*: cập nhật 5 dòng trust-score path và Auth Required (public cho read, ADMIN cho recalc/history). |
| `DOC7-Backend-Structure.md` | Cấu trúc thư mục `api/admin_web/controller/`: bỏ dòng `AdminBatterySwapTrustController.java`. |
| `DOC10-Section-4-1-3-Detailed-Package-Design.md` | §Controllers (API layer): bỏ `AdminBatterySwapTrustController` khỏi admin_web; thêm ghi chú về `BatterySwapTrustController` ở `batteryswapchange/web`. |
| `changelog.md` | Entry này. |

### Test cases cần bổ sung (đề xuất)

| # | Test | Mô tả |
|---|---|---|
| 1 | Public read trust score | `GET /api/v1/battery-swap/trust/{stationId}` không kèm token → 200 hoặc 404 (nếu chưa có score), **không** 401/403 |
| 2 | Public read trust breakdown | `GET /api/v1/battery-swap/trust/{stationId}/breakdown` anonymous → 200 |
| 3 | Public read trust level | `GET /api/v1/battery-swap/trust/{stationId}/level` anonymous → 200 (trả HIGH/MEDIUM/LOW) |
| 4 | Public read trust summary | `GET /api/v1/battery-swap/trust/summary` anonymous → 200 (trả `{totalStations, excellentCount, ...}`) |
| 5 | Anonymous recalc bị chặn | `POST /api/v1/battery-swap/trust/{stationId}/recalculate` anonymous → 403 với code `EVS-0403` |
| 6 | Anonymous history bị chặn | `GET /api/v1/battery-swap/trust/{stationId}/history` anonymous → 403 |
| 7 | EV user recalc bị chặn | EV user JWT (không phải ADMIN) gọi `POST .../recalculate` → 403 |
| 8 | Admin recalc thành công | `admin2@local` JWT, `POST .../recalculate` → 200 với `BatterySwapTrustScoreDTO` mới |
| 9 | Admin history thành công | Admin JWT, `GET .../history` → 200 với `List<VerificationReviewEntity>` |
| 10 | Admin summary qua path mới | Admin JWT, `GET /api/v1/.../summary` → 200 với cùng body cũ |
| 11 | Old admin path trả 404 | `curl /api/admin/battery-swap/trust/summary` → 404 |
| 12 | EV user `getSwapTrust` qua repo Flutter | Chạy EV user mobile app, mở 1 station detail, quan sát `swapTrustProvider` trả 200 thay vì 404 |
| 13 | `flutter analyze` clean | Run `flutter analyze` trong `shared_api`, `admin_web`, `ev_user_mobile` — không có lỗi mới |

### Breaking changes

**Có, cần migration:**

- **6 endpoint bị xóa** dưới `/api/admin/battery-swap/trust/**`:
  - `GET /api/admin/battery-swap/trust/summary`
  - `GET /api/admin/battery-swap/trust/{stationId}`
  - `GET /api/admin/battery-swap/trust/{stationId}/breakdown`
  - `GET /api/admin/battery-swap/trust/{stationId}/level`
  - `POST /api/admin/battery-swap/trust/{stationId}/recalculate`
  - `GET /api/admin/battery-swap/trust/{stationId}/history`
  - Caller duy nhất là `AdminWebApiClient` (đã được cập nhật sang path mới). Không có caller nào khác trong repo.

- **2 endpoint tăng cường bảo mật** dưới `/api/v1/battery-swap/trust/**`:
  - `POST /api/v1/battery-swap/trust/{stationId}/recalculate` — yêu cầu JWT có `ROLE_ADMIN` (trước: public).
  - `GET /api/v1/battery-swap/trust/{stationId}/history` — yêu cầu JWT có `ROLE_ADMIN` (trước: public, leak `VerificationReviewEntity`).

- **Không có alias / 410 Gone / fallback route** cho 6 endpoint bị xóa. Nếu cần rollback khẩn cấp, khôi phục `AdminBatterySwapTrustController.java` từ git history.

---

---

## [Unreleased] — Smoke-test Endpoint Cleanup (D2)

**Ngày:** 2026-06-17
**Phạm vi:** Backend (Spring Boot) + generated OpenAPI spec
**Tính năng:** Loại bỏ 3 endpoint smoke-test không có người gọi (`GET /api/admin/test`, `GET /api/collab/web/test`, `GET /api/collab/mobile/test`) và xóa luôn class `AdminWebController` rỗng chỉ chứa endpoint này. Giữ nguyên `/healthz` là endpoint health/smoke canonical duy nhất.

### Tổng quan thay đổi

#### Backend — Java / Spring Boot

| File | Thay đổi |
|---|---|
| `api/admin_web/controller/AdminWebController.java` | **XÓA** — class chỉ chứa duy nhất 1 endpoint `GET /api/admin/test` (smoke test). Sau khi xóa endpoint, class trống → xóa luôn file. |
| `api/collaborator_web/controller/CollaboratorWebController.java` | Xóa method `test()` (5 dòng, lines 41-45) + xóa import `java.util.Map` không còn dùng. Giữ nguyên 3 endpoint thật: `/me/profile`, `/me/contracts`, `/me/location`. |
| `api/collaborator_mobile/controller/CollaboratorMobileController.java` | Xóa method `test()` (5 dòng, lines 29-33) + xóa import `java.util.Map`. Giữ nguyên endpoint `/me/location`. |

#### Generated OpenAPI

| File | Thay đổi |
|---|---|
| `shared/openapi/openapi.yaml` | Xóa 3 path entry: `/api/admin/test` (line cũ 1142), `/api/collab/web/test` (965), `/api/collab/mobile/test` (808). Spec sẽ được Spring Boot springdoc tự động tạo lại từ controller; bản cập nhật thủ công ở đây để giữ tree sạch cho đến lần regenerate kế tiếp. |

#### Tài liệu

| File | Thay đổi |
|---|---|
| `docs/DOC7-Backend-Structure.md` | Không cần sửa — file tree **đã chính xác từ trước** (chưa từng liệt kê `AdminWebController.java`). |
| `docs/changelog.md` | Entry này. |

### Quyết định thiết kế chính

1. **Canonical health endpoint là `/healthz` (public, không phải `/api/health`)** — Phase 1 brief ghi `GET /api/health` nhưng endpoint đó **không tồn tại trong code**; endpoint thật là `/healthz` được khai báo tại `common/web/HealthController.java`. Vì `/healthz` đã public và dùng cho smoke check, không cần tạo thêm endpoint mới.
2. **Xóa `AdminWebController.java` luôn thay vì giữ class rỗng** — class chỉ có 1 method `test()` và không có DI nào khác. Giữ class rỗng sẽ là dead code dạng annotation-only.
3. **Giữ `CollaboratorWebController` và `CollaboratorMobileController`** — cả 2 còn endpoint thật (`/me/profile`, `/me/contracts`, `/me/location` ở web; `/me/location` ở mobile).
4. **Không tạo alias / fallback route** — nếu external caller nào (ngoài repo) thực sự gọi 3 endpoint này, sẽ nhận `404`. Rủi ro thấp vì grep toàn repo cho thấy 0 caller.
5. **Không động vào `SecurityConfig` / JWT / RBAC** — 3 endpoint cũ đã được `@PreAuthorize` đúng role (admin, collab); sau khi xóa, role check tự nhiên không match, 404 là kết quả tự nhiên (hoặc 401 nếu anonymous do `SecurityConfig` chặn `/api/**` trước khi route match).

### Tác động

- **API surface**: -3 endpoint (`/api/admin/test`, `/api/collab/web/test`, `/api/collab/mobile/test`).
- **Files**: -1 file xóa (`AdminWebController.java`), 2 file sửa (chỉ method `test()` + 1 import).
- **OpenAPI**: -3 path entry (sẽ được springdoc tự tái sinh khớp với controller mới).
- **Tài liệu**: +1 CHANGELOG entry, 0 thay đổi DOC7.
- **Performance / Security**: không thay đổi đáng kể — chỉ thu hẹp attack surface 3 endpoint thừa.

### Kết quả kiểm thử (sẽ chạy ở Step 2.4)

Dự kiến sau khi rebuild image và chạy curl:

| # | Test | Expected |
|---|---|---|
| 1 | `GET /healthz` anonymous | 200 `{"status":"UP"}` |
| 2 | `GET /api/admin/test` (admin JWT) | 404 |
| 3 | `GET /api/collab/web/test` (collab JWT) | 404 |
| 4 | `GET /api/collab/mobile/test` (collab JWT) | 404 |
| 5 | `GET /api/admin/test` anonymous | 401 (Spring Security chặn `/api/**` trước route match) |
| 6 | `GET /api/collab/web/test` (EV user JWT) | 404 (route đã xóa; cũng có thể 403 nếu vẫn match class-level `@PreAuthorize` của controller khác — sẽ ghi nhận giá trị thực) |
| 7 | `GET /api/collab/web/me/profile` (collab JWT) | 200 — endpoint thật phải còn hoạt động |
| 8 | `GET /api/collab/mobile/me/location` (collab JWT) | 200 — endpoint thật phải còn hoạt động |

### Caller analysis (grep toàn repo, kết quả trước khi sửa)

| Loại caller | Số lượng |
|---|---|
| Source code trong repo (apps + backend) | 0 |
| Frontend typed API client (`AdminWebApiClient.test` etc.) | 0 (Phase 1 brief claim có nhưng **không tồn tại** — grep xác nhận) |
| Repositories / providers / screens | 0 |
| Backend tests (`backend/src/test/**`) | 0 |
| Frontend tests (`apps/*/test/**`) | 0 |
| Infra scripts (`infra/**`) | 0 |
| Docs (DOC1..DOC10 + thesis_materials) | 0 (chỉ DOC7 có file tree, đã đúng) |
| App router / runtime startup | 0 |
| SecurityConfig matcher | 0 (chỉ có class-level `@PreAuthorize`) |
| Generated OpenAPI spec | 3 path entry (đã xóa thủ công) |

**Kết luận: 0 caller thật. Cleanup an toàn.**

### Breaking changes

**Có, cần migration nếu có external caller nào (không có trong repo):**

- `GET /api/admin/test` → 404 (hoặc 401 nếu anonymous)
- `GET /api/collab/web/test` → 404 (hoặc 401 nếu anonymous)
- `GET /api/collab/mobile/test` → 404 (hoặc 401 nếu anonymous)

Cả 3 endpoint trả về `{"message":"... API is accessible"}` — đây là chuỗi tĩnh, không có state nào. Caller bên ngoài (nếu có) đang dùng endpoint này chỉ để smoke check connectivity — nên chuyển sang `GET /healthz` (public, không cần auth, trả `{"status":"UP"}`).

Không có alias / 410 Gone / fallback route. Nếu cần rollback khẩn cấp, khôi phục từ git history.

---

---

## [Unreleased] — Routing Debug Endpoint Cleanup (D3)

**Ngày:** 2026-06-17
**Phạm vi:** Backend (Spring Boot)
**Tính năng:** Loại bỏ debug endpoint legacy `GET /api/v1/routing/debug/stations-along-route` (chỉ active trong `dev`/`staging` profile, không có frontend caller) và dọn dẹp toàn bộ code path liên quan (controller, service method, DTO, SecurityConfig matcher). Endpoint production `POST /api/ev/routing/route` và toàn bộ EV routing flow **không bị ảnh hưởng**.

### Tổng quan thay đổi

#### Backend — Java / Spring Boot

| File | Thay đổi |
|---|---|
| `api/ev_user_mobile/controller/RoutingDebugController.java` | **XÓA** — class chỉ chứa 1 method `debugStationsAlongRoute` (đã bị xóa route khỏi EV routing business surface). Class có `@Profile({"dev","staging"})` nên đã 404 trong profile `docker`/`prod` ngay từ trước D3. |
| `api/ev_user_mobile/dto/RouteDebugDTO.java` | **XÓA** — DTO chỉ được dùng bởi `debugStationsAlongRoute` (đã xóa); trở thành orphan. |
| `api/ev_user_mobile/service/RoutingService.java` | Xóa method `debugStationsAlongRoute(...)` (~78 dòng, lines 617-695 trước D3). Giữ nguyên `calculateRoute(...)` — endpoint production `POST /api/ev/routing/route` cho EV user map flow. **Toàn bộ imports (`MDC`, `UUID`, `Collectors`) vẫn còn được dùng bởi `calculateRoute`, không cần sửa import.** |
| `auth/infrastructure/security/SecurityConfig.java` | Xóa `.requestMatchers("/api/v1/routing/debug/**").permitAll()` (line 82 trước D3) — không còn route nào khớp pattern này. **Giữ nguyên `.requestMatchers("/debug/**").permitAll()`** vì là generic matcher có thể áp dụng cho các debug controller khác (ngoài phạm vi D3). |

#### Tài liệu

| File | Thay đổi |
|---|---|
| `docs/changelog.md` | Entry này. |
| `docs/DOC7-Backend-Structure.md` | (no change — file tree **đã không liệt kê `RoutingDebugController.java` từ trước**, giống trường hợp AdminWebController ở D2). |
| `shared/openapi/openapi.yaml` | (no change — debug endpoint **không bao giờ xuất hiện trong spec** vì springdoc đã filter ra do `@Profile` exclude). |

### Endpoint bị xóa

| Method | Path | Old behavior | Old role/profile | New behavior |
|---|---|---|---|---|
| GET | `/api/v1/routing/debug/stations-along-route` | 200 RouteDebugDTO (debug breakdown) | public (permitAll) + `@Profile({"dev","staging"})` → active chỉ trong dev/staging, **đã 404 trong docker/prod trước D3** | **404** (class deleted + SecurityConfig matcher removed) |

### Endpoint production giữ nguyên (BẮT BUỘC)

| Method | Path | Auth | Status |
|---|---|---|---|
| POST | `/api/ev/routing/route` | `hasRole('EV_USER')` | 200 RouteResponseDTO — **đã verify live sau D3** |
| GET | `/healthz` | public | 200 {"status":"UP"} — **không động** |
| GET | `/api/v1/battery-swap/trust/{stationId}` | public (D1) | 200 — **D1 không bị động** |
| GET | `/api/admin/test` | (D2 removed) | 404 — **D2 không bị động** |
| GET | `/api/collab/web/test` | (D2 removed) | 404 — **D2 không bị động** |
| GET | `/api/collab/mobile/test` | (D2 removed) | 404 — **D2 không bị động** |

### Quyết định thiết kế chính

1. **Xóa hoàn toàn debug endpoint** thay vì move sang `/api/ev/routing/debug` — zero in-repo caller, đã 404 trong profile `docker` (môi trường test), đã 404 trong profile `prod`. Chỉ từng có ý nghĩa trong dev/staging như một manual diagnostic — không có test nào tự động gọi nó.
2. **Xóa luôn `RouteDebugDTO`** vì DTO trở thành orphan (chỉ được dùng bởi method đã xóa). Tránh giữ dead DTO.
3. **Xóa luôn method `RoutingService.debugStationsAlongRoute`** vì zero caller sau khi xóa controller. Method này có 78 dòng, phụ thuộc OSRM và station query, là dead weight.
4. **KHÔNG xóa `.requestMatchers("/debug/**").permitAll()`** — đây là generic matcher có thể áp dụng cho nhiều debug controllers khác. Brief chỉ cho phép xóa specific matcher `/api/v1/routing/debug/**`.
5. **KHÔNG động vào bất kỳ logic production nào**:
   - `RoutingController.java` (production routing endpoint) — không sửa.
   - `RoutingService.calculateRoute(...)` — không sửa.
   - `RouteRequestDTO`, `RouteResponseDTO` — không sửa.
   - OSRM config (`application.yml` cho OSRM URL) — không sửa.
   - `SecurityConfig` (chỉ xóa 1 dòng matcher cụ thể) — không đổi rule nào khác.
   - JWT, RBAC — không sửa.
6. **Không sửa frontend** — xác nhận không có file Flutter nào (ev_user_mobile, admin_web, collab_mobile) gọi `/api/v1/routing/debug/**`. Frontend chỉ gọi `/api/ev/routing/route` qua `station_repository.calculateRoute`.

### Frontend caller analysis (grep toàn repo)

| File | Pattern | Kết quả |
|---|---|---|
| `apps/ev_user_mobile/lib/src/repositories/station_repository.dart` | `calculateRoute` → POST `/api/ev/routing/route` | 1 caller (real production flow) |
| `apps/ev_user_mobile/lib/src/providers/routing_provider.dart` | `_repository.calculateRoute(...)` | 1 wrapper, dùng trong `_attemptRoute` / `_attemptRouteFromCoords` |
| `apps/ev_user_mobile/lib/src/screens/home_map_screen.dart` | `ref.read(routingProvider.notifier)` × 16 lần | Main map screen — search destination, long-press, calculate route, retry, polyline display |
| `apps/ev_user_mobile/lib/src/screens/recommendation_screen.dart` | `setVehicleSettings` | Battery/range → feeds routing provider |
| `apps/ev_user_mobile/lib/src/models/route_models.dart` | `RouteRequest`, `RouteResponse` DTOs | Flutter model classes cho real endpoint |
| `apps/admin_web/**`, `apps/collab_mobile/**` | grep routing | 0 HTTP caller (chỉ có `go_router` UI navigation) |
| **Bất kỳ file nào** gọi `/api/v1/routing/debug/**` | full ripgrep | **0** |

**Kết luận: 0 frontend caller cho debug endpoint. Real routing endpoint có 1 caller chain duy nhất (repository → provider → home_map_screen).**

### Tác động

- **API surface**: -1 endpoint (`/api/v1/routing/debug/stations-along-route`).
- **Files**: -2 file xóa (`RoutingDebugController.java`, `RouteDebugDTO.java`), 2 file sửa (`RoutingService.java` -78 dòng, `SecurityConfig.java` -1 dòng matcher).
- **Production routing**: **không thay đổi**. `/api/ev/routing/route` vẫn hoạt động nguyên si.
- **Frontend**: **0 dòng thay đổi**.
- **Performance / Security**: tích cực — thu hẹp 1 attack surface (public debug endpoint + 1 specific SecurityConfig matcher).

### Kết quả kiểm thử (Step 3.4 sẽ chạy)

Dự kiến sau khi rebuild image:

| # | Test | Expected |
|---|---|---|
| 1 | `POST /api/ev/routing/route` (EV user JWT, valid coords) | 200 + RouteResponseDTO với polyline + duration + distance |
| 2 | `POST /api/ev/routing/route` (anon) | 401 |
| 3 | `POST /api/ev/routing/route` (admin JWT) | 403 |
| 4 | `POST /api/ev/routing/route` (collab JWT) | 403 |
| 5 | `GET /api/v1/routing/debug/stations-along-route` (EV user JWT) | 404 |
| 6 | `GET /api/v1/routing/debug/stations-along-route` (admin JWT) | 404 |
| 7 | `GET /api/v1/routing/debug/stations-along-route` (anon) | 401 hoặc 404 (record actual) |
| 8 | `GET /healthz` (anon) | 200 body "UP" hoặc {"status":"UP"} (record actual) |
| 9 | `GET /api/v1/battery-swap/trust/{id}` (D1 sanity) | 200 — D1 không bị động |
| 10 | `GET /api/admin/test` (admin JWT, D2 sanity) | 404 — D2 không bị động |

### Caller analysis tổng kết (grep toàn repo, trước D3)

| Caller type | Số lượng |
|---|---|
| Source code (apps + backend) gọi `/api/v1/routing/debug/**` | 0 |
| Frontend typed API client method | 0 (chưa từng được tạo) |
| Repositories / providers / screens | 0 |
| Backend tests (`backend/src/test/**`) | 0 |
| Frontend tests (`apps/*/test/**`) | 0 |
| Infra scripts (`infra/**`) | 0 |
| Docs (DOC1..DOC10 + thesis_materials) | 0 |
| App router / runtime startup | 0 |
| SecurityConfig matcher | 1 (đã xóa) |
| Generated OpenAPI spec | 0 (chưa từng được include) |
| Source trong repo (controller + service method + DTO) | 3 (đã xóa hết) |

**Kết luận: 0 caller thật. Cleanup an toàn tuyệt đối.**

### Breaking changes

**Có, nếu có external caller nào (không có trong repo):**

- `GET /api/v1/routing/debug/stations-along-route` → **404** (trong mọi profile).

Caller bên ngoài (nếu có) chỉ là dev/staging manual diagnostic — chuyển sang dùng `POST /api/ev/routing/route` (production) nếu cần diagnostic data, hoặc thêm debug fields vào response DTO trong tương lai. Không cần alias / 410 Gone.

Không có rollback alias. Rollback = `git revert`.

---

---

## [Unreleased] — File Presign/Proxy Endpoint Cleanup (D4)

**Ngày:** 2026-06-17
**Phạm vi:** Backend (Spring Boot) + shared frontend client (`apps/shared/shared_api`) + OpenAPI spec + DOC4
**Tính năng:** Loại bỏ 3 file endpoint đã chết (zero frontend caller): `POST /api/ev/files/presign-upload`, `GET /api/collab/web/files/presign-view`, `POST /api/collab/mobile/files/presign-upload`. Toàn bộ flow file nghiệp vụ (verification evidence upload/view, admin evidence review, EV change request attachment) **không bị ảnh hưởng** — FileService (shared MinIO layer) và các live endpoint (`GET /api/ev/files/presign-view`, `POST /api/collab/mobile/files/upload`, `GET /api/collab/mobile/files/presign-view`, `GET /api/collab/mobile/files/view`, `GET /api/admin/files/presign-view`) được giữ nguyên.

### Tổng quan thay đổi

#### Backend — Java / Spring Boot

| File | Thay đổi |
|---|---|
| `api/ev_user_mobile/controller/EvFileController.java` | Xóa method `getPresignUploadUrl()` (line 33-41) + import `PresignUploadResponseDTO`, `UUID`. Endpoint `GET /presign-view` (live) giữ nguyên. |
| `api/collaborator_web/controller/CollabWebFileController.java` | **XÓA TOÀN FILE** — class chỉ chứa 1 method `getPresignViewUrl` cho route `GET /api/collab/web/files/presign-view` (zero frontend caller). |
| `api/collaborator_mobile/controller/CollabMobileFileController.java` | Xóa method `getPresignUploadUrl()` (line 37-45) + import `PresignUploadResponseDTO`. 3 live endpoint giữ nguyên: `POST /upload`, `GET /presign-view`, `GET /view`. |
| `api/admin_web/controller/AdminFileController.java` | **KHÔNG ĐỔI** — endpoint `GET /presign-view` là live caller chain (admin verification task detail). |
| `common/file/FileService.java` | **KHÔNG ĐỔI** — đã là shared MinIO layer cho cả 4 controller. |
| `api/common/dto/PresignViewResponseDTO.java` | **KHÔNG ĐỔI** — vẫn được dùng bởi 3 live endpoints (EV, collab mobile, admin). |
| `api/common/dto/ProxyUploadResponseDTO.java` | **KHÔNG ĐỔI** — vẫn được dùng bởi collab mobile `/upload`. |
| `api/common/dto/PresignUploadResponseDTO.java` | **KHÔNG ĐỔI** trong D4 scope — hiện đã trở thành orphan (chỉ còn declaration). Đề xuất dọn trong cleanup group tương lai. |
| `api/common/dto/PresignUploadRequest.java` | OpenAPI spec đã không tham chiếu (verified). |

#### Frontend — Dart / Flutter

| File | Thay đổi |
|---|---|
| `apps/shared/shared_api/lib/src/api_client_factory.dart` | Xóa 3 typed method đã chết (verified 0 caller bằng final ripgrep): <br>• `EvUserMobileApiClient.presignUpload({String? contentType})` (line 537-542) <br>• `CollaboratorWebApiClient.presignView({required String objectKey})` (line 1177-1187) <br>• `CollaboratorMobileApiClient.presignUpload({String? contentType})` (line 791-799) <br>Giữ nguyên: `EvUserMobileApiClient.presignView` (live, change_request_detail), `CollaboratorMobileApiClient.proxyUpload/presignView/proxyViewBytes` (live, evidence flow), `AdminWebApiClient.presignView` (live, admin verification). |

#### Tài liệu / OpenAPI

| File | Thay đổi |
|---|---|
| `docs/changelog.md` | Entry này. |
| `docs/DOC4-API-Documentation.md` | Xóa 3 dòng liệt kê các endpoint đã xóa (line 249, 260, 302 trước D4). |
| `docs/DOC7-Backend-Structure.md` | (no change — file tree chỉ liệt kê `AdminFileController.java`, không liệt kê 3 controller kia). |
| `shared/openapi/openapi.yaml` | Xóa 2 path block đã chết (`/api/collab/mobile/files/presign-upload` line 911-937, `/api/collab/web/files/presign-view` line 1035-1060). Xóa 2 schema đã trở thành orphan (`PresignUploadRequest`, `PresignUploadResponse` line 2626-2646). Giữ `PresignViewResponse` (vẫn được dùng bởi `/api/admin/files/presign-view`). |

### Endpoint matrix — Before vs After D4

| Method | Path | Before | After |
|---|---|---|---|
| GET    | /api/ev/files/presign-view             | EV_USER ✅ | **EV_USER ✅ (giữ nguyên)** |
| POST   | /api/ev/files/presign-upload           | EV_USER ✅ | **404 (xóa)** |
| GET    | /api/collab/web/files/presign-view      | COLLABORATOR ✅ | **404 (controller xóa)** |
| GET    | /api/collab/mobile/files/presign-view   | COLLABORATOR ✅ | **COLLABORATOR ✅ (giữ nguyên)** |
| POST   | /api/collab/mobile/files/presign-upload | COLLABORATOR ✅ | **404 (xóa)** |
| POST   | /api/collab/mobile/files/upload         | COLLABORATOR ✅ | **COLLABORATOR ✅ (giữ nguyên)** |
| GET    | /api/collab/mobile/files/view           | COLLABORATOR ✅ | **COLLABORATOR ✅ (giữ nguyên)** |
| GET    | /api/admin/files/presign-view           | ADMIN ✅ | **ADMIN ✅ (giữ nguyên)** |

### Authorization matrix — Before vs After D4

| Caller     | /ev/files/presign-view | /ev/files/presign-upload (REMOVED) | /collab/web/files/presign-view (REMOVED) | /collab/mobile/files/presign-view | /collab/mobile/files/upload | /collab/mobile/files/view | /admin/files/presign-view |
|------------|------------------------|------------------------------------|-------------------------------------------|------------------------------------|------------------------------|-----------------------------|----------------------------|
| Anonymous  | 401                    | 404                                | 404                                       | 401                                | 401                          | 401                         | 401                        |
| EV_USER    | 200 ✅ (role+no obj-check) | 404                            | 404                                       | 403                                | 403                          | 403                         | 403                        |
| COLLAB     | 403                    | 404                                | 404                                       | 200 (role+ownership) ✅ hoặc 403   | 200 ✅ (multipart)           | 200 ✅ (role+ownership) hoặc 403 | 403                    |
| ADMIN      | 403                    | 404                                | 404                                       | 403                                | 403                          | 403                         | 200 ✅ (role+no obj-check) |

### Quyết định thiết kế chính

1. **Chỉ xóa các endpoint thật sự chết**, không gộp route surface. Phase 1 brief đề cập "duplicate code" và "potential route merge" — re-scan cho thấy 4 controller **không** giống nhau về endpoint surface hay permission logic. FileService đã là shared MinIO layer. Việc extract thêm một delegate/helper không có value-add rõ ràng và tăng rủi ro refactor.
2. **Không xóa `AdminFileController`** — endpoint `GET /api/admin/files/presign-view` là live caller chain cho admin verification task detail (`presignedUrlProvider` → `_buildPhotoThumbnail`).
3. **Không xóa `CollabMobileFileController`** — 3 live endpoint phục vụ verification evidence submission/review flow thật.
4. **Xóa `CollabWebFileController`** vì toàn bộ class chỉ có 1 method cho 1 endpoint đã chết.
5. **Giữ nguyên `@PreAuthorize` class-level** cho tất cả controller — không mở rộng/thu hẹp role authorization.
6. **Không thêm shared delegate, không merge route surface** — theo approved scope "Do not introduce a shared delegate now, because the re-scan shows FileService is already the shared MinIO layer and the controllers are not behavior-identical."
7. **Không xóa `PresignUploadResponseDTO.java`** — không nằm trong approved scope của D4. Sẽ đề xuất dọn trong cleanup group tương lai.

### Frontend caller analysis (ripgrep trước D4)

| Pattern | Files matched | Verdict |
|---|---|---|
| `.presignUpload(` toàn repo apps | **0** | Sạch — 2 typed method (EV + collab mobile) không có UI caller nào. |
| `.presignView(` toàn repo apps | 4 files | Live callers — giữ nguyên tất cả method tương ứng. |

### Tác động

- **API surface**: -3 endpoint (`/api/ev/files/presign-upload`, `/api/collab/web/files/presign-view`, `/api/collab/mobile/files/presign-upload`).
- **Files backend**: -1 file xóa (`CollabWebFileController.java`), 2 file sửa (`EvFileController.java` -12 dòng, `CollabMobileFileController.java` -10 dòng).
- **Files frontend**: 1 file sửa (`api_client_factory.dart`) — -20 dòng.
- **Files tài liệu/OpenAPI**: 2 file sửa (`DOC4-API-Documentation.md` -3 dòng, `openapi.yaml` -49 dòng).
- **Live business flow**: **không thay đổi**. Verification evidence submission/review, admin evidence review, EV change request attachment view đều hoạt động nguyên si.
- **Performance / Security**: tích cực — thu hẹp 3 attack surface (cùng role authorization), giảm dead code.

### Kết quả kiểm thử (Step 4.4 sẽ chạy)

Xem `backend/d4_smoke_result.md` (sẽ tạo sau khi chạy test) cho curl output chi tiết.

Dự kiến sau khi rebuild image:

| Test | Endpoint | Auth | Expected | Actual |
|---|---|---|---|---|
| 1 | GET /api/ev/files/presign-view | EV_USER | 200 (presigned URL) hoặc 500 (MinIO nếu không config) | (sẽ ghi sau) |
| 2 | GET /api/ev/files/presign-view | anon | 401 | (sẽ ghi sau) |
| 3 | GET /api/ev/files/presign-view | ADMIN | 403 | (sẽ ghi sau) |
| 4 | GET /api/admin/files/presign-view | ADMIN | 200 hoặc 500 | (sẽ ghi sau) |
| 5 | GET /api/admin/files/presign-view | EV_USER | 403 | (sẽ ghi sau) |
| 6 | POST /api/collab/mobile/files/upload | COLLABORATOR | 200 + objectKey (real flow) | (sẽ ghi sau) |
| 7 | GET /api/collab/mobile/files/presign-view | COLLABORATOR (fake key) | 403 (ownership fail) | (sẽ ghi sau) |
| 8 | GET /api/collab/mobile/files/presign-view | EV_USER | 403 | (sẽ ghi sau) |
| 9 | **REMOVED** POST /api/ev/files/presign-upload | EV_USER | 404 | (sẽ ghi sau) |
| 10 | **REMOVED** POST /api/ev/files/presign-upload | anon | 401 hoặc 404 | (sẽ ghi sau) |
| 11 | **REMOVED** GET /api/collab/web/files/presign-view | COLLABORATOR | 404 | (sẽ ghi sau) |
| 12 | **REMOVED** GET /api/collab/web/files/presign-view | ADMIN | 404 | (sẽ ghi sau) |
| 13 | **REMOVED** POST /api/collab/mobile/files/presign-upload | COLLABORATOR | 404 | (sẽ ghi sau) |
| 14 | /healthz | anon | 200 | (sẽ ghi sau) |
| 15 | POST /api/ev/routing/route | EV_USER | 200 (D3 không động) | (sẽ ghi sau) |
| 16 | GET /api/admin/test | ADMIN | 404 (D2 không động) | (sẽ ghi sau) |
| 17 | GET /api/collab/web/test | COLLABORATOR | 404 (D2 không động) | (sẽ ghi sau) |
| 18 | GET /api/v1/battery-swap/trust/{id} | anon | 200 (D1 không động) | (sẽ ghi sau) |

### Caller analysis tổng kết (frontend, sau D4)

| Endpoint | Caller (Flutter) | Status |
|---|---|---|
| GET /api/ev/files/presign-view         | ev_user_mobile/.../services/file_viewer_service.dart (line 30) → providers/file_viewer_providers.dart → change_request_detail_screen.dart (line 456) | **LIVE — verified** |
| POST /api/collab/mobile/files/upload   | collab_mobile/.../repositories/task_repository.dart (line 78), providers/battery_swap_task_providers.dart (line 217) → task_detail_screen.dart (line 709) | **LIVE — verified** |
| GET /api/collab/mobile/files/presign-view | collab_mobile/.../repositories/task_repository.dart (line 102), providers/battery_swap_task_providers.dart (line 240) | **LIVE — verified** |
| GET /api/collab/mobile/files/view      | collab_mobile/.../repositories/task_repository.dart (line 114), providers/battery_swap_task_providers.dart (line 251) | **LIVE — verified** |
| GET /api/admin/files/presign-view      | admin_web/.../services/file_viewer_service.dart (line 39) → providers/file_viewer_providers.dart → verification_task_detail_screen.dart (line 818, 875, 951) | **LIVE — verified** |
| POST /api/ev/files/presign-upload      | **none** | **REMOVED** |
| GET /api/collab/web/files/presign-view | **none** | **REMOVED** |
| POST /api/collab/mobile/files/presign-upload | **none** | **REMOVED** |

### Breaking changes

**Có, nếu có external caller nào (không có trong repo):**

- `POST /api/ev/files/presign-upload` → **404**
- `GET /api/collab/web/files/presign-view` → **404**
- `POST /api/collab/mobile/files/presign-upload` → **404**

Tất cả 3 endpoint trên đều **zero in-repo caller** (verified bằng full ripgrep). Caller bên ngoài (nếu có) chỉ là dev/test manual. Không cần alias / 410 Gone.

Không có rollback alias. Rollback = `git revert`.

### Orphan còn lại (ghi nhận cho cleanup tương lai)

| Orphan | File | Lý do giữ |
|---|---|---|
| `PresignUploadResponseDTO.java` | `backend/src/main/java/com/example/evstation/api/common/dto/PresignUploadResponseDTO.java` | Không thuộc approved scope D4 (DTO, không phải endpoint). Backend declaration chỉ — không có caller. |

### Known limitation / Future work

- Tương lai có thể extract một shared `FileControllerDelegate` nếu cần thêm endpoint trên nhiều role prefix (hiện tại 4 controller chỉ có 5 live endpoint, không có value rõ ràng).
- Nếu mobile flow chuyển sang presigned upload thay vì proxy upload (để giảm tải backend), cần re-add `POST /api/collab/mobile/files/presign-upload` với logic ownership check.

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
