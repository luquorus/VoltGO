# DOC 6 — Frontend Structure (Flutter)

---

## 6.1 Repository Structure

The Flutter code is organized as a monorepo under `apps/` and `apps/shared/`:

```
apps/
├── admin_web/          # Admin web portal (Flutter web)
├── collab_mobile/      # Collaborator mobile app
├── ev_user_mobile/     # EV user mobile app
└── hardware_simulator/  # Hardware display simulator (desktop/web)
apps/shared/
├── shared_ui/          # Reusable widgets, theme, common components
├── shared_auth/         # Auth state, token storage, auth service
├── shared_network/      # Dio HTTP client, error interceptors
└── shared_api/         # Typed API client from api_client_factory.dart
```

**Note:** There is NO `melos.yaml` in this project. The monorepo is managed by placing all apps and shared packages under the `apps/` directory.

---

## 6.2 Shared Packages

### `shared_auth`

Provides authentication infrastructure consumed by all apps.

- **`auth_service.dart`** — Dio-based HTTP calls to `/auth/login` and `/auth/register`. On success, persists token via `TokenStorage` and updates `AuthStateNotifier`.
- **`token_storage.dart`** — Platform-adaptive token storage using `SharedPreferences` on mobile and `html` `localStorage` on web. Also handles `vehicle_settings_storage.dart` for vehicle configuration.
- **`auth_state.dart`** — Defines `AuthState` (userId, email, role, token, status) and `AuthStateNotifier` (Riverpod StateNotifier). Handles login, logout.

### `shared_network`

Provides the configured Dio HTTP client.

- **`dio_client.dart`** — Creates a `Dio` instance with:
  - Base URL from `VoltGoEnv.apiBaseUrl`
  - Connect timeout: 30s, receive timeout: 30s
  - `ErrorInterceptor` for parsing API error responses
  - Conditional `Web` adapter for web compatibility
  - Request/response logging (debug mode only)

### `shared_ui`

Reusable visual components used across all apps.

- **`theme/app_theme.dart`** — Defines `VoltGoTheme` using Material 3 `ColorScheme.fromSeed`. Primary seed color: `#2E7D32` (green energy theme).
- **`widgets/badges/score_badge.dart`** — Displays trust/risk scores as colored chips.
- **`widgets/inputs/search_field.dart`** — Reusable search input widget.
- **`widgets/cards/audit_card.dart`** — Audit log card widget.
- **`widgets/buttons/primary_button.dart`** — Reusable primary button.
- **`utils/error_formatter.dart`** — Error formatting utilities.

### `shared_api`

Typed API client classes for all endpoints. All typed methods are defined in `api_client_factory.dart`:
- `AuthApiClient` — `/auth/**`
- `EvUserMobileApiClient` — `/api/ev/**`
- `CollaboratorMobileApiClient` — `/api/collab/mobile/**` and `/api/mobile/collab/**`
- `CollaboratorWebApiClient` — `/api/collab/web/**`
- `PublicApiClient` — `/api/public/**`
- `AdminWebApiClient` — `/api/admin/**`

---

## 6.3 State Management — Riverpod

**Architecture pattern:** All app state is managed via Riverpod providers.

1. **Model** (`models/`) — Plain Dart classes representing API responses.
2. **Repository** (`repositories/`) — Calls `shared_api`, handles raw JSON → model mapping.
3. **Provider** (`providers/`) — Riverpod providers that call repositories, handle loading/error states via `AsyncValue`, expose state to UI.

Example pattern (from `ev_user_mobile`):

```dart
// Repository
class StationRepository {
  final ApiClient _api;
  Future<List<NearbyStation>> getNearby(...) async {
    final response = await _api.ev.getStations(...);
    return NearbyStation.fromJson(response);
  }
}

// Provider (Riverpod)
final nearbyStationsProvider = FutureProvider.family<List<NearbyStation>, (double,double,double)>(
  (ref, params) => StationRepository().getNearby(...),
);
```

**Key providers used:**
- `authStateProvider` — Global auth state (token, user info, role).
- `apiClientProvider` — Configured Dio instance.
- `tokenStorageProvider` — Platform-adaptive token persistence.
- Feature-specific providers per app.

---

## 6.4 Navigation — GoRouter

GoRouter provides declarative routing with role-based guards.

**Key features:**
- Deep linking: Routes map directly to URLs (web) or paths (mobile).
- Route guards: `Redirect` callback checks `authStateProvider`. Unauthenticated users redirect to `/login`.
- Shell routes: Admin web uses nested routes with `ShellRoute` for persistent side navigation.
- Path parameters: `/stations/:id`, `/bookings/:id`, etc.

---

## 6.5 Key Screens by Application

### EV User Mobile (`ev_user_mobile`)

**Screens (29 total):**

| Screen | File | Description |
|---|---|---|
| Splash | `splash_screen.dart` | App logo, env loading |
| Login | `login_screen.dart` | Email+password auth |
| Register | `register_screen.dart` | Registration with optional referral code |
| Home Map | `home_map_screen.dart` | OpenStreetMap với station markers, routing *(Redesigned 2026-06-20: 1 search bar, modal filter sheet, 2-mode bottom sheet, SelectedStationPreview khi chọn trạm)* |
| Station Detail | `station_detail_screen.dart` | Station info, availability, book/rate buttons *(Updated 2026-06-20: tích hợp `StationRatingSection` ở compact mode)* |
| Booking | `create_booking_with_charger_unit_screen.dart` | Time slot selection and booking |
| Booking Detail | `booking_detail_screen.dart` | Booking info and actions |
| Booking List | `booking_list_screen.dart` | List of user bookings |
| Recommendation | `recommendation_screen.dart` | AI-powered personalized recommendations |
| Battery Swap | `battery_swap_screen.dart` | Swap stations list *(Updated 2026-06-20: tích hợp `StationRatingSection` ở compact mode ở main screen + station detail sheet)* |
| Battery Swap Reservation | `battery_swap_reservation_screen.dart` | Reserve flow |
| Battery Swap Booking Sheet | `battery_swap_booking_sheet.dart` | Swap booking bottom sheet |
| Battery Swap CR Detail | `battery_swap_change_request_detail_screen.dart` | Swap CR detail |
| Change Request List | `change_request_list_screen.dart` | User's change requests |
| Change Request Detail | `change_request_detail_screen.dart` | CR detail |
| Change Request Create | `change_request_create_screen.dart` | Submit new CR *(Updated 2026-06-20: thêm dropdown Parking với 4 options PAID/FREE/STREET_PARKING/UNKNOWN, auto-fill từ station detail)* |
| My Issues | `my_issues_screen.dart` | User's reported issues |
| Loyalty Home | `loyalty_home_screen.dart` | Points, tier overview |
| My Vouchers | `loyalty/my_vouchers_screen.dart` | Redeemed vouchers |
| Voucher Catalog | `loyalty/voucher_catalog_screen.dart` | Available vouchers to redeem |
| Voucher Detail | `loyalty/voucher_detail_screen.dart` | Voucher detail |
| Badge Collection | `badge_collection_screen.dart` | Earned badges |
| Point History | `point_history_screen.dart` | Points transaction history |
| Rate Station | `rate_station_screen.dart` | Submit station rating |
| Referral | `referral_screen.dart` | Referral code management |
| Profile | `profile_screen.dart` | View/edit profile, password change |
| Edit Profile | `edit_profile_screen.dart` | Edit profile form |
| Notifications | `notifications_screen.dart` | User notifications |
| Forbidden | `forbidden_screen.dart` | Access denied screen |

**Providers (10 total):**
`auth_state_provider`, `booking_providers`, `battery_swap_change_request_providers`, `change_request_providers`, `file_viewer_providers`, `issue_providers`, `loyalty_providers`, `notification_provider`, `profile_providers`, `routing_provider`, `station_providers`

> **Update 2026-06-20:** `station_providers` thêm `.where((s) => s['supportsBatterySwap'] != true)` trong `StationSearchNotifier` (search by name + 2 nearby modes) để tab Charging không trộn trạm battery-swap-only.

**Repositories (6 total):**
`booking_repository`, `battery_swap_change_request_repository`, `change_request_repository`, `issue_repository`, `profile_repository`, `station_repository`

**Custom Widgets (2026-06-20 — 4 mới):**
- `widgets/compact_station_card.dart` — `CompactStationCard` (charging/hybrid, tối đa 3 badge) + `CompactSwapStationCard` (swap-only).
- `widgets/filter_bottom_sheet.dart` — `HomeMapFilterState` + `FilterBottomSheet` (modal sheet thay cho AlertDialog cũ).
- `widgets/selected_station_preview.dart` — `SelectedStationPreview` (preview card lớn khi user chọn 1 station trên map).
- `widgets/rating/station_rating_section.dart` — `StationRatingSection` widget dùng chung cho cả charging + battery swap screen, watch `stationRatingSummaryProvider` + `eligibleStationsForRatingProvider`.

---

### Admin Web (`admin_web`)

**Screens (52 total) — organized in `screens/` and `screens/[feature]/`:**

| Screen | Location | Description |
|---|---|---|
| Login | `screens/login_screen.dart` | Admin login |
| Home/Dashboard | `screens/home_screen.dart` | Overview stats |
| Analytics Dashboard | `screens/analytics_dashboard_screen.dart` | Detailed analytics |
| Charging Stations | `screens/charging_stations_screen.dart` | Charging station management |
| Charging Stations List | `screens/charging_stations_list_screen.dart` | Paginated charging station table |
| Unified Stations List | `screens/unified_stations_list_screen.dart` | Combined station list (charging + battery swap tabs) |
| Station Detail | `screens/station_detail_screen.dart` | Station edit/view |
| Create Station | `screens/create_station_screen.dart` | Create charging station |
| CSV Import | `screens/csv_import_screen.dart` | Bulk import CSV |
| Unified Change Requests | `screens/unified_change_requests_screen.dart` | Combined CR list (charging + battery swap tabs) |
| CR Detail | `screens/change_request_detail_screen.dart` | CR review |
| CR Audit | `screens/change_request_audit_screen.dart` | CR audit log |
| Collaborators | `screens/collaborator_management_screen.dart` | Collaborator management |
| Collaborator Detail | `screens/collaborator_detail_screen.dart` | Collaborator profile |
| Collaborator Performance | `screens/collaborator_performance_screen.dart` | Performance overview |
| Collaborator Performance Detail | `screens/collaborator_performance_detail_screen.dart` | Individual performance |
| Contract Detail | `screens/contract_detail_screen.dart` | Contract view |
| Verification Tasks List | `screens/verification_tasks_list_screen.dart` | Task list |
| Verification Task Detail | `screens/verification_task_detail_screen.dart` | Task review |
| Station Audit | `screens/station_audit_screen.dart` | Station audit log |
| Audit Query | `screens/audit_query_screen.dart` | Cross-entity audit search |
| Charging Trust | `screens/charging_trust_dashboard_screen.dart` | Trust score management |
| Swap Trust | `screens/battery_swap_trust_dashboard_screen.dart` | Battery swap trust |
| Issues List | `screens/issues_list_screen.dart` | Issue table |
| Issue Detail | `screens/issue_detail_screen.dart` | Issue resolution |
| Registration Requests List | `screens/registration_requests_list_screen.dart` | Collaborator applications |
| Registration Request Detail | `screens/registration_request_detail_screen.dart` | Application review |
| Profile | `screens/profile_screen.dart` | Admin profile |
| Edit Profile | `screens/edit_profile_screen.dart` | Edit profile |
| Battery Swap Station Detail | `screens/battery_swap_station_detail_screen.dart` | Swap station edit |
| Create Battery Swap Station | `screens/battery_swap/create_battery_swap_station_screen.dart` | Create swap station |
| Battery Swap CSV Import | `screens/battery_swap/battery_swap_csv_import_screen.dart` | Import CSV |
| Battery Swap CR List | `screens/battery_swap_cr_list_screen.dart` | Swap CR list |
| Battery Swap CR Detail | `screens/battery_swap_cr_detail_screen.dart` | Swap CR review |
| Loyalty Dashboard | `screens/loyalty/loyalty_dashboard_screen.dart` | Loyalty overview |
| User Loyalty List | `screens/loyalty/user_loyalty_list_screen.dart` | All loyalty users |
| User Loyalty Detail | `screens/loyalty/user_loyalty_detail_screen.dart` | User loyalty profile |
| Rating Moderation | `screens/loyalty/rating_moderation_screen.dart` | Rate moderation |
| Voucher Management | `screens/loyalty/voucher_management_screen.dart` | Voucher CRUD |

**Models (19 total):**
`admin_change_request`, `admin_issue`, `admin_station`, `admin_verification_task`, `audit_log`, `battery_swap_change_request`, `battery_swap_station`, `battery_swap_trust`, `collaborator_candidate`, `collaborator_performance`, `collaborator_profile`, `contract`, `dashboard_stats`, `pagination_response`, `presign_view_response`, `registration_request`, `simulator_models`, `station_trust`, `station_trust_summary`

**Providers (18+ total):**
`audit_log_providers`, `battery_swap_cr_providers`, `battery_swap_station_providers`, `battery_swap_trust_providers`, `change_request_providers`, `collaborator_performance_providers`, `collaborator_providers`, `contract_providers`, `dashboard_providers`, `file_viewer_providers`, `issue_providers`, `loyalty_providers`, `profile_providers`, `registration_request_providers`, `station_providers`, `station_trust_providers`, `verification_task_providers`

**Repositories (4 total):**
`audit_log_repository`, `profile_repository`, `station_trust_repository`

---

### Collaborator Mobile (`collab_mobile`)

**Screens (19 total — 4 added 2026-06):**

| Screen | Description |
|---|---|
| `splash_screen.dart` | App initialization |
| `login_screen.dart` | Email+password auth |
| `register_screen.dart` | Registration form |
| `registration_form_screen.dart` | Full registration details |
| `registration_pending_screen.dart` | Pending approval screen |
| `dashboard_overview_screen.dart` | KPI overview |
| `task_list_screen.dart` | Assigned verification tasks |
| `task_detail_screen.dart` | Task info and actions |
| `swap_task_list_screen.dart` | Battery swap tasks |
| `swap_verification_task_detail_screen.dart` | Swap task detail |
| `contracts_screen.dart` | Contract list |
| `profile_screen.dart` | Profile view |
| `edit_profile_screen.dart` | Edit profile |
| `notifications_screen.dart` | Notifications |
| `forbidden_screen.dart` | Access denied |

**Providers (7 total — 1 added 2026-06):**
`battery_swap_task_providers`, `change_request_providers` (NEW), `contracts_provider`, `dashboard_provider`, `notification_provider`, `profile_providers`, `task_providers`

**Repositories (4 total — 2 added 2026-06):**
`change_request_repository` (NEW), `battery_swap_change_request_repository` (NEW), `profile_repository`, `task_repository`

**Bottom Navigation (UPDATED 2026-06):** Migrated from `BottomNavigationBar` to Material 3 `NavigationBar` to support 6 destinations: **Home / Charging / Swap / Requests (NEW) / Notifications / Profile**. The Requests tab is reachable at `/change-requests`.

---

### Hardware Simulator (`hardware_simulator`)

**Screens (2 total):**
- `simulator_screen.dart` — Main simulator display
- `station_display_screen.dart` — Station display with WebSocket

**Services:**
- `display_websocket_service.dart` — WebSocket connection for receiving swap codes

---

## 6.6 Key Flutter Packages and Their Purpose

| Package | Version (range) | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.4 | Reactive state management |
| `go_router` | ^13.x | Declarative routing |
| `dio` | ^5.4 | HTTP client with interceptors |
| `flutter_map` | ^7.0 | OpenStreetMap rendering |
| `latlong2` | ^0.9 | Coordinate types, distance |
| `geolocator` | ^10.1 | GPS location access |
| `fl_chart` | ^0.68 | Dashboard charts |
| `file_picker` | ^9.0 | CSV file selection |
| `flutter_dotenv` | ^5.1 | Environment variables |
| `intl` | ^0.19 | Date/time formatting |
| `web_socket_channel` | ^2.4 | WebSocket client |
| `flutter_secure_storage` | ^9.0 | Secure token storage (shared_auth) |
| `shared_preferences` | ^2.2 | Token storage fallback |
| `image_picker` | ^1.1 | Camera/gallery (collab_mobile) |
| `font_awesome_flutter` | ^10.6 | Icons |

---

## 6.7 Environment Configuration (`.env`)

Each app uses `flutter_dotenv` to load environment variables:

```env
# EV User Mobile
API_BASE_URL=http://10.0.2.2:8080/api
TOKEN_KEY=voltgo_token

# Admin Web
API_BASE_URL=http://localhost:8080/api

# Hardware Simulator
API_BASE_URL=http://localhost:8080
WS_BASE_URL=ws://localhost:8080

# Collaborator Mobile
API_BASE_URL=http://10.0.2.2:8080/api
```

---

## 6.8 Stats Summary

| App | Screens | Providers | Repositories | Models |
|---|---|---|---|---|
| `ev_user_mobile` | 29 | 11 | 6 | (in providers) |
| `admin_web` | 54+ | 18+ | 4 | 19 |
| `collab_mobile` | 15 | 6 | 2 | (in providers) |
| `hardware_simulator` | 2 | (display_providers.dart) | 0 | 0 |
| **Shared** | — | — | — | — |
| `shared_auth` | — | — | — | — |
| `shared_network` | — | — | — | — |
| `shared_ui` | — | — | — | — |
| `shared_api` | — | — | — | — |
| **Total** | **~100** | **~35** | **~12** | **~19** |
