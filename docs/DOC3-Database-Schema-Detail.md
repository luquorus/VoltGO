# DOC 3 Supplement - Chi tiết Database Schema

> Phần bổ sung cho DOC3-Database-Schema.md. Tài liệu này mô tả chi tiết từng bảng trong cơ sở dữ liệu VoltGO, bao gồm tên cột, kiểu dữ liệu, ràng buộc, và quan hệ giữa các bảng. Dữ liệu được trích xuất trực tiếp từ 46 JPA Entity classes trong codebase.

---

## Mục lục

- [Bảng 4.1 - Nhóm User/Authentication](#bảng-41---nhóm-userauthentication)
- [Bảng 4.2 - Nhóm Station/Charging Booking](#bảng-42---nhóm-stationcharging-booking)
- [Bảng 4.3 - Nhóm Battery Swap](#bảng-43---nhóm-battery-swap)
- [Bảng 4.4 - Nhóm Governance/Verification](#bảng-44---nhóm-governanceverification)
- [Bảng 4.5 - Nhóm Trust/Loyalty/Audit](#bảng-45---nhóm-trustloyaltyaudit)

---

## Bảng 4.1 - Nhóm User/Authentication

### 4.1.1 `user_account`

**Package:** `com.example.evstation.auth.infrastructure.jpa`

**Mô tả:** Lưu trữ thông tin tài khoản người dùng hệ thống (EV User, Collaborator, Admin).

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, NOT NULL | Khóa chính |
| 2 | email | VARCHAR(255) | NOT NULL, UNIQUE | Email đăng nhập |
| 3 | name | VARCHAR(255) | NOT NULL | Tên hiển thị |
| 4 | phone | VARCHAR(20) | NULL | Số điện thoại |
| 5 | password_hash | VARCHAR(255) | NOT NULL | Băm mật khẩu (BCrypt) |
| 6 | role | VARCHAR(20) | NOT NULL | Vai trò: EV_USER, COLLABORATOR, ADMIN |
| 7 | status | VARCHAR(20) | NOT NULL | Trạng thái: ACTIVE, PENDING_COLLABORATOR, BANNED |
| 8 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 9 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật gần nhất |
| 10 | last_login_at | TIMESTAMPTZ | NULL | Thời điểm đăng nhập cuối |

**Indexes:** Primary Key trên `id`, Unique trên `email`.

**Quan hệ:**
- 1 user có nhiều `push_token` (1:N)
- 1 user có nhiều `ev_user_notification` (1:N)
- 1 user có nhiều `collaborator_notification` (1:N)
- 1 user có 1 `notification_preference` (1:1)
- 1 user có nhiều `booking` (1:N)
- 1 user có nhiều `battery_swap_reservation` (1:N)
- 1 user có 1 `loyalty_user_profile` (1:1)
- 1 user có nhiều `station_rating` (1:N)
- 1 user có nhiều `referral` (với vai trò referrer, 1:N)
- 1 user có 1 `referral` (với vai trò referee, 1:1)

---

### 4.1.2 `push_token`

**Package:** `com.example.evstation.notification.infrastructure.jpa`

**Mô tả:** Lưu trữ FCM token của thiết bị để gửi push notification.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | token | TEXT | NOT NULL | FCM device token |
| 4 | device_type | VARCHAR(20) | NOT NULL | Loại thiết bị: ANDROID, IOS, WEB |
| 5 | is_active | BOOLEAN | NOT NULL, default=true | Token còn hoạt động không |
| 6 | last_used_at | TIMESTAMPTZ | NULL | Thời điểm sử dụng token gần nhất |
| 7 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

**Indexes:**
- `idx_push_token_user` ON (user_id)

---

### 4.1.3 `notification_preference`

**Package:** `com.example.evstation.notification.infrastructure.jpa`

**Mô tả:** Lưu trữ tùy chỉnh thông báo cho từng người dùng, theo từng danh mục.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | category | VARCHAR(50) | NOT NULL | Danh mục thông báo |
| 4 | push_enabled | BOOLEAN | NOT NULL, default=true | Bật thông báo đẩy |
| 5 | email_enabled | BOOLEAN | NOT NULL, default=true | Bật email |
| 6 | in_app_enabled | BOOLEAN | NOT NULL, default=true | Bật thông báo trong app |
| 7 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 8 | updated_at | TIMESTAMPTZ | NULL | Thời điểm cập nhật gần nhất |

**Constraints:**
- Unique constraint: `(user_id, category)`

---

## Bảng 4.2 - Nhóm Station/Charging Booking

### 4.2.1 `station`

**Package:** `com.example.evstation.station.infrastructure.jpa`

**Mô tả:** Bảng gốc đại diện cho một trạm sạc. Chỉ lưu trữ ID và provider, các thông tin chi tiết nằm ở `station_version`.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK | Khóa chính |
| 2 | provider_id | UUID | NOT NULL | FK → user_account.id (chủ trạm) |
| 3 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 4 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật gần nhất |

**Quan hệ:**
- 1 station có nhiều `station_version` (1:N)
- 1 station có 1 `battery_swap_station_state` (1:1)
- 1 station có nhiều `charger_unit` (1:N)
- 1 station có nhiều `swap_pile` (1:N)
- 1 station có nhiều `booking` (1:N)
- 1 station có nhiều `battery_swap_reservation` (1:N)
- 1 station có nhiều `change_request` (1:N)
- 1 station có nhiều `report_issue` (1:N)
- 1 station có 1 `station_trust` (1:1)
- 1 station có 1 `battery_swap_trust` (1:1)
- 1 station có 1 `battery_swap_station_device` (1:1)
- 1 station có nhiều `verification_task` (1:N)

---

### 4.2.2 `station_version`

**Package:** `com.example.evstation.station.infrastructure.jpa`

**Mô tả:** Lưu trữ phiên bản chi tiết của trạm sạc. Mỗi lần chỉnh sửa tạo phiên bản mới.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK | Khóa chính |
| 2 | station_id | UUID | NOT NULL | FK → station.id |
| 3 | version_no | INTEGER | NOT NULL | Số phiên bản |
| 4 | workflow_status | VARCHAR(20) | NOT NULL | Trạng thái workflow |
| 5 | name | VARCHAR(255) | NOT NULL | Tên trạm |
| 6 | address | VARCHAR(500) | NOT NULL | Địa chỉ |
| 7 | location | GEOGRAPHY(POINT, 4326) | NOT NULL | Tọa độ (PostGIS) |
| 8 | operating_hours | VARCHAR(100) | NULL | Giờ hoạt động |
| 9 | parking | VARCHAR(20) | NOT NULL | Loại bãi đỗ xe |
| 10 | visibility | VARCHAR(20) | NOT NULL | Chế độ hiển thị: PUBLIC, PRIVATE, HIDDEN |
| 11 | public_status | VARCHAR(20) | NOT NULL | Trạng thái công khai |
| 12 | created_by | UUID | NOT NULL | Người tạo phiên bản |
| 13 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 14 | published_at | TIMESTAMPTZ | NULL | Thời điểm xuất bản |

**Indexes:**
- Spatial index GIST trên `location`
- `idx_station_version_station` ON (station_id)
- `idx_station_version_status` ON (workflow_status)

---

### 4.2.3 `charger_unit`

**Package:** `com.example.evstation.booking.infrastructure.jpa`

**Mô tả:** Đơn vị sạc riêng lẻ tại trạm. Là đơn vị được đặt trước trong booking.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | station_id | UUID | NOT NULL | FK → station.id |
| 3 | station_version_id | UUID | NOT NULL | FK → station_version.id |
| 4 | power_type | VARCHAR(20) | NOT NULL | Loại công suất: AC, DC |
| 5 | power_kw | DECIMAL(10,2) | NOT NULL | Công suất (kW) |
| 6 | label | VARCHAR(100) | NOT NULL | Nhãn/tên đơn vị sạc |
| 7 | price_per_slot | INTEGER | NOT NULL | Giá mỗi slot (VND) |
| 8 | status | VARCHAR(20) | NOT NULL, default=ACTIVE | Trạng thái: AVAILABLE, OCCUPIED, OUT_OF_SERVICE |
| 9 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

**Indexes:**
- `idx_charger_unit_station_id` ON (station_id)
- `idx_charger_unit_station_power` ON (station_id, power_kw)
- `idx_charger_unit_station_version_id` ON (station_version_id)

---

### 4.2.4 `booking`

**Package:** `com.example.evstation.booking.infrastructure.jpa`

**Mô tả:** Lưu trữ thông tin đặt chỗ sạc của người dùng.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | station_id | UUID | NOT NULL | FK → station.id |
| 4 | charger_unit_id | UUID | NOT NULL | FK → charger_unit.id |
| 5 | start_time | TIMESTAMPTZ | NOT NULL | Thời điểm bắt đầu |
| 6 | end_time | TIMESTAMPTZ | NOT NULL | Thời điểm kết thúc |
| 7 | status | VARCHAR(20) | NOT NULL, default=HOLD | Trạng thái: HOLD, CONFIRMED, CANCELLED, EXPIRED |
| 8 | hold_expires_at | TIMESTAMPTZ | NOT NULL | Thời điểm hết hạn giữ chỗ |
| 9 | price_snapshot | JSONB | NOT NULL, default={} | Ảnh chụp giá tại thời điểm đặt |
| 10 | voucher_redemption_id | UUID | NULL | FK → voucher_redemption.id |
| 11 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

**Indexes:**
- `idx_booking_user_id` ON (user_id)
- `idx_booking_station_id` ON (station_id)
- `idx_booking_status` ON (status)
- `idx_booking_created_at` ON (created_at)
- `idx_booking_start_time` ON (start_time)
- `idx_booking_user_status` ON (user_id, status)
- Exclusion constraint: CK_BOOKING_NO_OVERLAP_ACTIVE (ngăn đặt trùng trên cùng charger_unit trong khoảng thời gian giao nhau với trạng thái HOLD hoặc CONFIRMED)

---

### 4.2.5 `payment_intent`

**Package:** `com.example.evstation.payment.infrastructure.jpa`

**Mô tả:** Lưu trữ yêu cầu thanh toán cho booking. Mỗi booking có tối đa 1 payment_intent.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | booking_id | UUID | NOT NULL, UNIQUE | FK → booking.id |
| 3 | amount | INTEGER | NOT NULL | Số tiền (VND) |
| 4 | currency | VARCHAR(3) | NOT NULL, default='VND' | Đơn vị tiền tệ |
| 5 | status | VARCHAR(20) | NOT NULL, default=CREATED | Trạng thái: CREATED, SUCCEEDED, FAILED |
| 6 | voucher_redemption_id | UUID | NULL | FK → voucher_redemption.id |
| 7 | discount_amount | INTEGER | NULL | Số tiền được giảm từ voucher |
| 8 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 9 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật gần nhất |

**Indexes:**
- `idx_payment_intent_booking_id` ON (booking_id)
- `idx_payment_intent_status` ON (status)
- `idx_payment_intent_created_at` ON (created_at)

---

## Bảng 4.3 - Nhóm Battery Swap

### 4.3.1 `battery_swap_station_state`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Lưu trữ trạng thái thời gian thực của trạm pin trao đổi (số pin khả dụng, công suất sạc).

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | station_id | UUID | PK, FK → station.id | Khóa chính |
| 2 | total_batteries | INTEGER | NOT NULL, default=20 | Tổng số pin |
| 3 | available_batteries | INTEGER | NOT NULL, default=10 | Số pin khả dụng |
| 4 | avg_charge_power_kw | DECIMAL(6,2) | NOT NULL, default=35.0 | Công suất sạc trung bình (kW) |
| 5 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật gần nhất |

**Quan hệ:** 1:1 với `station`.

---

### 4.3.2 `swap_pile`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Cọc pin trao đổi. Mỗi trạm có nhiều cọc, mỗi cọc chứa nhiều slot.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | station_id | UUID | NOT NULL | FK → station.id |
| 3 | pile_index | INTEGER | NOT NULL | Chỉ số cọc (1, 2, 3...) |
| 4 | status | VARCHAR(20) | NOT NULL, default=ACTIVE | Trạng thái: ACTIVE, INACTIVE, MAINTENANCE |
| 5 | created_at | TIMESTAMPTZ | NOT NULL | Thời điểm tạo |
| 6 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật gần nhất |

**Quan hệ:**
- `@OneToMany` → `battery_slot` (1 pile có nhiều slot)
- Unique constraint: `(station_id, pile_index)`

---

### 4.3.3 `battery_slot`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Vị trí lắp pin trong cọc. Mỗi slot chứa 1 viên pin với thông tin mức sạc.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | pile_id | UUID | NOT NULL | FK → swap_pile.id |
| 3 | slot_index | INTEGER | NOT NULL | Chỉ số slot trong cọc (1-based) |
| 4 | battery_id | UUID | NULL | ID viên pin đang ở slot này |
| 5 | battery_serial_number | VARCHAR(100) | NULL | Số serial viên pin |
| 6 | battery_capacity_kwh | DECIMAL(6,2) | NOT NULL, default=60.0 | Dung lượng pin (kWh) |
| 7 | battery_charge_percent | INTEGER | NOT NULL, default=100 | Mức sạc pin hiện tại (0-100) |
| 8 | status | VARCHAR(20) | NOT NULL, default=AVAILABLE | Trạng thái: AVAILABLE, OCCUPIED, MAINTENANCE |
| 9 | charging_started_at | TIMESTAMPTZ | NULL | Thời điểm bắt đầu sạc |
| 10 | estimated_full_at | TIMESTAMPTZ | NULL | Thời điểm ước tính sạc đầy |
| 11 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật gần nhất |

**Unique constraint:** `(pile_id, slot_index)`

---

### 4.3.4 `battery_swap_reservation`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Lưu trữ yêu cầu đặt trước dịch vụ trao đổi pin.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | station_id | UUID | NOT NULL | FK → station.id |
| 4 | pile_id | UUID | NULL | FK → swap_pile.id |
| 5 | slot_id | UUID | NULL | FK → battery_slot.id |
| 6 | status | VARCHAR(20) | NOT NULL, default=RESERVED | Trạng thái: RESERVED, CONFIRMED, SWAPPING, COMPLETED, CANCELLED, EXPIRED |
| 7 | reserved_slot_at | TIMESTAMPTZ | NULL | Thời điểm đặt slot |
| 8 | requested_battery_percent | INTEGER | NOT NULL, default=20 | Mức sạc pin yêu cầu (phần trăm) |
| 9 | battery_capacity_kwh | DECIMAL(6,2) | NOT NULL, default=60.0 | Dung lượng pin (kWh) |
| 10 | estimated_ready_at | TIMESTAMPTZ | NULL | Thời điểm ước tính pin sẵn sàng |
| 11 | note | TEXT | NULL | Ghi chú |
| 12 | reserved_at | TIMESTAMPTZ | NOT NULL | Thời điểm đặt |
| 13 | started_at | TIMESTAMPTZ | NULL | Thời điểm bắt đầu trao đổi |
| 14 | completed_at | TIMESTAMPTZ | NULL | Thời điểm hoàn thành |
| 15 | cancelled_at | TIMESTAMPTZ | NULL | Thời điểm hủy |
| 16 | confirmed_arrival_at | TIMESTAMPTZ | NULL | Thời điểm xác nhận đến |
| 17 | swap_code | VARCHAR(10) | NULL | Mã trao đổi (6 số) |
| 18 | swap_deadline_at | TIMESTAMPTZ | NULL | Thời hạn thực hiện trao đổi |
| 19 | base_price_vnd | BIGINT | NOT NULL, default=5000 | Giá cơ bản (VND) |
| 20 | payment_status | VARCHAR(20) | NOT NULL, default=UNPAID | Trạng thái thanh toán: UNPAID, PAID, REFUNDED |
| 21 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật gần nhất |

**Indexes:**
- `idx_bsr_user` ON (user_id)
- `idx_bsr_station` ON (station_id)
- `idx_bsr_status` ON (status)
- `idx_bsr_swap_code` ON (swap_code)

---

### 4.3.5 `swap_payment`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Lưu trữ thanh toán cho dịch vụ trao đổi pin.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | reservation_id | UUID | NOT NULL | FK → battery_swap_reservation.id |
| 3 | amount_vnd | BIGINT | NOT NULL | Số tiền (VND) |
| 4 | status | VARCHAR(20) | NOT NULL, default=PENDING | Trạng thái: PENDING, PAID, REFUNDED, FAILED |
| 5 | created_at | TIMESTAMPTZ | NOT NULL | Thời điểm tạo |
| 6 | paid_at | TIMESTAMPTZ | NULL | Thời điểm thanh toán thành công |
| 7 | refunded_at | TIMESTAMPTZ | NULL | Thời điểm hoàn tiền |
| 8 | expired_at | TIMESTAMPTZ | NULL | Thời điểm hết hạn thanh toán |

---

### 4.3.6 `swap_session`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Phiên trao đổi pin thực tế tại trạm, gắn với mã swap để xác thực.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | reservation_id | UUID | NOT NULL | FK → battery_swap_reservation.id |
| 3 | swap_code | VARCHAR(10) | NOT NULL, UNIQUE | Mã trao đổi (6 số) |
| 4 | status | VARCHAR(20) | NOT NULL, default=PENDING | Trạng thái: PENDING, ACTIVE, COMPLETED, EXPIRED |
| 5 | expires_at | TIMESTAMPTZ | NOT NULL | Thời điểm hết hạn phiên |
| 6 | started_at | TIMESTAMPTZ | NULL | Thời điểm bắt đầu |
| 7 | completed_at | TIMESTAMPTZ | NULL | Thời điểm hoàn thành |
| 8 | created_at | TIMESTAMPTZ | NOT NULL | Thời điểm tạo |
| 9 | created_by | UUID | NULL | Người tạo phiên |
| 10 | completed_by | UUID | NULL | Người hoàn thành phiên |

**Indexes:**
- `idx_swap_session_code` ON (swap_code)
- `idx_swap_session_expires` ON (expires_at) WHERE status = 'PENDING'

---

### 4.3.7 `battery_swap_station_device`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Thiết bị IoT của trạm pin trao đổi (để xác thực trạm từ phía thiết bị).

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | station_id | UUID | PK, FK → station.id | Khóa chính |
| 2 | device_key | VARCHAR(64) | NOT NULL, UNIQUE | Khóa thiết bị |
| 3 | device_name | VARCHAR(100) | NULL | Tên thiết bị |
| 4 | created_at | TIMESTAMPTZ | NOT NULL | Thời điểm đăng ký |
| 5 | last_seen_at | TIMESTAMPTZ | NULL | Thời điểm thiết bị hoạt động gần nhất |

---

### 4.3.8 `battery_swap_station_version`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Phiên bản chi tiết của trạm pin trao đổi (tương tự station_version nhưng dành cho battery swap).

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | station_id | UUID | NOT NULL | FK → station.id |
| 3 | version_no | INTEGER | NOT NULL, default=1 | Số phiên bản |
| 4 | workflow_status | VARCHAR(20) | NOT NULL, default=DRAFT | Trạng thái workflow |
| 5 | total_batteries | INTEGER | NOT NULL | Tổng số pin |
| 6 | avg_charge_power_kw | DECIMAL(6,2) | NOT NULL | Công suất sạc trung bình (kW) |
| 7 | operating_hours | VARCHAR(100) | NOT NULL | Giờ hoạt động |
| 8 | parking_fee | DECIMAL(10,2) | NULL | Phí đỗ xe (VND) |
| 9 | note | TEXT | NULL | Ghi chú |
| 10 | created_by | UUID | NOT NULL | Người tạo |
| 11 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 12 | published_at | TIMESTAMPTZ | NULL | Thời điểm xuất bản |
| 13 | submitted_at | TIMESTAMPTZ | NULL | Thời điểm nộp duyệt |

**Quan hệ:**
- `@OneToMany` → `battery_swap_pile_template` (1 version có nhiều pile template)

---

### 4.3.9 `battery_swap_pile_template`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Template cấu hình cọc pin trong phiên bản trạm pin trao đổi.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | station_version_id | UUID | NOT NULL | FK → battery_swap_station_version.id |
| 3 | pile_index | INTEGER | NOT NULL | Chỉ số cọc |
| 4 | slots_per_pile | INTEGER | NOT NULL, default=6 | Số slot mỗi cọc |

**Quan hệ:**
- `@ManyToOne` → `battery_swap_station_version`
- `@OneToMany` → `battery_swap_slot_template`

---

### 4.3.10 `battery_swap_slot_template`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Template cấu hình slot pin trong pile template.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | pile_template_id | UUID | NOT NULL | FK → battery_swap_pile_template.id |
| 3 | slot_index | INTEGER | NOT NULL | Chỉ số slot |
| 4 | battery_capacity_kwh | DECIMAL(6,2) | NOT NULL, default=60.0 | Dung lượng pin (kWh) |

**Quan hệ:** `@ManyToOne` → `battery_swap_pile_template`

---

### 4.3.11 `charging_session`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Phiên sạc pin tại trạm trao đổi.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | battery_slot_id | UUID | NOT NULL | FK → battery_slot.id |
| 3 | start_percent | INTEGER | NOT NULL, default=0 | Mức sạc bắt đầu (%) |
| 4 | end_percent | INTEGER | NULL | Mức sạc kết thúc (%) |
| 5 | start_kwh | DECIMAL(8,4) | NULL | Dung lượng bắt đầu (kWh) |
| 6 | end_kwh | DECIMAL(8,4) | NULL | Dung lượng kết thúc (kWh) |
| 7 | status | VARCHAR(20) | NOT NULL, default=CHARGING | Trạng thái: CHARGING, COMPLETED, INTERRUPTED |
| 8 | started_at | TIMESTAMPTZ | NOT NULL | Thời điểm bắt đầu sạc |
| 9 | estimated_full_at | TIMESTAMPTZ | NULL | Thời điểm ước tính đầy |
| 10 | completed_at | TIMESTAMPTZ | NULL | Thời điểm hoàn thành |

---

### 4.3.12 `battery_event`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Nhật ký sự kiện pin (lắp vào, tháo ra, bắt đầu/kết thúc sạc).

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | battery_slot_id | UUID | NOT NULL | FK → battery_slot.id |
| 3 | event_type | VARCHAR(20) | NOT NULL | Loại sự kiện: INSERTED, REMOVED, CHARGE_START, CHARGE_COMPLETE, RESERVED |
| 4 | old_state | VARCHAR(50) | NULL | Trạng thái trước |
| 5 | new_state | VARCHAR(50) | NULL | Trạng thái sau |
| 6 | old_percent | INTEGER | NULL | Mức sạc trước (%) |
| 7 | new_percent | INTEGER | NULL | Mức sạc sau (%) |
| 8 | metadata | JSONB | NULL | Dữ liệu bổ sung |
| 9 | created_at | TIMESTAMPTZ | NOT NULL | Thời điểm sự kiện |
| 10 | created_by | UUID | NULL | Người/tác nhân tạo event |
| 11 | actor_type | VARCHAR(20) | NULL | Loại tác nhân: DEVICE, USER, SYSTEM |

---

## Bảng 4.4 - Nhóm Governance/Verification

### 4.4.1 `change_request`

**Package:** `com.example.evstation.station.infrastructure.jpa`

**Mô tả:** Yêu cầu thay đổi thông tin trạm sạc (tạo mới, cập nhật, xóa).

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK | Khóa chính |
| 2 | type | VARCHAR(20) | NOT NULL | Loại: CREATE_STATION, UPDATE_STATION, DELETE_STATION |
| 3 | status | VARCHAR(20) | NOT NULL | Trạng thái: DRAFT, SUBMITTED, PENDING, APPROVED, REJECTED, PUBLISHED |
| 4 | station_id | UUID | NULL | FK → station.id |
| 5 | proposed_station_version_id | UUID | NOT NULL | FK → station_version.id (phiên bản đề xuất) |
| 6 | submitted_by | UUID | NOT NULL | FK → user_account.id (người gửi) |
| 7 | risk_score | INTEGER | NOT NULL, default=0 | Điểm rủi ro (0-100) |
| 8 | risk_reasons | JSONB | NOT NULL, default=[] | Danh sách lý do rủi ro |
| 9 | admin_note | TEXT | NULL | Ghi chú của admin |
| 10 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 11 | submitted_at | TIMESTAMPTZ | NULL | Thời điểm nộp |
| 12 | decided_at | TIMESTAMPTZ | NULL | Thời điểm phê duyệt/từ chối |

---

### 4.4.2 `report_issue`

**Package:** `com.example.evstation.station.infrastructure.jpa`

**Mô tả:** Báo cáo sự cố về trạm sạc từ người dùng.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | station_id | UUID | NOT NULL | FK → station.id |
| 3 | reporter_id | UUID | NOT NULL | FK → user_account.id |
| 4 | category | VARCHAR(50) | NOT NULL | Loại sự cố: WRONG_LOCATION, BROKEN_CHARGER, WRONG_INFO, OTHER |
| 5 | description | TEXT | NOT NULL | Mô tả chi tiết |
| 6 | status | VARCHAR(20) | NOT NULL, default=OPEN | Trạng thái: OPEN, IN_PROGRESS, RESOLVED, CLOSED |
| 7 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 8 | decided_at | TIMESTAMPTZ | NULL | Thời điểm xử lý |
| 9 | admin_note | TEXT | NULL | Ghi chú xử lý |

**Indexes:**
- `idx_report_issue_station_id` ON (station_id)
- `idx_report_issue_status` ON (status)
- `idx_report_issue_reporter_id` ON (reporter_id)

---

### 4.4.3 `verification_task`

**Package:** `com.example.evstation.verification.infrastructure.jpa`

**Mô tả:** Công việc xác minh trạm sạc được giao cho collaborator.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | station_id | UUID | NOT NULL | FK → station.id |
| 3 | change_request_id | UUID | NULL | FK → change_request.id |
| 4 | priority | INTEGER | NOT NULL, default=3 | Độ ưu tiên (1=cao nhất) |
| 5 | sla_due_at | TIMESTAMPTZ | NULL | Thời hạn SLA |
| 6 | assigned_to | UUID | NULL | FK → collaborator_profile.id |
| 7 | status | VARCHAR(20) | NOT NULL, default=OPEN | Trạng thái: OPEN, ASSIGNED, IN_PROGRESS, COMPLETED, CANCELLED |
| 8 | verification_type | VARCHAR(20) | NOT NULL, default=CHARGING_STATION | Loại xác minh: CHARGING_STATION, BATTERY_SWAP_STATION |
| 9 | battery_swap_change_request_id | UUID | NULL | FK → battery_swap_change_request.id |
| 10 | battery_swap_station_snapshot | JSONB | NULL | Ảnh chụp trạng thái trạm pin swap |
| 11 | checklist_json | JSONB | NULL | Checklist xác minh |
| 12 | station_snapshot_json | JSONB | NULL | Ảnh chụp trạm sạc |
| 13 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

---

### 4.4.4 `verification_checkin`

**Package:** `com.example.evstation.verification.infrastructure.jpa`

**Mô tả:** Check-in của collaborator khi đến trạm để xác minh.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | task_id | UUID | NOT NULL, UNIQUE | FK → verification_task.id |
| 3 | checkin_lat | DECIMAL(10,7) | NOT NULL | Vĩ độ check-in |
| 4 | checkin_lng | DECIMAL(10,7) | NOT NULL | Kinh độ check-in |
| 5 | checked_in_at | TIMESTAMPTZ | NOT NULL | Thời điểm check-in |
| 6 | distance_m | INTEGER | NOT NULL | Khoảng cách đến trạm (mét) |
| 7 | device_note | TEXT | NULL | Ghi chú từ thiết bị |
| 8 | actual_total_batteries | INTEGER | NULL | Tổng số pin thực tế |
| 9 | actual_available_batteries | INTEGER | NULL | Số pin khả dụng thực tế |
| 10 | observed_avg_charge_power_kw | DECIMAL(6,2) | NULL | Công suất sạc trung bình quan sát được |
| 11 | checklist_answers_json | JSONB | NULL | Câu trả lời checklist |

---

### 4.4.5 `verification_evidence`

**Package:** `com.example.evstation.verification.infrastructure.jpa`

**Mô tả:** Ảnh chụp bằng chứng xác minh tại trạm.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | task_id | UUID | NOT NULL | FK → verification_task.id |
| 3 | photo_object_key | TEXT | NOT NULL | Object key của ảnh trên MinIO |
| 4 | note | TEXT | NULL | Ghi chú cho ảnh |
| 5 | submitted_at | TIMESTAMPTZ | NOT NULL | Thời điểm tải lên |
| 6 | submitted_by | UUID | NOT NULL | Người tải lên |

---

### 4.4.6 `verification_review`

**Package:** `com.example.evstation.verification.infrastructure.jpa`

**Mô tả:** Kết quả phê duyệt xác minh từ phía admin.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | task_id | UUID | NOT NULL, UNIQUE | FK → verification_task.id |
| 3 | result | VARCHAR(20) | NOT NULL | Kết quả: VERIFIED, REJECTED, REQUIRES_RESUBMISSION |
| 4 | admin_note | TEXT | NULL | Ghi chú của admin |
| 5 | reviewed_at | TIMESTAMPTZ | NOT NULL | Thời điểm phê duyệt |
| 6 | reviewed_by | UUID | NOT NULL | FK → user_account.id |
| 7 | swap_station_verified | BOOLEAN | NULL | Trạm pin swap đã được xác minh |
| 8 | inventory_accurate | BOOLEAN | NULL | Hàng tồn kho chính xác |
| 9 | resolution_note | TEXT | NULL | Ghi chú giải quyết |

---

## Bảng 4.5 - Nhóm Trust/Loyalty/Audit

### 4.5.1 `station_trust`

**Package:** `com.example.evstation.trust.infrastructure.jpa`

**Mô tả:** Điểm tin cậy của trạm sạc, bao gồm phân tích chi tiết các yếu tố.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | station_id | UUID | PK, FK → station.id | Khóa chính |
| 2 | score | INTEGER | NOT NULL | Điểm tin cậy (0-100) |
| 3 | breakdown | JSONB | NOT NULL | Phân tích chi tiết các yếu tố ảnh hưởng |
| 4 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm tính toán lại gần nhất |

**Indexes:** `idx_station_trust_station` ON (station_id)

---

### 4.5.2 `battery_swap_trust`

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

**Mô tả:** Điểm tin cậy của trạm pin trao đổi với phân tích rủi ro đa chiều.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | station_id | UUID | NOT NULL, UNIQUE | FK → station.id |
| 3 | score | INTEGER | NOT NULL, default=50 | Điểm tin cậy (0-100) |
| 4 | breakdown | JSONB | NOT NULL, default={} | Phân tích chi tiết rủi ro |
| 5 | last_event_at | TIMESTAMPTZ | NULL | Thời điểm sự kiện gần nhất |
| 6 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 7 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật gần nhất |

**Indexes:** `idx_battery_swap_trust_station` ON (station_id)

---

### 4.5.3 `loyalty_user_profile`

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

**Mô tả:** Hồ sơ tích lũy điểm và cấp độ của người dùng.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | user_id | UUID | PK, FK → user_account.id | Khóa chính |
| 2 | current_points | INTEGER | NOT NULL, default=0 | Điểm hiện tại |
| 3 | lifetime_points | INTEGER | NOT NULL, default=0 | Tổng điểm tích lũy suốt đời |
| 4 | total_ratings | INTEGER | NOT NULL, default=0 | Số lần đánh giá |
| 5 | total_bookings | INTEGER | NOT NULL, default=0 | Số lần đặt sạc |
| 6 | total_swaps | INTEGER | NOT NULL, default=0 | Số lần trao đổi pin |
| 7 | total_contributions | INTEGER | NOT NULL, default=0 | Số đóng góp xác minh |
| 8 | last_activity_at | TIMESTAMPTZ | NULL | Hoạt động gần nhất |
| 9 | level | INTEGER | NOT NULL, default=1 | Cấp độ thành viên |
| 10 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật |

---

### 4.5.4 `loyalty_point_transaction`

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

**Mô tả:** Lịch sử giao dịch điểm (kiếm điểm / đổi điểm).

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | type | VARCHAR(20) | NOT NULL | Loại: EARN, REDEEM, ADJUSTMENT |
| 4 | source | VARCHAR(50) | NOT NULL | Nguồn: BOOKING_COMPLETE, REFERRAL_SIGNUP, REFERRAL_COMPLETE, RATING_BONUS, VOUCHER_REDEEM, ADMIN_ADJUSTMENT, VERIFICATION_BONUS |
| 5 | source_id | UUID | NULL | ID tham chiếu đến booking, referral, etc. |
| 6 | points | INTEGER | NOT NULL | Số điểm (dương = kiếm, âm = đổi) |
| 7 | balance_after | INTEGER | NOT NULL | Số dư sau giao dịch |
| 8 | description | TEXT | NULL | Mô tả giao dịch |
| 9 | metadata | JSONB | NULL | Dữ liệu bổ sung |
| 10 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm giao dịch |

**Indexes:** `idx_lpt_user_created` ON (user_id, created_at)

---

### 4.5.5 `voucher_definition`

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

**Mô tả:** Định nghĩa voucher có thể đổi bằng điểm.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK | Khóa chính |
| 2 | code | VARCHAR(50) | NOT NULL, UNIQUE | Mã voucher |
| 3 | name | VARCHAR(255) | NOT NULL | Tên voucher |
| 4 | description | TEXT | NULL | Mô tả |
| 5 | voucher_type | VARCHAR(20) | NOT NULL | Loại: BOOKING_DISCOUNT, SWAP_DISCOUNT, FREE_MINUTES, CASHBACK |
| 6 | point_cost | INTEGER | NOT NULL | Số điểm cần để đổi |
| 7 | discount_percent | INTEGER | NULL | Phần trăm giảm giá |
| 8 | max_value_vnd | INTEGER | NULL | Giá trị giảm tối đa (VND) |
| 9 | service_type | VARCHAR(20) | NULL | Loại dịch vụ áp dụng |
| 10 | status | VARCHAR(20) | NOT NULL, default=ACTIVE | Trạng thái: ACTIVE, INACTIVE, EXPIRED |
| 11 | start_date | TIMESTAMPTZ | NULL | Ngày bắt đầu hiệu lực |
| 12 | end_date | TIMESTAMPTZ | NULL | Ngày hết hạn |
| 13 | validity_days | INTEGER | NOT NULL, default=30 | Số ngày hiệu lực sau khi đổi |
| 14 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 15 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật |

**Indexes:** `idx_voucher_code` ON (code)

---

### 4.5.6 `voucher_redemption`

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

**Mô tả:** Bản ghi đổi voucher của người dùng.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | voucher_definition_id | UUID | NOT NULL | FK → voucher_definition.id |
| 4 | voucher_code | VARCHAR(50) | NOT NULL, UNIQUE | Mã voucher cá nhân |
| 5 | status | VARCHAR(20) | NOT NULL, default=REDEEMED | Trạng thái: REDEEMED, USED, EXPIRED |
| 6 | points_spent | INTEGER | NOT NULL | Số điểm đã dùng |
| 7 | redeemed_at | TIMESTAMPTZ | NOT NULL | Thời điểm đổi |
| 8 | used_at | TIMESTAMPTZ | NULL | Thời điểm sử dụng |
| 9 | expires_at | TIMESTAMPTZ | NOT NULL | Thời điểm hết hạn |
| 10 | metadata | JSONB | NULL | Dữ liệu bổ sung |
| 11 | booking_id | UUID | NULL | FK → booking.id (khi voucher được dùng) |
| 12 | service_type | VARCHAR(20) | NULL | Loại dịch vụ đã dùng |

**Indexes:**
- `idx_vr_user_status` ON (user_id, status)
- `idx_vr_expires` ON (expires_at)

---

### 4.5.7 `station_rating`

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

**Mô tả:** Đánh giá trạm sạc từ người dùng.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | station_id | UUID | NOT NULL | FK → station.id |
| 4 | rating | INTEGER | NOT NULL | Điểm đánh giá (1-5 sao) |
| 5 | comment | TEXT | NULL | Bình luận |
| 6 | eligibility_id | UUID | NULL | FK → rating_eligibility.id |
| 7 | is_verified | BOOLEAN | NOT NULL, default=false | Đánh giá từ người đã sử dụng dịch vụ |
| 8 | helpful_count | INTEGER | NOT NULL, default=0 | Số người thấy hữu ích |
| 9 | status | VARCHAR(20) | NOT NULL, default=ACTIVE | Trạng thái: ACTIVE, FLAGGED, HIDDEN |
| 10 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 11 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật |

**Indexes:**
- `idx_sr_station` ON (station_id)
- `idx_sr_user` ON (user_id)

---

### 4.5.8 `referral`

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

**Mô tả:** Lưu trữ mối quan hệ giới thiệu giữa người dùng.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | referrer_id | UUID | NOT NULL | FK → user_account.id (người giới thiệu) |
| 3 | referee_id | UUID | NULL | FK → user_account.id (người được giới thiệu) |
| 4 | referral_code | VARCHAR(50) | NOT NULL | Mã giới thiệu |
| 5 | status | VARCHAR(20) | NOT NULL, default=PENDING | Trạng thái: PENDING, COMPLETED, CANCELLED |
| 6 | referred_at | TIMESTAMPTZ | NOT NULL | Thời điểm giới thiệu |

**Unique constraint:** `(referrer_id, referral_code)`

---

### 4.5.9 `audit_log`

**Package:** `com.example.evstation.station.infrastructure.jpa`

**Mô tả:** Nhật ký kiểm toán ghi lại mọi hành động quan trọng trong hệ thống.

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | actor_id | UUID | NOT NULL | FK → user_account.id |
| 3 | actor_role | VARCHAR(50) | NOT NULL | Vai trò người thực hiện |
| 4 | action | VARCHAR(50) | NOT NULL | Hành động: CREATE, UPDATE, DELETE, APPROVE, REJECT, SUBMIT |
| 5 | entity_type | VARCHAR(100) | NOT NULL | Loại thực thể: Station, Booking, User, etc. |
| 6 | entity_id | UUID | NULL | ID của thực thể bị tác động |
| 7 | metadata | JSONB | NOT NULL, default={} | Dữ liệu bổ sung về hành động |
| 8 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm thực hiện |

**Indexes:**
- `idx_audit_log_entity` ON (entity_type, entity_id)
- `idx_audit_log_actor` ON (actor_id)
- `idx_audit_log_created` ON (created_at DESC)

---

## Bảng phụ - Các entity bổ sung

### Collaborator Profile

**Package:** `com.example.evstation.collaborator.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_account_id | UUID | NOT NULL, UNIQUE | FK → user_account.id |
| 3 | full_name | VARCHAR(255) | NULL | Họ tên đầy đủ |
| 4 | phone | VARCHAR(20) | NULL | Số điện thoại |
| 5 | current_location | GEOGRAPHY(POINT, 4326) | NULL | Vị trí hiện tại (PostGIS) |
| 6 | location_updated_at | TIMESTAMPTZ | NULL | Thời điểm cập nhật vị trí |
| 7 | location_source | VARCHAR(20) | NULL | Nguồn vị trí |
| 8 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

---

### Contract

**Package:** `com.example.evstation.collaborator.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | collaborator_id | UUID | NOT NULL | FK → collaborator_profile.id |
| 3 | region | VARCHAR(100) | NULL | Khu vực hợp đồng |
| 4 | start_date | DATE | NOT NULL | Ngày bắt đầu |
| 5 | end_date | DATE | NOT NULL | Ngày kết thúc |
| 6 | status | VARCHAR(20) | NOT NULL, default=ACTIVE | Trạng thái: ACTIVE, EXPIRED, TERMINATED |
| 7 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 8 | terminated_at | TIMESTAMPTZ | NULL | Thời điểm chấm dứt |
| 9 | note | TEXT | NULL | Ghi chú |

---

### Collaborator Registration Request

**Package:** `com.example.evstation.collaborator.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK | Khóa chính |
| 2 | email | VARCHAR(255) | NOT NULL | Email đăng ký |
| 3 | full_name | VARCHAR(255) | NOT NULL | Họ tên |
| 4 | phone | VARCHAR(20) | NOT NULL | Số điện thoại |
| 5 | date_of_birth | DATE | NULL | Ngày sinh |
| 6 | address | TEXT | NULL | Địa chỉ |
| 7 | id_card_number | VARCHAR(20) | NOT NULL | Số CCCD |
| 8 | bank_account_number | VARCHAR(50) | NULL | Số tài khoản ngân hàng |
| 9 | bank_name | VARCHAR(100) | NULL | Tên ngân hàng |
| 10 | contract_agreed_at | TIMESTAMPTZ | NULL | Thời điểm đồng ý hợp đồng |
| 11 | status | VARCHAR(20) | NOT NULL | Trạng thái: PENDING, APPROVED, REJECTED |
| 12 | rejection_reason | TEXT | NULL | Lý do từ chối |
| 13 | submission_count | INTEGER | NOT NULL, default=1 | Số lần nộp |
| 14 | reviewed_by | UUID | NULL | FK → user_account.id |
| 15 | reviewed_at | TIMESTAMPTZ | NULL | Thời điểm duyệt |
| 16 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 17 | updated_at | TIMESTAMPTZ | NOT NULL | Thời điểm cập nhật |

**Indexes:**
- `idx_reg_req_email` ON (email)
- `idx_reg_req_status` ON (status)
- `idx_reg_req_created_at` ON (created_at)

---

### Battery Swap Change Request

**Package:** `com.example.evstation.batteryswap.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | type | VARCHAR(20) | NOT NULL | Loại: CREATE_STATION, UPDATE_STATION, DELETE_STATION |
| 3 | status | VARCHAR(20) | NOT NULL, default=DRAFT | Trạng thái: DRAFT, SUBMITTED, PENDING, APPROVED, REJECTED, PUBLISHED |
| 4 | station_id | UUID | NULL | FK → station.id |
| 5 | proposed_version_id | UUID | NOT NULL | FK → battery_swap_station_version.id |
| 6 | submitted_by | UUID | NOT NULL | FK → user_account.id |
| 7 | risk_score | INTEGER | NOT NULL, default=0 | Điểm rủi ro |
| 8 | risk_reasons | TEXT | NOT NULL, default='[]' | Danh sách lý do rủi ro (JSON array string) |
| 9 | admin_note | TEXT | NULL | Ghi chú admin |
| 10 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |
| 11 | submitted_at | TIMESTAMPTZ | NULL | Thời điểm nộp |
| 12 | decided_at | TIMESTAMPTZ | NULL | Thời điểm phê duyệt |

---

### Loyalty Badge

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | code | VARCHAR(50) | NOT NULL, UNIQUE | Mã badge |
| 3 | name | VARCHAR(100) | NOT NULL | Tên badge |
| 4 | description | TEXT | NULL | Mô tả |
| 5 | icon | VARCHAR(255) | NULL | Icon URL |
| 6 | tier | VARCHAR(20) | NOT NULL | Cấp độ: BRONZE, SILVER, GOLD, PLATINUM, DIAMOND |
| 7 | criteria_type | VARCHAR(20) | NOT NULL | Loại điều kiện |
| 8 | criteria_value | INTEGER | NOT NULL | Giá trị điều kiện |
| 9 | points_bonus | INTEGER | NOT NULL, default=0 | Bonus điểm khi nhận badge |
| 10 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

**Indexes:** `idx_lb_criteria` ON (criteria_type, criteria_value)

---

### User Badge

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | badge_id | UUID | NOT NULL | FK → loyalty_badge.id |
| 4 | earned_at | TIMESTAMPTZ | NOT NULL | Thời điểm nhận badge |

**Unique constraint:** `(user_id, badge_id)`

---

### Rating Eligibility

**Package:** `com.example.evstation.loyalty.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | user_id | UUID | NOT NULL | FK → user_account.id |
| 3 | station_id | UUID | NOT NULL | FK → station.id |
| 4 | source_type | VARCHAR(20) | NOT NULL | Nguồn đủ điều kiện: BOOKING, REFERRAL |
| 5 | source_id | UUID | NOT NULL | ID của booking hoặc referral |
| 6 | eligible_at | TIMESTAMPTZ | NOT NULL | Thời điểm đủ điều kiện |
| 7 | is_rated | BOOLEAN | NOT NULL, default=false | Đã đánh giá chưa |
| 8 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

**Unique constraint:** `(user_id, station_id, source_type, source_id)`

**Indexes:**
- `idx_re_user` ON (user_id)
- `idx_re_station` ON (station_id)

---

### EvUser Notification

**Package:** `com.example.evstation.notification.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | recipient_id | UUID | NOT NULL | FK → user_account.id |
| 3 | type | VARCHAR(20) | NOT NULL | Loại: BOOKING, LOYALTY, SYSTEM, PROMOTION |
| 4 | category | VARCHAR(50) | NOT NULL | Danh mục chi tiết |
| 5 | title | VARCHAR(255) | NOT NULL | Tiêu đề |
| 6 | body | TEXT | NOT NULL | Nội dung |
| 7 | data_json | JSONB | NULL | Dữ liệu bổ sung |
| 8 | is_read | BOOLEAN | NOT NULL, default=false | Đã đọc chưa |
| 9 | reference_id | UUID | NULL | ID tham chiếu (booking_id, voucher_id, etc.) |
| 10 | reference_type | VARCHAR(50) | NULL | Loại tham chiếu |
| 11 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

**Indexes:**
- `idx_ev_notification_recipient` ON (recipient_id)
- `idx_ev_notification_category` ON (category)
- `idx_ev_notification_read` ON (is_read)
- `idx_ev_notification_created_at` ON (created_at DESC)

---

### Collaborator Notification

**Package:** `com.example.evstation.notification.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK, default=UUID.randomUUID() | Khóa chính |
| 2 | recipient_id | UUID | NOT NULL | FK → user_account.id |
| 3 | type | VARCHAR(20) | NOT NULL | Loại: TASK, EARNING, SYSTEM, PROMOTION |
| 4 | category | VARCHAR(50) | NOT NULL | Danh mục chi tiết |
| 5 | title | VARCHAR(255) | NOT NULL | Tiêu đề |
| 6 | body | TEXT | NOT NULL | Nội dung |
| 7 | data_json | JSONB | NULL | Dữ liệu bổ sung |
| 8 | is_read | BOOLEAN | NOT NULL, default=false | Đã đọc chưa |
| 9 | reference_id | UUID | NULL | ID tham chiếu |
| 10 | reference_type | VARCHAR(50) | NULL | Loại tham chiếu |
| 11 | created_at | TIMESTAMPTZ | NOT NULL, updatable=false | Thời điểm tạo |

**Indexes:**
- `idx_notification_recipient` ON (recipient_id)
- `idx_notification_category` ON (category)
- `idx_notification_read` ON (is_read)
- `idx_notification_created_at` ON (created_at DESC)

---

### Station Service

**Package:** `com.example.evstation.station.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK | Khóa chính |
| 2 | station_version_id | UUID | NOT NULL | FK → station_version.id |
| 3 | service_type | VARCHAR(20) | NOT NULL | Loại dịch vụ: AC_NORMAL, AC_FAST, DC_FAST, BATTERY_SWAP |
| 4 | total_batteries | INTEGER | NULL | Tổng số pin (chỉ cho BATTERY_SWAP) |
| 5 | avg_charge_power_kw | DECIMAL(6,2) | NULL | Công suất sạc trung bình |

---

### Charging Port

**Package:** `com.example.evstation.station.infrastructure.jpa`

| STT | Tên cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
|-----|---------|--------------|-----------|-------|
| 1 | id | UUID | PK | Khóa chính |
| 2 | station_service_id | UUID | NOT NULL | FK → station_service.id |
| 3 | power_type | VARCHAR(20) | NOT NULL | Loại công suất: AC, DC |
| 4 | power_kw | DECIMAL(10,2) | NOT NULL | Công suất (kW) |
| 5 | port_count | INTEGER | NOT NULL | Số cổng sạc |

---

## Tổng kết số lượng bảng

| Nhóm | Số bảng | Bảng |
|------|---------|------|
| User/Authentication | 3 | user_account, push_token, notification_preference |
| Station/Charging Booking | 5 | station, station_version, charger_unit, booking, payment_intent |
| Battery Swap | 12 | battery_swap_station_state, swap_pile, battery_slot, battery_swap_reservation, swap_payment, swap_session, battery_swap_station_device, battery_swap_station_version, battery_swap_pile_template, battery_swap_slot_template, charging_session, battery_event |
| Governance/Verification | 6 | change_request, report_issue, verification_task, verification_checkin, verification_evidence, verification_review |
| Trust/Loyalty/Audit | 9 | station_trust, battery_swap_trust, loyalty_user_profile, loyalty_point_transaction, voucher_definition, voucher_redemption, station_rating, referral, audit_log |
| Bổ sung | 11 | collaborator_profile, contract, collaborator_registration_request, battery_swap_change_request, loyalty_badge, user_badge, rating_eligibility, ev_user_notification, collaborator_notification, station_service, charging_port |
| **Tổng cộng** | **46** | |

---

*Ghi chú: Tài liệu này được trích xuất tự động từ 46 JPA Entity classes trong codebase backend. Mọi thay đổi về schema nên được phản ánh cả ở Entity class và tài liệu này.*
