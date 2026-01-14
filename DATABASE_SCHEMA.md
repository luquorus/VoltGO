# Database Schema - VoltGo

## Tổng quan
Database sử dụng PostgreSQL 16 với PostGIS extension cho spatial data.

---

## Danh sách các bảng

### 1. **user_account**
Bảng quản lý tài khoản người dùng.

**Các cột:**
- `id` (UUID, PK) - ID tài khoản
- `email` (VARCHAR(255), UNIQUE, NOT NULL) - Email đăng nhập
- `password_hash` (VARCHAR(255), NOT NULL) - Mật khẩu đã hash
- `name` (VARCHAR(255), NOT NULL) - Tên hiển thị
- `phone` (VARCHAR(20)) - Số điện thoại
- `role` (VARCHAR(50), NOT NULL) - Vai trò: EV_USER, PROVIDER, COLLABORATOR, ADMIN
- `status` (VARCHAR(50), NOT NULL) - Trạng thái: ACTIVE, INACTIVE
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo

**Indexes:**
- `idx_user_account_email` - Index trên email

---

### 2. **station**
Bảng chính đại diện cho một địa điểm trạm sạc (immutable identifier).

**Các cột:**
- `id` (UUID, PK) - ID trạm
- `provider_id` (UUID, FK → user_account) - ID nhà cung cấp
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo

**Indexes:**
- `idx_station_provider_id` - Index trên provider_id

---

### 3. **station_version**
Bảng lưu dữ liệu theo phiên bản của trạm (versioning pattern).

**Các cột:**
- `id` (UUID, PK) - ID phiên bản
- `station_id` (UUID, FK → station, NOT NULL) - ID trạm
- `version_no` (INTEGER, NOT NULL) - Số phiên bản
- `workflow_status` (workflow_status ENUM, NOT NULL) - Trạng thái: DRAFT, PENDING, PUBLISHED, REJECTED, ARCHIVED
- `name` (TEXT, NOT NULL) - Tên trạm
- `address` (TEXT, NOT NULL) - Địa chỉ
- `location` (geography(Point,4326), NOT NULL) - Vị trí địa lý (PostGIS)
- `operating_hours` (TEXT) - Giờ hoạt động
- `parking` (parking_type ENUM, NOT NULL) - Loại bãi đỗ: PAID, FREE, UNKNOWN
- `visibility` (visibility_type ENUM, NOT NULL) - Độ hiển thị: PUBLIC, PRIVATE, RESTRICTED
- `public_status` (public_status_type ENUM, NOT NULL) - Trạng thái công khai: ACTIVE, INACTIVE, MAINTENANCE
- `created_by` (UUID, FK → user_account, NOT NULL) - Người tạo
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo
- `published_at` (TIMESTAMP) - Thời gian publish

**Constraints:**
- Unique: (station_id, version_no)
- Chỉ 1 PUBLISHED version per station (partial unique index)
- Check: version_no > 0
- Check: published_at phải có khi status = PUBLISHED

**Indexes:**
- `idx_station_version_one_published` - Partial unique index cho PUBLISHED
- `idx_station_version_location_gist` - GiST index cho spatial queries
- `idx_station_version_station_id`
- `idx_station_version_workflow_status`
- `idx_station_version_created_by`

---

### 4. **station_service**
Bảng dịch vụ có sẵn tại trạm.

**Các cột:**
- `id` (UUID, PK) - ID dịch vụ
- `station_version_id` (UUID, FK → station_version, NOT NULL) - ID phiên bản trạm
- `service_type` (service_type ENUM, NOT NULL) - Loại dịch vụ: CHARGING, BATTERY_SWAP

**Indexes:**
- `idx_station_service_station_version_id`
- `idx_station_service_type`

---

### 5. **charging_port**
Bảng cấu hình cổng sạc.

**Các cột:**
- `id` (UUID, PK) - ID cổng sạc
- `station_service_id` (UUID, FK → station_service, NOT NULL) - ID dịch vụ
- `power_type` (power_type ENUM, NOT NULL) - Loại công suất: DC, AC
- `power_kw` (NUMERIC) - Công suất (kW), bắt buộc khi power_type = DC
- `port_count` (INTEGER, NOT NULL) - Số lượng cổng

**Constraints:**
- Check: port_count >= 0
- Check: power_kw phải có và > 0 khi power_type = DC

**Indexes:**
- `idx_charging_port_station_service_id`
- `idx_charging_port_power_type`

---

### 6. **charger_unit**
Bảng đơn vị sạc riêng lẻ (mở rộng từ charging_port) cho booking.

**Các cột:**
- `id` (UUID, PK) - ID đơn vị sạc
- `station_id` (UUID, FK → station, NOT NULL) - ID trạm
- `station_version_id` (UUID, FK → station_version, NOT NULL) - ID phiên bản trạm
- `power_type` (power_type ENUM, NOT NULL) - Loại công suất: DC, AC
- `power_kw` (NUMERIC) - Công suất (kW)
- `label` (TEXT, NOT NULL) - Nhãn đơn vị (VD: DC250-01, AC-01)
- `price_per_hour` (INTEGER, NOT NULL) - Giá mỗi giờ (VND)
- `status` (charger_unit_status ENUM, NOT NULL) - Trạng thái: ACTIVE, INACTIVE, MAINTENANCE
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo

**Constraints:**
- Unique: (station_id, label)
- Check: price_per_hour >= 0
- Check: power_kw phải có và > 0 khi power_type = DC

**Indexes:**
- `idx_charger_unit_station_id`
- `idx_charger_unit_station_power`
- `idx_charger_unit_status` (partial index cho ACTIVE)
- `idx_charger_unit_station_version_id`

---

### 7. **change_request**
Bảng yêu cầu thay đổi cho việc tạo/cập nhật trạm với workflow phê duyệt.

**Các cột:**
- `id` (UUID, PK) - ID yêu cầu
- `type` (change_request_type ENUM, NOT NULL) - Loại: CREATE_STATION, UPDATE_STATION
- `status` (change_request_status ENUM, NOT NULL) - Trạng thái: DRAFT, PENDING, APPROVED, REJECTED, PUBLISHED
- `station_id` (UUID, FK → station) - ID trạm (NULL khi CREATE_STATION)
- `proposed_station_version_id` (UUID, FK → station_version, NOT NULL) - ID phiên bản đề xuất
- `submitted_by` (UUID, FK → user_account, NOT NULL) - Người gửi
- `risk_score` (INTEGER, NOT NULL) - Điểm rủi ro (0-100)
- `risk_reasons` (JSONB, NOT NULL) - Lý do rủi ro (array)
- `admin_note` (TEXT) - Ghi chú admin
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo
- `submitted_at` (TIMESTAMP) - Thời gian gửi
- `decided_at` (TIMESTAMP) - Thời gian quyết định

**Constraints:**
- Check: station_id phải có khi type = UPDATE_STATION
- Check: risk_score từ 0-100
- Check: submitted_at phải có khi status != DRAFT
- Check: decided_at phải có khi status = APPROVED/REJECTED/PUBLISHED

**Indexes:**
- `idx_change_request_station_id`
- `idx_change_request_status`
- `idx_change_request_submitted_by`
- `idx_change_request_proposed_station_version_id`
- `idx_change_request_type`

---

### 8. **audit_log**
Bảng nhật ký audit cho tất cả các hành động trong hệ thống.

**Các cột:**
- `id` (UUID, PK) - ID log
- `actor_id` (UUID, FK → user_account, NOT NULL) - ID người thực hiện
- `actor_role` (TEXT, NOT NULL) - Vai trò người thực hiện
- `action` (TEXT, NOT NULL) - Hành động
- `entity_type` (TEXT, NOT NULL) - Loại entity
- `entity_id` (UUID) - ID entity
- `metadata` (JSONB) - Metadata bổ sung
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo

**Indexes:**
- `idx_audit_log_actor_id`
- `idx_audit_log_entity` (composite: entity_type, entity_id)
- `idx_audit_log_created_at`
- `idx_audit_log_action`

---

### 9. **report_issue**
Bảng báo cáo vấn đề từ EV users về dữ liệu trạm.

**Các cột:**
- `id` (UUID, PK) - ID báo cáo
- `station_id` (UUID, FK → station, NOT NULL) - ID trạm
- `reporter_id` (UUID, FK → user_account, NOT NULL) - ID người báo cáo
- `category` (issue_category ENUM, NOT NULL) - Loại: LOCATION_WRONG, PRICE_WRONG, HOURS_WRONG, PORTS_WRONG, OTHER
- `description` (TEXT, NOT NULL) - Mô tả vấn đề
- `status` (issue_status ENUM, NOT NULL) - Trạng thái: OPEN, ACKNOWLEDGED, RESOLVED, REJECTED
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo
- `decided_at` (TIMESTAMP) - Thời gian quyết định
- `admin_note` (TEXT) - Ghi chú admin

**Indexes:**
- `idx_report_issue_station_id`
- `idx_report_issue_status`
- `idx_report_issue_reporter_id`
- `idx_report_issue_created_at`

---

### 10. **station_trust**
Bảng điểm tin cậy của trạm với breakdown có thể giải thích.

**Các cột:**
- `station_id` (UUID, PK, FK → station) - ID trạm
- `score` (INTEGER, NOT NULL) - Điểm tin cậy (0-100)
- `breakdown` (JSONB, NOT NULL) - Breakdown: base, verification_bonus, issues_penalty, high_risk_penalty
- `updated_at` (TIMESTAMP, NOT NULL) - Thời gian cập nhật

**Constraints:**
- Check: score từ 0-100

**Indexes:**
- `idx_station_trust_score`
- `idx_station_trust_updated_at`

---

### 11. **collaborator_profile**
Bảng thông tin profile của collaborator.

**Các cột:**
- `id` (UUID, PK) - ID profile
- `user_account_id` (UUID, FK → user_account, UNIQUE, NOT NULL) - ID tài khoản
- `full_name` (TEXT) - Họ tên đầy đủ
- `phone` (TEXT) - Số điện thoại
- `current_location` (geography(Point,4326)) - Vị trí GPS hiện tại
- `location_updated_at` (TIMESTAMP) - Thời gian cập nhật vị trí
- `location_source` (location_source ENUM) - Nguồn: MOBILE, WEB
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo

**Indexes:**
- `idx_collaborator_profile_user_account_id`
- `idx_collaborator_profile_location` (GiST index cho spatial queries)

---

### 12. **contract**
Bảng hợp đồng định nghĩa khi nào collaborator có thể submit verification evidence.

**Các cột:**
- `id` (UUID, PK) - ID hợp đồng
- `collaborator_id` (UUID, FK → collaborator_profile, NOT NULL) - ID collaborator
- `region` (TEXT) - Khu vực (cho auto-assign)
- `start_date` (DATE, NOT NULL) - Ngày bắt đầu
- `end_date` (DATE, NOT NULL) - Ngày kết thúc
- `status` (contract_status ENUM, NOT NULL) - Trạng thái: ACTIVE, TERMINATED
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo
- `terminated_at` (TIMESTAMP) - Thời gian terminate
- `note` (TEXT) - Ghi chú

**Constraints:**
- Check: end_date >= start_date
- Check: terminated_at phải có khi status = TERMINATED

**Indexes:**
- `idx_contract_collaborator_id`
- `idx_contract_status`
- `idx_contract_dates` (composite: start_date, end_date)

---

### 13. **verification_task**
Bảng nhiệm vụ verification cho collaborator để verify dữ liệu trạm.

**Các cột:**
- `id` (UUID, PK) - ID nhiệm vụ
- `station_id` (UUID, FK → station, NOT NULL) - ID trạm
- `change_request_id` (UUID, FK → change_request) - ID change request liên quan
- `priority` (INTEGER, NOT NULL) - Độ ưu tiên (1-5, 1=cao nhất)
- `sla_due_at` (TIMESTAMP) - Thời hạn SLA
- `assigned_to` (UUID, FK → user_account) - ID collaborator được giao
- `status` (verification_task_status ENUM, NOT NULL) - Trạng thái: OPEN, ASSIGNED, CHECKED_IN, SUBMITTED, REVIEWED
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo

**Constraints:**
- Check: priority từ 1-5

**Indexes:**
- `idx_verification_task_station_id`
- `idx_verification_task_change_request_id`
- `idx_verification_task_assigned_to`
- `idx_verification_task_status`
- `idx_verification_task_sla_due_at`
- `idx_verification_task_priority`
- `idx_verification_task_assigned_status` (composite)
- `idx_verification_task_created_at`

---

### 14. **verification_checkin**
Bảng ghi nhận GPS check-in cho verification tasks.

**Các cột:**
- `id` (UUID, PK) - ID check-in
- `task_id` (UUID, FK → verification_task, UNIQUE, NOT NULL) - ID nhiệm vụ
- `checkin_lat` (NUMERIC(10,7), NOT NULL) - Vĩ độ check-in
- `checkin_lng` (NUMERIC(10,7), NOT NULL) - Kinh độ check-in
- `checked_in_at` (TIMESTAMP, NOT NULL) - Thời gian check-in
- `distance_m` (INTEGER, NOT NULL) - Khoảng cách từ trạm (mét)
- `device_note` (TEXT) - Ghi chú thiết bị

**Indexes:**
- `idx_verification_checkin_task_id`

---

### 15. **verification_evidence**
Bảng bằng chứng ảnh được submit bởi collaborator.

**Các cột:**
- `id` (UUID, PK) - ID bằng chứng
- `task_id` (UUID, FK → verification_task, NOT NULL) - ID nhiệm vụ
- `photo_object_key` (TEXT, NOT NULL) - Key của ảnh trong storage
- `note` (TEXT) - Ghi chú
- `submitted_at` (TIMESTAMP, NOT NULL) - Thời gian submit
- `submitted_by` (UUID, FK → user_account, NOT NULL) - ID collaborator submit

**Indexes:**
- `idx_verification_evidence_task_id`
- `idx_verification_evidence_submitted_by`

---

### 16. **verification_review**
Bảng kết quả review của admin cho verification tasks.

**Các cột:**
- `id` (UUID, PK) - ID review
- `task_id` (UUID, FK → verification_task, UNIQUE, NOT NULL) - ID nhiệm vụ
- `result` (verification_result ENUM, NOT NULL) - Kết quả: PASS, FAIL
- `admin_note` (TEXT) - Ghi chú admin
- `reviewed_at` (TIMESTAMP, NOT NULL) - Thời gian review
- `reviewed_by` (UUID, FK → user_account, NOT NULL) - ID admin review

**Indexes:**
- `idx_verification_review_task_id`
- `idx_verification_review_result`
- `idx_verification_review_reviewed_by`

---

### 17. **booking**
Bảng đặt chỗ của EV users cho charging slots.

**Các cột:**
- `id` (UUID, PK) - ID booking
- `user_id` (UUID, FK → user_account, NOT NULL) - ID người dùng
- `station_id` (UUID, FK → station, NOT NULL) - ID trạm
- `charger_unit_id` (UUID, FK → charger_unit, NOT NULL) - ID đơn vị sạc
- `start_time` (TIMESTAMP, NOT NULL) - Thời gian bắt đầu
- `end_time` (TIMESTAMP, NOT NULL) - Thời gian kết thúc
- `time_range` (TSTZRANGE, NOT NULL) - Time range cho exclusion constraint
- `status` (booking_status ENUM, NOT NULL) - Trạng thái: HOLD, CONFIRMED, CANCELLED, EXPIRED
- `hold_expires_at` (TIMESTAMP, NOT NULL) - Thời gian hết hạn HOLD
- `price_snapshot` (JSONB, NOT NULL) - Snapshot giá tại thời điểm booking
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo

**Constraints:**
- Check: end_time > start_time
- Check: hold_expires_at > created_at
- Exclusion constraint: Không cho phép overlapping bookings trên cùng charger_unit khi status = HOLD hoặc CONFIRMED

**Indexes:**
- `idx_booking_user_id`
- `idx_booking_station_id`
- `idx_booking_status`
- `idx_booking_hold_expires_at` (partial index cho HOLD)
- `idx_booking_created_at`
- `idx_booking_start_time`
- `idx_booking_user_status` (composite)
- `idx_booking_charger_unit_id`
- `idx_booking_time_range` (GiST index cho exclusion constraint)

---

### 18. **payment_intent**
Bảng payment intent cho booking payments (có thể thay thế bằng payment gateway thật sau).

**Các cột:**
- `id` (UUID, PK) - ID payment intent
- `booking_id` (UUID, FK → booking, UNIQUE, NOT NULL) - ID booking
- `amount` (INTEGER, NOT NULL) - Số tiền (đơn vị nhỏ nhất của currency)
- `currency` (TEXT, NOT NULL) - Đơn vị tiền tệ (mặc định: VND)
- `status` (payment_intent_status ENUM, NOT NULL) - Trạng thái: CREATED, SUCCEEDED, FAILED
- `created_at` (TIMESTAMP, NOT NULL) - Thời gian tạo
- `updated_at` (TIMESTAMP, NOT NULL) - Thời gian cập nhật (auto-update trigger)

**Constraints:**
- Check: amount > 0
- Check: currency không rỗng

**Indexes:**
- `idx_payment_intent_booking_id`
- `idx_payment_intent_status`
- `idx_payment_intent_created_at`

**Triggers:**
- `trigger_payment_intent_updated_at` - Tự động cập nhật updated_at khi row thay đổi

---

## Tổng kết

**Tổng số bảng: 18 bảng**

### Nhóm bảng chính:
1. **Authentication & User Management:**
   - `user_account`

2. **Station Management:**
   - `station`
   - `station_version`
   - `station_service`
   - `charging_port`
   - `charger_unit`
   - `change_request`
   - `station_trust`

3. **Issue & Audit:**
   - `report_issue`
   - `audit_log`

4. **Collaborator Management:**
   - `collaborator_profile`
   - `contract`

5. **Verification Workflow:**
   - `verification_task`
   - `verification_checkin`
   - `verification_evidence`
   - `verification_review`

6. **Booking & Payment:**
   - `booking`
   - `payment_intent`

---

## Các ENUM Types

1. `workflow_status` - DRAFT, PENDING, PUBLISHED, REJECTED, ARCHIVED
2. `parking_type` - PAID, FREE, UNKNOWN
3. `visibility_type` - PUBLIC, PRIVATE, RESTRICTED
4. `public_status_type` - ACTIVE, INACTIVE, MAINTENANCE
5. `service_type` - CHARGING, BATTERY_SWAP
6. `change_request_type` - CREATE_STATION, UPDATE_STATION
7. `change_request_status` - DRAFT, PENDING, APPROVED, REJECTED, PUBLISHED
8. `power_type` - DC, AC
9. `issue_category` - LOCATION_WRONG, PRICE_WRONG, HOURS_WRONG, PORTS_WRONG, OTHER
10. `issue_status` - OPEN, ACKNOWLEDGED, RESOLVED, REJECTED
11. `contract_status` - ACTIVE, TERMINATED
12. `verification_task_status` - OPEN, ASSIGNED, CHECKED_IN, SUBMITTED, REVIEWED
13. `verification_result` - PASS, FAIL
14. `booking_status` - HOLD, CONFIRMED, CANCELLED, EXPIRED
15. `payment_intent_status` - CREATED, SUCCEEDED, FAILED
16. `charger_unit_status` - ACTIVE, INACTIVE, MAINTENANCE
17. `location_source` - MOBILE, WEB

---

## Extensions

- **PostGIS** - Cho spatial data (geography type)
- **btree_gist** - Cho exclusion constraints với time ranges

