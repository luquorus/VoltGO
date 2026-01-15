# Đặc tả Use Case: Tìm kiếm trạm sạc

## Bảng 2.1: Đặc tả use case Tìm kiếm trạm sạc

| | |
|---|---|
| **Mã use case** | UC002 |
| **Tên use case** | Tìm kiếm trạm sạc (Search Charging Station) |
| **Tác nhân** | Người dùng EV (EV_USER) hoặc Nhà cung cấp (PROVIDER) |
| **Mô tả** | Use case này cho phép người dùng tìm kiếm các trạm sạc xe điện trong phạm vi bán kính nhất định từ vị trí hiện tại của họ. Hệ thống sẽ trả về danh sách các trạm sạc đã được PUBLISHED (đã xuất bản) trong bán kính tìm kiếm, có thể được lọc theo công suất tối thiểu (DC) và loại cổng sạc (AC). Kết quả được sắp xếp theo khoảng cách từ gần đến xa. |
| **Tiền điều kiện** | 1. Người dùng đã đăng nhập vào hệ thống với vai trò EV_USER hoặc PROVIDER.<br>2. Người dùng có quyền truy cập API tìm kiếm trạm sạc.<br>3. Hệ thống có dữ liệu về các trạm sạc đã được PUBLISHED trong cơ sở dữ liệu. |
| **Luồng sự kiện chính** | 1. Người dùng chọn chức năng "Tìm kiếm trạm sạc".<br>2. Hệ thống yêu cầu người dùng nhập thông tin tìm kiếm:<br>   - Vĩ độ (latitude): từ -90 đến 90<br>   - Kinh độ (longitude): từ -180 đến 180<br>   - Bán kính tìm kiếm (radiusKm): từ 0.1 đến 100 km<br>   - Công suất tối thiểu (minPowerKw): tùy chọn, chỉ áp dụng cho cổng DC<br>   - Có cổng AC (hasAC): tùy chọn, true/false<br>   - Phân trang: số trang (page), kích thước trang (size)<br>3. Người dùng nhập thông tin tìm kiếm và gửi yêu cầu.<br>4. Hệ thống kiểm tra tính hợp lệ của các tham số đầu vào:<br>   - Kiểm tra vĩ độ trong khoảng -90 đến 90<br>   - Kiểm tra kinh độ trong khoảng -180 đến 180<br>   - Kiểm tra bán kính trong khoảng 0.1 đến 100 km<br>   - Kiểm tra quyền truy cập của người dùng<br>5. Hệ thống thực hiện truy vấn cơ sở dữ liệu để tìm các trạm sạc:<br>   - Chỉ lấy các trạm có workflow_status = 'PUBLISHED'<br>   - Tính toán khoảng cách từ vị trí người dùng đến trạm sạc sử dụng PostGIS ST_DWithin<br>   - Lọc các trạm trong bán kính chỉ định<br>   - Áp dụng bộ lọc công suất tối thiểu (nếu có) cho cổng DC<br>   - Áp dụng bộ lọc có cổng AC (nếu có)<br>   - Sắp xếp kết quả theo khoảng cách từ gần đến xa<br>   - Áp dụng phân trang<br>6. Hệ thống tính toán thông tin bổ sung cho mỗi trạm:<br>   - Tổng số cổng sạc (DC và AC)<br>   - Điểm tin cậy (trust score)<br>   - Thông tin tóm tắt về cổng sạc (ChargingSummaryDTO)<br>7. Hệ thống trả về danh sách các trạm sạc kèm thông tin phân trang cho người dùng. |
| **Luồng sự kiện thay thế** | 1. Tại bước 4, nếu thông tin nhập không hợp lệ:<br>   (a) Hệ thống hiển thị thông báo lỗi validation, yêu cầu người dùng nhập lại thông tin đúng định dạng.<br>   (b) Luồng sự kiện kết thúc.<br><br>2. Tại bước 4, nếu người dùng chưa đăng nhập hoặc không có quyền truy cập:<br>   (a) Hệ thống trả về lỗi 401 (Unauthorized) hoặc 403 (Forbidden).<br>   (b) Luồng sự kiện kết thúc.<br><br>3. Tại bước 5, nếu không tìm thấy trạm sạc nào trong bán kính:<br>   (a) Hệ thống trả về danh sách rỗng với thông tin phân trang (totalElements = 0).<br>   (b) Luồng sự kiện kết thúc bình thường.<br><br>4. Tại bước 5, nếu xảy ra lỗi hệ thống (lỗi cơ sở dữ liệu, lỗi kết nối):<br>   (a) Hệ thống ghi log lỗi và trả về thông báo lỗi 500 (Internal Server Error).<br>   (b) Luồng sự kiện kết thúc. |
| **Hậu điều kiện** | Hệ thống đã trả về danh sách các trạm sạc phù hợp với tiêu chí tìm kiếm của người dùng, được sắp xếp theo khoảng cách và có thông tin phân trang. Người dùng có thể xem chi tiết từng trạm hoặc thực hiện tìm kiếm mới với các tiêu chí khác. |

---

## Bảng 2.2: Dữ liệu đầu vào cho use case Tìm kiếm trạm sạc

| STT | Dữ liệu đầu vào | Ghi chú | Bắt buộc | Ví dụ |
|-----|-----------------|---------|----------|-------|
| 1 | Vĩ độ (lat) | Tọa độ vĩ độ của vị trí tìm kiếm, giá trị từ -90 đến 90 | Có | 21.0285 |
| 2 | Kinh độ (lng) | Tọa độ kinh độ của vị trí tìm kiếm, giá trị từ -180 đến 180 | Có | 105.8542 |
| 3 | Bán kính (radiusKm) | Bán kính tìm kiếm tính bằng kilomet, giá trị từ 0.1 đến 100 | Có | 10.0 |
| 4 | Công suất tối thiểu (minPowerKw) | Công suất tối thiểu của cổng sạc DC (tính bằng kW), chỉ áp dụng cho cổng DC | Không | 50.0 |
| 5 | Có cổng AC (hasAC) | Lọc các trạm có cổng sạc AC, giá trị true/false | Không | true |
| 6 | Số trang (page) | Số trang kết quả cần lấy, bắt đầu từ 0 | Không | 0 |
| 7 | Kích thước trang (size) | Số lượng kết quả trên mỗi trang | Không | 20 |

---

## Bảng 2.3: Dữ liệu đầu ra cho use case Tìm kiếm trạm sạc

| STT | Dữ liệu đầu ra | Ghi chú | Ví dụ |
|-----|----------------|---------|-------|
| 1 | stationId | Mã định danh duy nhất của trạm sạc | "550e8400-e29b-41d4-a716-446655440000" |
| 2 | name | Tên trạm sạc | "Trạm sạc VinFast Hà Nội" |
| 3 | address | Địa chỉ trạm sạc | "123 Đường Láng, Đống Đa, Hà Nội" |
| 4 | latitude | Vĩ độ của trạm sạc | 21.0285 |
| 5 | longitude | Kinh độ của trạm sạc | 105.8542 |
| 6 | operatingHours | Giờ hoạt động | "24/7" |
| 7 | parking | Loại bãi đỗ xe | "PAID", "FREE", "UNKNOWN" |
| 8 | visibility | Mức độ hiển thị | "PUBLIC", "PRIVATE", "RESTRICTED" |
| 9 | publicStatus | Trạng thái công khai | "ACTIVE", "INACTIVE", "MAINTENANCE" |
| 10 | chargingSummary | Tóm tắt thông tin cổng sạc (tổng số cổng, số cổng DC, số cổng AC) | {totalPorts: 10, dcPorts: 8, acPorts: 2} |
| 11 | trustScore | Điểm tin cậy của trạm sạc (0-100) | 85 |
| 12 | page | Số trang hiện tại | 0 |
| 13 | size | Kích thước trang | 20 |
| 14 | totalElements | Tổng số kết quả tìm được | 50 |
| 15 | totalPages | Tổng số trang | 3 |

---

## Mô tả chi tiết

**Bảng 2.1** trình bày đặc tả chi tiết cho use case tìm kiếm trạm sạc, được thực hiện bởi tác nhân Người dùng EV (EV_USER) hoặc Nhà cung cấp (PROVIDER). Các dữ liệu mà người dùng phải nhập để tiến hành tìm kiếm trạm sạc được miêu tả chi tiết trong **bảng 2.2**. Kết quả trả về từ hệ thống được mô tả trong **bảng 2.3**.

### Lưu ý kỹ thuật:

1. **Xác thực và phân quyền**: Use case này yêu cầu người dùng phải đăng nhập và có vai trò EV_USER hoặc PROVIDER. Hệ thống sử dụng JWT token để xác thực.

2. **Lọc dữ liệu**: Hệ thống chỉ trả về các trạm sạc có trạng thái workflow_status = 'PUBLISHED'. Các trạm ở trạng thái khác (DRAFT, PENDING, APPROVED) sẽ không xuất hiện trong kết quả tìm kiếm.

3. **Tính toán khoảng cách**: Hệ thống sử dụng PostGIS ST_DWithin để tính toán khoảng cách địa lý giữa vị trí người dùng và các trạm sạc, đảm bảo độ chính xác cao.

4. **Sắp xếp kết quả**: Kết quả được sắp xếp theo khoảng cách từ gần đến xa, giúp người dùng dễ dàng tìm thấy trạm sạc gần nhất.

5. **Bộ lọc nâng cao**: 
   - Bộ lọc `minPowerKw` chỉ áp dụng cho cổng sạc DC (Direct Current).
   - Bộ lọc `hasAC` cho phép người dùng tìm các trạm có cổng sạc AC (Alternating Current).

6. **Phân trang**: Hệ thống hỗ trợ phân trang để tối ưu hiệu suất khi có nhiều kết quả tìm kiếm.

7. **Xử lý lỗi**: Hệ thống có cơ chế xử lý lỗi toàn diện, bao gồm validation lỗi, lỗi xác thực, và lỗi hệ thống.

