# Test Cases - VoltGo Application

## Tài Khoản Test

### EV Users (đã tạo trong database)

| Email | Password | Name | Status |
|-------|----------|------|--------|
| test1@local | (chưa set password) | test1@local | ACTIVE |
| evuser@1 | (chưa set password) | Nguyen Van B | ACTIVE |
| test_booking_user@local | (chưa set password) | test_booking_user@local | ACTIVE |
| evuser1@local | (chưa set password) | evuser1@local | ACTIVE |
| evuser2@local | (chưa set password) | evuser2@local | ACTIVE |

### Tài Khoản khác

| Email | Password | Role |
|-------|----------|------|
| admin@local | Admin@123 | ADMIN |

> **Lưu ý:** Để test đăng nhập EV User, cần đăng ký tài khoản mới qua app hoặc set password cho tài khoản hiện có.

---

## 1. EV User Mobile App - Test Cases

### 1.1 Authentication

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| AUTH_001 | Đăng ký tài khoản EV User mới | 1. Mở app<br>2. Nhấn "Đăng ký"<br>3. Điền email, name, password<br>4. Chọn role "EV_USER"<br>5. Nhấn "Đăng ký" | Đăng ký thành công, chuyển sang màn hình home |
| AUTH_002 | Đăng nhập với tài khoản mới | 1. Nhập email/password đã đăng ký<br>2. Nhấn "Đăng nhập" | Đăng nhập thành công, nhận JWT token |
| AUTH_003 | Đăng nhập sai password | 1. Nhập email đúng, password sai<br>2. Nhấn "Đăng nhập" | Hiển thị lỗi "Invalid credentials" |
| AUTH_004 | Đăng nhập tài khoản không tồn tại | 1. Nhập email không tồn tại<br>2. Nhấn "Đăng nhập" | Hiển thị lỗi "User not found" |
| AUTH_005 | Đăng xuất | 1. Vào Profile<br>2. Nhấn "Đăng xuất" | Xóa token, chuyển về màn hình login |

### 1.2 Station Discovery

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| STATION_001 | Xem danh sách trạm sạc gần đây | 1. Mở app<br>2. Xem màn hình home/map | Hiển thị danh sách trạm với khoảng cách |
| STATION_002 | Tìm kiếm trạm sạc theo tên | 1. Gõ tên trạm vào search bar<br>2. Nhấn tìm kiếm | Hiển thị kết quả phù hợp |
| STATION_003 | Xem chi tiết trạm sạc | 1. Chọn 1 trạm từ danh sách<br>2. Xem thông tin chi tiết | Hiển thị thông tin: địa chỉ, loại sạc, giá, số slot trống |
| STATION_004 | Filter trạm theo loại sạc | 1. Chọn filter "DC" hoặc "AC"<br>2. Xem kết quả | Chỉ hiển thị trạm có loại sạc đã chọn |
| STATION_005 | Xem availability theo thời gian | 1. Chọn trạm<br>2. Chọn ngày/giờ<br>3. Xem slot trống | Hiển thị các slot có sẵn |

### 1.3 Booking (Đặt sạc)

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| BOOK_001 | Tạo booking mới (DC 50kW) | 1. Chọn trạm "a0000000-..." (Station 1)<br>2. Chọn DC50-01<br>3. Chọn thời gian 10:00-11:00<br>4. Xác nhận | Booking được tạo, status "CONFIRMED" |
| BOOK_002 | Tạo booking HOLD (chờ thanh toán) | 1. Chọn trạm<br>2. Chọn slot<br>3. Không thanh toán ngay | Booking status "HOLD", có countdown 15 phút |
| BOOK_003 | Xem danh sách booking của tôi | 1. Vào mục "My Bookings"<br>2. Xem danh sách | Hiển thị tất cả booking của user |
| BOOK_004 | Hủy booking | 1. Chọn booking đang HOLD/CONFIRMED<br>2. Nhấn "Hủy"<br>3. Xác nhận hủy | Booking chuyển sang "CANCELLED" |
| BOOK_005 | Booking slot đã được đặt | 1. Chọn 1 slot đang có booking CONFIRMED<br>2. Thử đặt | Hiển thị lỗi "Slot not available" |
| BOOK_006 | Booking quá khứ | 1. Thử đặt slot trong quá khứ | Hiển thị lỗi "Cannot book past time" |

**Dữ liệu test cho Booking:**
- Booking đang hoạt động: evuser@1 đặt DC100-01 từ 09:45-10:45
- Booking tương lai: test1@local đặt DC50-01 từ 10:18-11:18
- Booking đang HOLD: evuser1@local đặt DC50-02 từ 12:19-13:19

### 1.4 Battery Swap

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| SWAP_001 | Xem danh sách trạm pin dự phòng | 1. Mở mục Battery Swap<br>2. Xem danh sách trạm | Hiển thị các trạm với số pin trống |
| SWAP_002 | Đặt lịch đổi pin | 1. Chọn trạm f1000000-...<br>2. Chọn slot thời gian<br>3. Chọn % pin hiện tại và mong muốn<br>4. Xác nhận | Tạo reservation với status "RESERVED" |
| SWAP_003 | Thanh toán đặt lịch | 1. Chọn reservation chưa thanh toán<br>2. Thực hiện thanh toán | Payment status chuyển sang "PAID" |
| SWAP_004 | Xem chi tiết trạm pin | 1. Chọn trạm pin<br>2. Xem số pin available | Hiển thị số pin trống/tổng cộng |
| SWAP_005 | Đặt khi không có pin trống | 1. Tìm trạm có available_batteries = 0<br>2. Thử đặt | Hiển thị lỗi "No batteries available" |

**Dữ liệu test cho Battery Swap:**
- Station f1000000-...-0001: 24 pin, 22 trống
- Station f1000000-...-0002: 16 pin, 14 trống
- Station f1000000-...-0003: 20 pin, 18 trống

**Reservations đã tạo:**
- test1@local: RESERVED, UNPAID, slot 10:20
- evuser@1: RESERVED, PAID, slot 09:50
- test_booking_user@local: SWAPPING, PAID (đang đổi pin)

### 1.5 Profile & Settings

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| PROFILE_001 | Xem thông tin cá nhân | 1. Vào Profile | Hiển thị email, name, phone |
| PROFILE_002 | Cập nhật thông tin | 1. Sửa name/phone<br>2. Lưu | Thông tin được cập nhật |
| PROFILE_003 | Đổi mật khẩu | 1. Nhập password cũ<br>2. Nhập password mới<br>3. Xác nhận | Password được đổi thành công |

### 1.6 Issue Reporting

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ISSUE_001 | Báo cáo sự cố tại trạm | 1. Chọn trạm<br>2. Nhấn "Báo cáo sự cố"<br>3. Điền mô tả<br>4. Gửi | Issue được tạo, có thể upload ảnh |
| ISSUE_002 | Xem danh sách sự cố đã gửi | 1. Vào mục "My Issues"<br>2. Xem danh sách | Hiển thị các issue của user |

---

## 2. Admin Web Portal - Test Cases

### 2.1 Authentication

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_AUTH_001 | Đăng nhập admin | 1. Mở admin portal<br>2. Login với admin@local / Admin@123 | Đăng nhập thành công, vào dashboard |
| ADMIN_AUTH_002 | Truy cập không có quyền | 1. Copy token EV_USER<br>2. Gọi API admin | Trả về 403 Forbidden |

### 2.2 Dashboard

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_DASH_001 | Xem dashboard | 1. Login as admin<br>2. Xem dashboard | Hiển thị thống kê: stations, users, bookings |
| ADMIN_DASH_002 | Xem thống kê booking hôm nay | 1. Vào Dashboard<br>2. Kiểm tra số booking | Hiển thị số booking trong ngày |

### 2.3 Station Management

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_STA_001 | Xem danh sách trạm | 1. Vào mục Stations<br>2. Xem danh sách | Hiển thị tất cả trạm với status |
| ADMIN_STA_002 | Tạo trạm mới | 1. Nhấn "Create Station"<br>2. Điền thông tin<br>3. Submit | Trạm mới được tạo |
| ADMIN_STA_003 | Xem chi tiết trạm | 1. Chọn trạm<br>2. Xem chi tiết | Hiển thị thông tin đầy đủ + danh sách charger |
| ADMIN_STA_004 | Cập nhật trạm | 1. Sửa thông tin trạm<br>2. Lưu | Trạm được cập nhật |
| ADMIN_STA_005 | Đổi status trạm | 1. Chọn trạm ACTIVE<br>2. Đổi sang INACTIVE | Status trạm thay đổi |
| ADMIN_STA_006 | Import trạm từ CSV | 1. Vào mục Import<br>2. Upload file CSV<br>3. Xác nhận | Các trạm được import |

### 2.4 Charger Unit Management

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_CHG_001 | Xem charger units của trạm | 1. Chọn trạm<br>2. Xem tab "Charger Units" | Hiển thị danh sách charger |
| ADMIN_CHG_002 | Thêm charger unit | 1. Chọn trạm<br>2. Nhấn "Add Charger"<br>3. Điền thông tin<br>4. Submit | Charger mới được thêm |
| ADMIN_CHG_003 | Sửa charger unit | 1. Chọn charger<br>2. Sửa thông tin<br>3. Lưu | Charger được cập nhật |
| ADMIN_CHG_004 | Đổi status charger | 1. Chọn charger ACTIVE<br>2. Đổi sang MAINTENANCE | Status thay đổi |

### 2.5 Battery Swap Admin

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_BAT_001 | Xem danh sách trạm pin | 1. Vào mục Battery Swap<br>2. Xem danh sách | Hiển thị các trạm pin |
| ADMIN_BAT_002 | Cập nhật số pin trạm | 1. Chọn trạm pin<br>2. Cập nhật total_batteries, available_batteries<br>3. Lưu | Số pin được cập nhật |
| ADMIN_BAT_003 | Xem reservations | 1. Chọn trạm pin<br>2. Xem tab "Reservations" | Hiển thị danh sách đặt lịch |
| ADMIN_BAT_004 | Xem chi tiết reservation | 1. Chọn 1 reservation<br>2. Xem chi tiết | Hiển thị thông tin đầy đủ |

### 2.6 Booking Management

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_BOOK_001 | Xem danh sách booking | 1. Vào mục Bookings<br>2. Xem danh sách | Hiển thị tất cả booking |
| ADMIN_BOOK_002 | Filter booking theo status | 1. Filter status = "CONFIRMED"<br>2. Xem kết quả | Chỉ hiển thị booking CONFIRMED |
| ADMIN_BOOK_003 | Filter booking theo ngày | 1. Chọn date range<br>2. Xem kết quả | Hiển thị booking trong khoảng ngày |
| ADMIN_BOOK_004 | Xem chi tiết booking | 1. Chọn 1 booking<br>2. Xem chi tiết | Hiển thị đầy đủ thông tin |

### 2.7 Change Request Management

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_CR_001 | Duyệt change request | 1. Vào mục Change Requests<br>2. Chọn request PENDING<br>3. Duyệt | Request chuyển sang APPROVED |
| ADMIN_CR_002 | Từ chối change request | 1. Chọn request PENDING<br>2. Nhấn Reject<br>3. Điền lý do | Request chuyển sang REJECTED |

### 2.8 Issue Management

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_ISSUE_001 | Xem danh sách issues | 1. Vào mục Issues<br>2. Xem danh sách | Hiển thị tất cả issues |
| ADMIN_ISSUE_002 | Filter issues theo status | 1. Filter status = "OPEN"<br>2. Xem kết quả | Chỉ hiển thị issues OPEN |

### 2.9 Audit Trail

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| ADMIN_AUDIT_001 | Xem audit log | 1. Vào mục Audit<br>2. Xem danh sách | Hiển thị lịch sử thay đổi |

---

## 3. Collaborator Web - Test Cases

### 3.1 Authentication

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| COLLAB_AUTH_001 | Đăng nhập collaborator | 1. Login với collab1@local | Đăng nhập thành công |
| COLLAB_AUTH_002 | Xem dashboard | 1. Sau khi login<br>2. Xem dashboard | Hiển thị thống kê tasks |

### 3.2 Verification Tasks

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| COLLAB_TASK_001 | Xem danh sách task | 1. Vào mục Tasks<br>2. Xem danh sách | Hiển thị các task được assign |
| COLLAB_TASK_002 | Check-in task | 1. Chọn task<br>2. Nhấn "Check-in"<br>3. Upload ảnh<br>4. Gửi | Check-in thành công, tạo verification_checkin |
| COLLAB_TASK_003 | Hoàn thành task | 1. Chọn task đã check-in<br>2. Nhấn "Complete"<br>3. Điền mô tả<br>4. Gửi | Task chuyển sang COMPLETED |

### 3.3 Battery Swap Management

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| COLLAB_BAT_001 | Xem trạm pin được assign | 1. Vào mục Battery Swap<br>2. Xem danh sách | Hiển thị trạm pin của collaborator |
| COLLAB_BAT_002 | Cập nhật trạng thái pin | 1. Chọn trạm pin<br>2. Cập nhật số pin trống<br>3. Lưu | Trạng thái được cập nhật |

---

## 4. Collaborator Mobile App - Test Cases

### 4.1 Authentication

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| COLLAB_M_001 | Đăng nhập | 1. Login với collab account | Đăng nhập thành công |
| COLLAB_M_002 | Đăng xuất | 1. Vào Profile<br>2. Đăng xuất | Xóa token, về login |

### 4.2 Task Management

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| COLLAB_M_TASK_001 | Xem task list | 1. Mở app<br>2. Xem task list | Hiển thị tasks |
| COLLAB_M_TASK_002 | Xem chi tiết task | 1. Chọn task<br>2. Xem chi tiết | Hiển thị thông tin |
| COLLAB_M_TASK_003 | Check-in | 1. Chọn task<br>2. Nhấn Check-in<br>3. Chụp ảnh<br>4. Gửi | Check-in thành công |

---

## 5. Cross-Feature Test Cases

### 5.1 Booking Flow (EV User -> Admin)

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| CROSS_001 | Tạo booking -> Admin thấy | 1. EV User tạo booking mới<br>2. Admin xem danh sách booking | Admin thấy booking mới |
| CROSS_002 | Admin hủy booking -> User thấy | 1. Admin hủy booking<br>2. EV User refresh booking list | Booking của user chuyển sang CANCELLED |
| CROSS_003 | Booking hết hạn | 1. Tạo booking HOLD<br>2. Đợi 15 phút<br>3. Kiểm tra | Booking chuyển sang EXPIRED |

### 5.2 Station Data Sync

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| CROSS_010 | Tạo trạm -> EV User thấy | 1. Admin tạo trạm mới<br>2. EV User refresh station list | Trạm mới xuất hiện |
| CROSS_011 | Update trạm -> Sync | 1. Admin cập nhật trạm<br>2. EV User xem chi tiết | Thông tin được cập nhật |

### 5.3 Battery Swap Flow

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|-----------------|
| CROSS_020 | User đặt pin -> Admin thấy | 1. User đặt lịch pin<br>2. Admin xem reservation | Admin thấy reservation mới |
| CROSS_021 | Pin count update | 1. User hoàn thành đổi pin<br>2. Kiểm tra available_batteries | Số pin trống giảm 1 |

---

## 6. API Test Cases (Manual/Postman)

### 6.1 Auth API

```bash
# Register
POST /auth/register
{
  "email": "newuser@test.com",
  "name": "New User",
  "password": "Password123",
  "role": "EV_USER"
}

# Login
POST /auth/login
{
  "email": "admin@local",
  "password": "Admin@123"
}
```

### 6.2 Station API

```bash
# Get all stations
GET /api/stations

# Get station detail
GET /api/stations/{id}

# Get availability
GET /api/stations/{id}/availability?date=2026-05-23
```

### 6.3 Booking API

```bash
# Create booking
POST /api/bookings
Authorization: Bearer {token}
{
  "stationId": "a0000000-...",
  "chargerUnitId": "83e37fa6-...",
  "startTime": "2026-05-23T14:00:00Z",
  "endTime": "2026-05-23T15:00:00Z"
}

# Get my bookings
GET /api/bookings/me
```

### 6.4 Battery Swap API

```bash
# Get swap stations
GET /api/battery-swap/stations

# Reserve slot
POST /api/battery-swap/reservations
{
  "stationId": "f1000000-...",
  "reservedSlotAt": "2026-05-23T14:00:00Z",
  "requestedBatteryPercent": 20,
  "targetBatteryPercent": 80
}
```

---

## 7. Test Data Summary

### Database Connections
- Host: localhost:5432
- Database: voltgo
- User: voltgo_user
- Password: admin123

### Key Tables
- `user_account` - Tài khoản users
- `station` - Trạm sạc
- `charger_unit` - Bộ sạc (875 units)
- `booking` - Đặt lịch sạc
- `battery_swap_station_state` - Trạng thái trạm pin
- `battery_swap_reservation` - Đặt lịch đổi pin

### Active Test Bookings
| ID | User | Charger | Time | Status |
|----|------|---------|------|--------|
| 90000000-...-001 | test1@local | DC50-01 | 10:18-11:18 | CONFIRMED |
| 90000000-...-002 | evuser@1 | DC100-01 | 09:45-10:45 | HOLD |
| 90000000-...-003 | test_booking_user@local | AC-01 | 09:18-10:18 | CONFIRMED |
| 90000000-...-004 | evuser1@local | DC50-02 | 12:19-13:19 | HOLD |
| 90000000-...-005 | evuser2@local | DC100-02 | 13:19-14:19 | CONFIRMED |

### Battery Swap Stations
| Station ID | Total | Available |
|-----------|-------|-----------|
| f1000000-...-001 | 24 | 22 |
| f1000000-...-002 | 16 | 14 |
| f1000000-...-003 | 20 | 18 |

### Active Swap Reservations
| ID | User | Station | Status | Payment |
|----|------|---------|--------|---------|
| b0000000-...-001 | test1@local | f1000000-001 | RESERVED | UNPAID |
| b0000000-...-002 | evuser@1 | f1000000-002 | RESERVED | PAID |
| b0000000-...-003 | test_booking_user@local | f1000000-003 | SWAPPING | PAID |
| b0000000-...-004 | evuser1@local | f1000000-001 | RESERVED | UNPAID |

---

## 8. Known Issues to Test

1. **Booking HOLD expiry** - Booking HOLD tự động chuyển EXPIRED sau 15 phút
2. **Concurrent booking** - 2 user đặt cùng 1 slot cùng lúc
3. **Battery swap state consistency** - available_batteries cập nhật khi có reservation mới
4. **Station availability cache** - Cache có thể không sync ngay lập tức
