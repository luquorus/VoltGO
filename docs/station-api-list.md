# VoltGO — Station API Reference

> Danh sách toàn bộ API endpoint liên quan đến **station** (trạm sạc + trạm đổi pin) trong hệ thống VoltGO.
> Bao gồm: truy vấn, chi tiết, khuyến nghị, đặt chỗ, đổi pin, change request, quản trị, audit log, issue, AI, trust score…
>
> **Cập nhật:** 18/06/2026

---

## Mục lục

1. [EV User Mobile — Charging Station](#1-ev-user-mobile--charging-station)
2. [EV User Mobile — Battery Swap Station](#2-ev-user-mobile--battery-swap-station)
3. [EV User Mobile — Booking & Payment](#3-ev-user-mobile--booking--payment)
4. [EV User Mobile — Change Request](#4-ev-user-mobile--change-request)
5. [EV User Mobile — Issue Report](#5-ev-user-mobile--issue-report)
6. [EV User Mobile — AI Recommendations & Routing](#6-ev-user-mobile--ai-recommendations--routing)
7. [EV User Mobile — Loyalty / Rating](#7-ev-user-mobile--loyalty--rating)
8. [Collaborator Mobile — Station & Change Request](#8-collaborator-mobile--station--change-request)
9. [Collaborator Web — Profile & Location](#9-collaborator-web--profile--location)
10. [Admin Web — Station Management](#10-admin-web--station-management)
11. [Admin Web — Battery Swap Station Management](#11-admin-web--battery-swap-station-management)
12. [Admin Web — Change Request Management](#12-admin-web--change-request-management)
13. [Admin Web — Battery Swap Change Request](#13-admin-web--battery-swap-change-request)
14. [Admin Web — Audit Log](#14-admin-web--audit-log)
15. [Admin Web — Issue Management](#15-admin-web--issue-management)
16. [Admin Web — Dashboard & Analytics](#16-admin-web--dashboard--analytics)
17. [Admin Web — Loyalty / Rating Moderation](#17-admin-web--loyalty--rating-moderation)
18. [Public API — Battery Swap Display](#18-public-api--battery-swap-display)
19. [Battery Swap Trust Score](#19-battery-swap-trust-score)
20. [WebSocket](#20-websocket)

---

## 1. EV User Mobile — Charging Station

**Base path:** `/api/ev/stations` · **Auth:** `ROLE_EV_USER`
**Controller:** `EvUserMobileController`, `ChargerUnitController`, `AvailabilityController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 1.1 | `GET` | `/api/ev/stations` | Tìm trạm đã publish trong bán kính (cả charging-only, battery-swap-only, hybrid). Query: `lat`, `lng`, `radiusKm`, `minPowerKw?`, `hasAC?`, `page?`, `size?`. Trả về `PaginationResponse<StationListItemDTO>`. Mỗi item có: `chargingSummary` (charging ports), `batterySwap` (piles/pins — null nếu trạm không hỗ trợ), `supportsBatterySwap` (bool). |
| 1.2 | `GET` | `/api/ev/stations/{stationId}` | Lấy chi tiết trạm đã publish. Nếu trạm hỗ trợ battery swap, `batterySwap` (SwapServiceInfoDTO) chứa `totalBatteries`, `avgChargePowerKw`, `availableBatteries`. |
| 1.3 | `GET` | `/api/ev/stations/search/by-name` | Tìm trạm theo tên (case-insensitive, partial match). Chỉ trả về bản PUBLISHED. Cùng schema `StationListItemDTO` như 1.1. |
| 1.4 | `POST` | `/api/ev/stations/recommendations` | Gợi ý trạm tối ưu dựa trên mức pin, dung lượng pin, mức pin mục tiêu. Tối ưu tổng thời gian (đi + sạc). Body: `RecommendationRequestDTO`. |
| 1.5 | `GET` | `/api/ev/stations/{stationId}/charger-units` | Lấy danh sách charger units (active) của một trạm. Trả về `List<ChargerUnitDTO>`. |
| 1.6 | `GET` | `/api/ev/stations/{stationId}/availability` | Lấy ma trận khả dụng của các slot theo ngày. Query: `date` (YYYY-MM-DD), `tz?`, `slotMinutes?` (mặc định 30), `powerType?`, `minPowerKw?`. |

---

## 2. EV User Mobile — Battery Swap Station

**Base path:** `/api/ev/battery-swap` · **Auth:** `ROLE_EV_USER`
**Controller:** `EvBatterySwapController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 2.1 | `GET` | `/api/ev/battery-swap/stations` | Danh sách trạm đổi pin gần vị trí hiện tại. Query: `lat`, `lng`, `radiusKm?` (mặc định 15). |
| 2.2 | `GET` | `/api/ev/battery-swap/stations/{stationId}` | Chi tiết trạm đổi pin kèm swap piles và slots. |
| 2.3 | `POST` | `/api/ev/battery-swap/reservations` | Đặt chỗ (reserve) một slot đổi pin. Body: `BatterySwapReserveRequestDTO`. |
| 2.4 | `POST` | `/api/ev/battery-swap/reservations/{id}/confirm-arrival` | User xác nhận đã đến trạm. |
| 2.5 | `POST` | `/api/ev/battery-swap/reservations/{id}/start` | Bắt đầu đổi pin, sinh swap code (Flow 2 — code required), broadcast tới simulator. |
| 2.6 | `POST` | `/api/ev/battery-swap/reservations/{id}/pay` | Mô phỏng thanh toán cho reservation đổi pin. |
| 2.7 | `POST` | `/api/ev/battery-swap/reservations/{id}/cancel` | Huỷ reservation đổi pin. |
| 2.8 | `GET` | `/api/ev/battery-swap/reservations/mine` | Danh sách reservation đổi pin của user hiện tại. |
| 2.9 | `GET` | `/api/ev/battery-swap/reservations/{id}` | Chi tiết một reservation đổi pin. |
| 2.10 | `GET` | `/api/ev/battery-swap/reservations/{id}/swap-code` | Lấy swap code đang active của reservation. |
| 2.11 | `POST` | `/api/ev/battery-swap/reservations/{id}/verify-swap` | Xác minh swap code và xác nhận hoàn tất đổi pin (user app gọi). Body: `{swapCode}`. |
| 2.12 | `GET` | `/api/ev/battery-swap/slots/{slotId}/charging` | Lấy thông tin charging session của một slot. Trả về 204 nếu chưa có. |

---

## 3. EV User Mobile — Booking & Payment

**Base path:** `/api/ev/bookings`, `/api/ev/payments` · **Auth:** `ROLE_EV_USER`
**Controller:** `BookingController`, `PaymentController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 3.1 | `POST` | `/api/ev/bookings` | Tạo booking trạng thái HOLD (giữ chỗ 10 phút). Yêu cầu trạm phải có bản published. |
| 3.2 | `GET` | `/api/ev/bookings/mine` | Danh sách booking của user hiện tại (phân trang). |
| 3.3 | `GET` | `/api/ev/bookings/{id}` | Chi tiết một booking (chỉ nếu thuộc về user hiện tại). |
| 3.4 | `POST` | `/api/ev/bookings/{id}/cancel` | Huỷ booking (chỉ khi HOLD hoặc CONFIRMED). |
| 3.5 | `POST` | `/api/ev/bookings/{bookingId}/payment-intent` | Tạo payment intent cho booking HOLD (mỗi booking chỉ có 1 intent). |
| 3.6 | `POST` | `/api/ev/payments/{intentId}/simulate-success` | Mô phỏng thanh toán thành công — chuyển booking HOLD → CONFIRMED. Idempotent. |
| 3.7 | `POST` | `/api/ev/payments/{intentId}/simulate-fail` | Mô phỏng thanh toán thất bại — giữ booking ở HOLD cho tới khi hết hạn. |

---

## 4. EV User Mobile — Change Request

**Base path:** `/api/ev/change-requests`, `/api/ev/battery-swap-change-requests` · **Auth:** `ROLE_EV_USER`
**Controller:** `ChangeRequestController`, `BatterySwapChangeRequestController`

### Charging Station CR

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 4.1 | `POST` | `/api/ev/change-requests` | Tạo CR (CREATE_STATION hoặc UPDATE_STATION). Status khởi tạo là DRAFT. |
| 4.2 | `POST` | `/api/ev/change-requests/{id}/submit` | Submit CR từ DRAFT → PENDING (chạy risk engine). |
| 4.3 | `GET` | `/api/ev/change-requests/mine` | Danh sách CR của user hiện tại. |
| 4.4 | `GET` | `/api/ev/change-requests/{id}` | Chi tiết một CR (chỉ nếu thuộc về user). |

### Battery Swap CR

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 4.5 | `POST` | `/api/ev/battery-swap-change-requests` | Tạo CR cho trạm đổi pin (CREATE / UPDATE). Status khởi tạo DRAFT. |
| 4.6 | `GET` | `/api/ev/battery-swap-change-requests` | Lấy tất cả battery-swap CR của user hiện tại. |
| 4.7 | `GET` | `/api/ev/battery-swap-change-requests/{id}` | Chi tiết một battery-swap CR. |
| 4.8 | `POST` | `/api/ev/battery-swap-change-requests/{id}/submit` | Submit CR battery-swap từ DRAFT → PENDING (chạy risk engine). |

---

## 5. EV User Mobile — Issue Report

**Base path:** `/api/ev` · **Auth:** `ROLE_EV_USER`
**Controller:** `IssueController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 5.1 | `POST` | `/api/ev/stations/{stationId}/issues` | Báo cáo sự cố trên trạm (location, price, hours, ports, other). |
| 5.2 | `GET` | `/api/ev/issues/mine` | Danh sách issue đã báo cáo của user hiện tại. |

---

## 6. EV User Mobile — AI Recommendations & Routing

**Base path:** `/api/ev/ai`, `/api/ev/routing` · **Auth:** `ROLE_EV_USER`
**Controller:** `EvUserAiController`, `RoutingController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 6.1 | `POST` | `/api/ev/ai/personalized-recommendations` | Gợi ý trạm cá nhân hoá cho user (dựa trên lịch sử booking/swap, điểm loyalty…). Body: `RecommendationRequestDTO`. |
| 6.2 | `POST` | `/api/ev/ai/smart-time-suggestions` | Gợi ý khung giờ sạc thông minh cho một trạm cụ thể. Body: `SmartTimeSuggestionRequestDTO`. |
| 6.3 | `POST` | `/api/ev/routing/route` | Tính tuyến đường giữa origin → destination có gợi ý trạm sạc dọc đường. EV-aware routing khi có thông tin pin. Body: `RouteRequestDTO`. |

---

## 7. EV User Mobile — Loyalty / Rating

**Base path:** `/api/ev/loyalty` · **Auth:** `ROLE_EV_USER` (một số endpoint public)
**Controller:** `EvLoyaltyController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 7.1 | `GET` | `/api/ev/loyalty/me` | Lấy hồ sơ loyalty của user hiện tại (điểm, level, badges). |
| 7.2 | `GET` | `/api/ev/loyalty/points/history` | Lịch sử giao dịch điểm (phân trang). |
| 7.3 | `GET` | `/api/ev/loyalty/ratings/eligible` | Danh sách trạm đủ điều kiện để user đánh giá. |
| 7.4 | `GET` | `/api/ev/loyalty/ratings` | Danh sách đánh giá của user hiện tại. |
| 7.5 | `POST` | `/api/ev/loyalty/ratings` | Gửi đánh giá trạm. Body: `SubmitRatingRequestDTO`. |
| 7.6 | `POST` | `/api/ev/loyalty/ratings/{id}/helpful` | Đánh dấu một đánh giá là hữu ích. |
| 7.7 | `GET` | `/api/ev/loyalty/badges` | Danh sách badge của user hiện tại. |
| 7.8 | `GET` | `/api/ev/loyalty/badges/available` | Danh sách tất cả badge với tiến độ. |
| 7.9 | `POST` | `/api/ev/loyalty/referral/generate` | Sinh mã giới thiệu cá nhân. |
| 7.10 | `GET` | `/api/ev/loyalty/public/stations/{stationId}/ratings` | **Public.** Lấy danh sách đánh giá của một trạm (phân trang). |
| 7.11 | `GET` | `/api/ev/loyalty/public/stations/{stationId}/summary` | **Public.** Tổng hợp rating của trạm (avg + phân bố 1–5 sao). |
| 7.12 | `GET` | `/api/ev/loyalty/vouchers` | Danh sách voucher definitions đang khả dụng. |
| 7.13 | `GET` | `/api/ev/loyalty/vouchers/mine` | Danh sách voucher user đã đổi. Query: `status?`, `page?`, `size?`. |
| 7.14 | `GET` | `/api/ev/loyalty/vouchers/redemptions/{redemptionId}` | Chi tiết một lần đổi voucher. |
| 7.15 | `POST` | `/api/ev/loyalty/vouchers/{definitionId}/redeem` | Đổi voucher từ điểm loyalty. |
| 7.16 | `POST` | `/api/ev/loyalty/vouchers/redemptions/{redemptionId}/apply-to-booking` | Áp voucher đã đổi vào một booking. |
| 7.17 | `POST` | `/api/ev/loyalty/vouchers/redemptions/{redemptionId}/apply-to-swap` | Áp voucher đã đổi vào một battery-swap reservation. |

---

## 8. Collaborator Mobile — Station & Change Request

**Base path:** `/api/collab/mobile` · **Auth:** `ROLE_COLLABORATOR`
**Controller:** `CollaboratorChangeRequestController`, `CollaboratorMobileController`

### Charging Station CR (đề xuất chỉnh sửa)

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 8.1 | `POST` | `/api/collab/mobile/change-requests` | Tạo charging-station CR (CREATE_STATION / UPDATE_STATION). Ghi `actor_role = COLLABORATOR`. |
| 8.2 | `POST` | `/api/collab/mobile/change-requests/{id}/submit` | Submit CR từ DRAFT → PENDING. |
| 8.3 | `GET` | `/api/collab/mobile/change-requests/mine` | Danh sách CR charging của collaborator hiện tại. |
| 8.4 | `GET` | `/api/collab/mobile/change-requests/{id}` | Chi tiết CR charging. |

### Battery Swap Station CR

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 8.5 | `POST` | `/api/collab/mobile/battery-swap-change-requests` | Tạo battery-swap CR. |
| 8.6 | `POST` | `/api/collab/mobile/battery-swap-change-requests/{id}/submit` | Submit battery-swap CR. |
| 8.7 | `GET` | `/api/collab/mobile/battery-swap-change-requests/mine` | Danh sách battery-swap CR của collaborator hiện tại. |
| 8.8 | `GET` | `/api/collab/mobile/battery-swap-change-requests/{id}` | Chi tiết battery-swap CR. |

### Auto-fill helper (tìm trạm để pre-populate form)

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 8.9 | `GET` | `/api/collab/mobile/stations/search/by-name` | Tìm trạm sạc đã publish theo tên (case-insensitive, phân trang). |
| 8.10 | `GET` | `/api/collab/mobile/stations/{stationId}` | Lấy chi tiết trạm sạc đầy đủ (auto-fill form). |
| 8.11 | `GET` | `/api/collab/mobile/battery-swap-stations/search/by-name` | Tìm trạm đổi pin đã publish theo tên. |
| 8.12 | `GET` | `/api/collab/mobile/battery-swap-stations/{stationId}` | Lấy chi tiết trạm đổi pin (auto-fill form). |

### Location

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 8.13 | `PUT` | `/api/collab/mobile/me/location` | Cập nhật vị trí GPS của collaborator (từ mobile). |

---

## 9. Collaborator Web — Profile & Location

**Base path:** `/api/collab/web` · **Auth:** `ROLE_COLLABORATOR`
**Controller:** `CollaboratorWebController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 9.1 | `GET` | `/api/collab/web/me/profile` | Lấy profile của collaborator hiện tại. |
| 9.2 | `GET` | `/api/collab/web/me/contracts` | Danh sách hợp đồng của collaborator (kèm cờ active). |
| 9.3 | `PUT` | `/api/collab/web/me/location` | Cập nhật vị trí GPS thủ công từ web. |

---

## 10. Admin Web — Station Management

**Base path:** `/api/admin/stations` · **Auth:** `ROLE_ADMIN`
**Controller:** `AdminStationController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 10.1 | `GET` | `/api/admin/stations` | Danh sách tất cả trạm (phân trang). Query: `serviceType?` (mặc định CHARGING), `search?`. |
| 10.2 | `GET` | `/api/admin/stations/{stationId}` | Chi tiết một trạm (bao gồm tất cả version). |
| 10.3 | `POST` | `/api/admin/stations` | Tạo trạm mới trực tiếp (bypass quy trình change request). |
| 10.4 | `PUT` | `/api/admin/stations/{stationId}` | Cập nhật trạm — sinh version mới. |
| 10.5 | `DELETE` | `/api/admin/stations/{stationId}` | Xoá vĩnh viễn trạm (cascade toàn bộ version/services/ports/bookings). Không xoá được nếu đang có booking active. |
| 10.6 | `GET` | `/api/admin/stations/trust/summary` | Tổng hợp trust score toàn hệ thống. |
| 10.7 | `GET` | `/api/admin/stations/{stationId}/trust` | Trust score chi tiết của một trạm (kèm breakdown). |
| 10.8 | `POST` | `/api/admin/stations/{stationId}/trust/recalculate` | Ép tính lại trust score cho trạm. |
| 10.9 | `POST` | `/api/admin/stations/import-csv` | Import nhiều trạm từ CSV (`multipart/form-data`). |

---

## 11. Admin Web — Battery Swap Station Management

**Base path:** `/api/admin/battery-swap/stations` · **Auth:** `ROLE_ADMIN`
**Controller:** `AdminBatterySwapStationController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 11.1 | `GET` | `/api/admin/battery-swap/stations` | Danh sách trạm đổi pin (phân trang). Query: `page?`, `size?`, `search?`. |
| 11.2 | `GET` | `/api/admin/battery-swap/stations/{stationId}` | Chi tiết trạm đổi pin (pile layout). |
| 11.3 | `POST` | `/api/admin/battery-swap/stations` | Tạo trạm đổi pin trực tiếp (admin bypass; publish ngay theo `publishImmediately`). |
| 11.4 | `POST` | `/api/admin/battery-swap/stations/import-csv` | Import nhiều trạm đổi pin từ CSV. |
| 11.5 | `PUT` | `/api/admin/battery-swap/stations/{stationId}` | Cập nhật trạm đổi pin — sinh version mới, publish theo `publishImmediately`. |
| 11.6 | `DELETE` | `/api/admin/battery-swap/stations/{stationId}` | Xoá vĩnh viễn trạm đổi pin (cascade change requests, versions, piles, state, trust). |

---

## 12. Admin Web — Change Request Management

**Base path:** `/api/admin/change-requests` · **Auth:** `ROLE_ADMIN`
**Controller:** `AdminChangeRequestController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 12.1 | `GET` | `/api/admin/change-requests` | Danh sách CR (charging station). Query: `status?` (PENDING, APPROVED, REJECTED, PUBLISHED, DRAFT). |
| 12.2 | `GET` | `/api/admin/change-requests/{id}` | Chi tiết CR (kèm audit logs). |
| 12.3 | `POST` | `/api/admin/change-requests/{id}/approve` | Duyệt CR PENDING → APPROVED. Body (optional): `{note}`. |
| 12.4 | `POST` | `/api/admin/change-requests/{id}/reject` | Từ chối CR PENDING. Body bắt buộc: `{reason}`. |
| 12.5 | `POST` | `/api/admin/change-requests/{id}/publish` | Publish CR đã APPROVED — làm version hiển thị công khai. |

---

## 13. Admin Web — Battery Swap Change Request

**Base path:** `/api/admin/battery-swap/change-requests` · **Auth:** `ROLE_ADMIN`
**Controller:** `AdminBatterySwapChangeRequestController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 13.1 | `POST` | `/api/admin/battery-swap/change-requests` | Tạo CR battery-swap. Admin: `submitImmediately=true` (bypass workflow, publish luôn). |
| 13.2 | `PUT` | `/api/admin/battery-swap/change-requests/{id}` | Cập nhật CR DRAFT (version fields + pile templates). |
| 13.3 | `GET` | `/api/admin/battery-swap/change-requests` | Danh sách tất cả CR battery-swap. Query: `status?`. |
| 13.4 | `GET` | `/api/admin/battery-swap/change-requests/{id}` | Chi tiết CR battery-swap. |
| 13.5 | `POST` | `/api/admin/battery-swap/change-requests/{id}/approve` | Duyệt CR PENDING → APPROVED. |
| 13.6 | `POST` | `/api/admin/battery-swap/change-requests/{id}/reject` | Từ chối CR (yêu cầu `reason`). |
| 13.7 | `POST` | `/api/admin/battery-swap/change-requests/{id}/publish` | Publish CR APPROVED. Nếu `riskScore >= 60` sẽ sinh verification task. Áp dụng version vào operational state. |

---

## 14. Admin Web — Audit Log

**Base path:** `/api/admin` · **Auth:** `ROLE_ADMIN`
**Controller:** `AdminAuditController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 14.1 | `GET` | `/api/admin/audit` | Truy vấn audit log. Query: `entityType?` (CHANGE_REQUEST, STATION, STATION_VERSION), `entityId?`, `from?`, `to?`. |
| 14.2 | `GET` | `/api/admin/stations/{stationId}/audit` | Toàn bộ audit log liên quan tới một trạm (kèm version và CR). |
| 14.3 | `GET` | `/api/admin/change-requests/{id}/audit` | Audit log của một CR. |

---

## 15. Admin Web — Issue Management

**Base path:** `/api/admin/issues` · **Auth:** `ROLE_ADMIN`
**Controller:** `AdminIssueController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 15.1 | `GET` | `/api/admin/issues` | Danh sách issue. Query: `status?` (OPEN, ACKNOWLEDGED, RESOLVED, REJECTED). |
| 15.2 | `GET` | `/api/admin/issues/{id}` | Chi tiết một issue. |
| 15.3 | `POST` | `/api/admin/issues/{id}/acknowledge` | Đánh dấu OPEN → ACKNOWLEDGED (admin đã thấy). |
| 15.4 | `POST` | `/api/admin/issues/{id}/resolve` | OPEN/ACKNOWLEDGED → RESOLVED. Body: `{note}`. |
| 15.5 | `POST` | `/api/admin/issues/{id}/reject` | OPEN/ACKNOWLEDGED → REJECTED (báo cáo sai). Body: `{note}`. |

---

## 16. Admin Web — Dashboard & Analytics

**Base path:** `/api/admin/dashboard` · **Auth:** `ROLE_ADMIN`
**Controller:** `AdminDashboardController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 16.1 | `GET` | `/api/admin/dashboard/stats` | Thống kê tổng quan: tổng trạm, CR pending, issue mở, task quá hạn, collaborator active. |
| 16.2 | `GET` | `/api/admin/dashboard/trends` | Xu hướng theo ngày (bookings, trạm mới, user mới). Query: `days?` (mặc định 30). |
| 16.3 | `GET` | `/api/admin/dashboard/booking-stats` | Thống kê booking: completion rate, cancellation rate, doanh thu, thời lượng trung bình. |
| 16.4 | `GET` | `/api/admin/dashboard/issue-stats` | Thống kê issue theo category + thời gian xử lý trung bình. |
| 16.5 | `GET` | `/api/admin/dashboard/trust-overview` | Danh sách trạm kèm trust score (phân trang, sort theo score/name). |

---

## 17. Admin Web — Loyalty / Rating Moderation

**Base path:** `/api/admin/loyalty` · **Auth:** `ROLE_ADMIN`
**Controller:** `AdminLoyaltyController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 17.1 | `GET` | `/api/admin/loyalty/ratings/moderation` | Hàng đợi moderation rating (chờ duyệt). |
| 17.2 | `POST` | `/api/admin/loyalty/ratings/{id}/approve` | Duyệt rating. |
| 17.3 | `POST` | `/api/admin/loyalty/ratings/{id}/reject` | Từ chối rating. |
| 17.4 | `GET` | `/api/admin/loyalty/badges` | Danh sách badge đang có trong hệ thống. |
| 17.5 | `POST` | `/api/admin/loyalty/badges` | Tạo badge mới. |
| 17.6 | `GET` | `/api/admin/loyalty/vouchers/definitions` | Danh sách voucher definitions. |
| 17.7 | `POST` | `/api/admin/loyalty/vouchers/definitions` | Tạo voucher definition mới. |

---

## 18. Public API — Battery Swap Display

**Base path:** `/api/public` · **Auth:** `permitAll()` (không cần đăng nhập)
**Controller:** `PublicBatterySwapController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 18.1 | `GET` | `/api/public/battery-swap/stations` | Danh sách tất cả trạm đổi pin đã publish (cho màn hình hiển thị công cộng). |
| 18.2 | `GET` | `/api/public/battery-swap/stations/{stationId}` | Chi tiết trạm đổi pin (kèm piles & slots). |
| 18.3 | `GET` | `/api/public/battery-swap/stations/{stationId}/piles` | Piles & slots của trạm (cho hardware simulator / display screen). |
| 18.4 | `GET` | `/api/public/device/stations/{stationId}/key` | Lấy / đăng ký device key cho trạm (dùng cho simulator/display). Query: `deviceName?`. Trả về `{stationId, deviceKey, wsEndpoint}`. |
| 18.5 | `GET` | `/api/public/battery-swap/stations/{stationId}/active-code` | Swap code đang active (PENDING) của trạm — polling fallback. |

---

## 19. Battery Swap Trust Score

**Base path:** `/api/v1/battery-swap/trust` · **Auth:** public (mutate/history yêu cầu ADMIN)
**Controller:** `BatterySwapTrustController`

| # | Method | Endpoint | Chức năng |
|---|--------|----------|-----------|
| 19.1 | `GET` | `/api/v1/battery-swap/trust/{stationId}` | **Public.** Trust score của một trạm đổi pin. |
| 19.2 | `GET` | `/api/v1/battery-swap/trust/{stationId}/breakdown` | **Public.** Trust score breakdown theo chiều (accuracy, reliability, safety…). |
| 19.3 | `GET` | `/api/v1/battery-swap/trust/{stationId}/level` | **Public.** Trust level: HIGH ≥ 70, MEDIUM 30–69, LOW < 30. |
| 19.4 | `GET` | `/api/v1/battery-swap/trust/summary` | **Public.** Thống kê tổng hợp: tổng trạm, phân bố level, điểm trung bình, top/bottom 5. |
| 19.5 | `POST` | `/api/v1/battery-swap/trust/{stationId}/recalculate` | **Admin.** Ép tính lại trust score. |
| 19.6 | `GET` | `/api/v1/battery-swap/trust/{stationId}/history` | **Admin.** Lịch sử verification review của trạm. |

---

## 20. WebSocket

| # | Endpoint | Chức năng |
|---|----------|-----------|
| 20.1 | `/ws/display/battery-swap` | Kênh WS cho màn hình hiển thị trạm đổi pin (cập nhật trạng thái swap real-time sau khi device key được cấp qua API 18.4). |

---

## Phụ lục: Tham chiếu file nguồn

| Controller / File | Đường dẫn |
|---|---|
| `EvUserMobileController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/EvUserMobileController.java` |
| `EvBatterySwapController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/EvBatterySwapController.java` |
| `ChargerUnitController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/ChargerUnitController.java` |
| `AvailabilityController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/AvailabilityController.java` |
| `ChangeRequestController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/ChangeRequestController.java` |
| `BatterySwapChangeRequestController` | `backend/src/main/java/com/example/evstation/batteryswap/api/controller/BatterySwapChangeRequestController.java` |
| `IssueController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/IssueController.java` |
| `EvUserAiController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/EvUserAiController.java` |
| `RoutingController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/RoutingController.java` |
| `EvLoyaltyController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/EvLoyaltyController.java` |
| `BookingController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/BookingController.java` |
| `PaymentController` | `backend/src/main/java/com/example/evstation/api/ev_user_mobile/controller/PaymentController.java` |
| `CollaboratorChangeRequestController` | `backend/src/main/java/com/example/evstation/api/collaborator_mobile/controller/CollaboratorChangeRequestController.java` |
| `CollaboratorMobileController` | `backend/src/main/java/com/example/evstation/api/collaborator_mobile/controller/CollaboratorMobileController.java` |
| `CollaboratorWebController` | `backend/src/main/java/com/example/evstation/api/collaborator_web/controller/CollaboratorWebController.java` |
| `AdminStationController` | `backend/src/main/java/com/example/evstation/api/admin_web/controller/AdminStationController.java` |
| `AdminBatterySwapStationController` | `backend/src/main/java/com/example/evstation/batteryswap/api/controller/AdminBatterySwapStationController.java` |
| `AdminChangeRequestController` | `backend/src/main/java/com/example/evstation/api/admin_web/controller/AdminChangeRequestController.java` |
| `AdminBatterySwapChangeRequestController` | `backend/src/main/java/com/example/evstation/batteryswap/api/controller/AdminBatterySwapChangeRequestController.java` |
| `AdminAuditController` | `backend/src/main/java/com/example/evstation/api/admin_web/controller/AdminAuditController.java` |
| `AdminIssueController` | `backend/src/main/java/com/example/evstation/api/admin_web/controller/AdminIssueController.java` |
| `AdminDashboardController` | `backend/src/main/java/com/example/evstation/api/admin_web/controller/AdminDashboardController.java` |
| `AdminLoyaltyController` | `backend/src/main/java/com/example/evstation/api/admin_web/controller/AdminLoyaltyController.java` |
| `PublicBatterySwapController` | `backend/src/main/java/com/example/evstation/api/public_api/controller/PublicBatterySwapController.java` |
| `BatterySwapTrustController` | `backend/src/main/java/com/example/evstation/batteryswapchange/web/BatterySwapTrustController.java` |
| `StationRepository` (FE) | `apps/ev_user_mobile/lib/src/repositories/station_repository.dart` |
| `StationSearchRepository` (FE) | `apps/collab_mobile/lib/src/repositories/station_search_repository.dart` |
