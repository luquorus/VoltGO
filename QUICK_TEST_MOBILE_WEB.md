# 🚀 Hướng dẫn Test Mobile Apps trên Edge với Kích thước Điện thoại

## ✅ Đã Setup

- ✅ Web platform đã được tạo cho `collab_mobile` và `ev_user_mobile`
- ✅ Dependencies đã được thêm (`dio`, `dio_web_adapter`)
- ✅ Viewport mobile đã được cấu hình trong `index.html`

---

## 📱 Cách 1: Chạy và Resize Browser Window (Đơn giản nhất)

### Bước 1: Chạy app

```bash
# Chạy collab_mobile
cd apps/collab_mobile
flutter run -d edge

# Hoặc chạy ev_user_mobile
cd apps/ev_user_mobile
flutter run -d edge
```

### Bước 2: Resize Edge window thành kích thước điện thoại

1. **Mở Edge DevTools**: Nhấn `F12` hoặc `Ctrl+Shift+I`
2. **Click vào icon Device Toolbar** (hoặc nhấn `Ctrl+Shift+M`)
3. **Chọn device preset**:
   - **iPhone 12 Pro** (390 x 844)
   - **iPhone SE** (375 x 667)
   - **Samsung Galaxy S20** (360 x 800)
   - **Pixel 5** (393 x 851)
   - Hoặc **Custom**: Set width = `375` hoặc `390`, height = `667` hoặc `844`

4. **Hoặc resize thủ công**: Kéo góc cửa sổ Edge để có kích thước ~375x667 hoặc 390x844

### Kết quả:
- App sẽ hiển thị như trên điện thoại
- Có thể test responsive design
- Hot reload vẫn hoạt động (`r` trong terminal)

---

## 🎯 Cách 2: Dùng Edge DevTools Device Emulation (Khuyến nghị)

### Bước 1: Chạy app

```bash
cd apps/collab_mobile
flutter run -d edge
```

### Bước 2: Mở DevTools và chọn Device

1. **Nhấn `F12`** để mở DevTools
2. **Click icon Device Toolbar** (📱) hoặc nhấn `Ctrl+Shift+M`
3. **Chọn device từ dropdown**:
   ```
   Responsive → iPhone 12 Pro
   ```
4. **Hoặc tạo custom size**:
   - Click "Edit..."
   - Thêm custom device:
     - Name: `Mobile Test`
     - Width: `375`
     - Height: `667`
     - Device pixel ratio: `2` hoặc `3`

### Bước 3: Tùy chỉnh thêm

- **Rotate**: Click icon xoay để test portrait/landscape
- **Throttling**: Giả lập network chậm (3G, 4G)
- **Touch**: Test touch events

---

## 🔧 Cách 3: Set Window Size khi Launch (Advanced)

### Tạo script PowerShell để tự động resize

Tạo file `run-mobile-edge.ps1`:

```powershell
# Run Flutter app
cd apps/collab_mobile
Start-Process flutter -ArgumentList "run -d edge" -NoNewWindow

# Wait for Edge to open
Start-Sleep -Seconds 10

# Resize Edge window to mobile size
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}
"@

$hwnd = [Win32]::FindWindow("Chrome_WidgetWin_1", "collab_mobile - Edge")
if ($hwnd -ne [IntPtr]::Zero) {
    [Win32]::MoveWindow($hwnd, 100, 100, 375, 667, $true)
}
```

Chạy:
```powershell
.\run-mobile-edge.ps1
```

---

## 📐 Kích thước màn hình điện thoại phổ biến

| Device | Width | Height | DPR |
|--------|-------|--------|-----|
| iPhone SE | 375 | 667 | 2 |
| iPhone 12/13 | 390 | 844 | 3 |
| iPhone 12 Pro Max | 428 | 926 | 3 |
| Samsung Galaxy S20 | 360 | 800 | 3 |
| Pixel 5 | 393 | 851 | 3 |
| **Custom Test** | **375** | **667** | **2** |

**Khuyến nghị**: Dùng **375x667** hoặc **390x844** để test

---

## 🎨 Tips để Test Mobile UI tốt hơn

### 1. Thêm Responsive Constraints trong Code

Nếu muốn app tự động responsive, wrap widgets với:

```dart
ConstrainedBox(
  constraints: BoxConstraints(
    maxWidth: 400, // Giới hạn width trên web
  ),
  child: YourWidget(),
)
```

### 2. Test Touch Events

- **Click** = Touch trên mobile
- **Hover** = Không có trên mobile (ẩn hover effects)
- **Scroll** = Swipe trên mobile

### 3. Test Orientation

- **Portrait**: 375x667 (mặc định)
- **Landscape**: 667x375 (xoay trong DevTools)

### 4. Test Network

Trong DevTools → Network tab:
- Throttle: **Slow 3G** để test loading states
- Offline: Test offline handling

---

## 🚀 Quick Commands

```bash
# Chạy collab_mobile với mobile viewport
cd apps/collab_mobile
flutter run -d edge

# Chạy ev_user_mobile với mobile viewport
cd apps/ev_user_mobile
flutter run -d edge

# Hot reload khi đang chạy
# Nhấn 'r' trong terminal

# Hot restart
# Nhấn 'R' trong terminal

# Quit
# Nhấn 'q' trong terminal
```

---

## 🔍 So sánh: Web vs Android Emulator

| Feature | Web (Edge) | Android Emulator |
|---------|------------|------------------|
| **Startup time** | ⚡ ~5-10 giây | 🐌 ~30-60 giây |
| **Hot reload** | ✅ Nhanh | ✅ Nhanh |
| **Performance** | ⚠️ Phụ thuộc browser | ✅ Giống device thật |
| **Native features** | ❌ Không có | ✅ Đầy đủ |
| **Network** | ✅ localhost OK | ⚠️ Cần 10.0.2.2 |
| **Debug** | ✅ DevTools tốt | ✅ Android Studio |

**Kết luận**: Dùng **Web** để test UI/UX nhanh, dùng **Android Emulator** để test native features và performance.

---

## 📝 Checklist

- [x] Web platform đã tạo
- [x] Dependencies đã thêm
- [x] Viewport đã config
- [ ] App đã chạy trên Edge
- [ ] DevTools Device Toolbar đã bật
- [ ] Window đã resize thành mobile size
- [ ] UI đã test responsive

---

## 🎯 Next Steps

Sau khi test trên web xong, nếu cần test native features:
1. Chạy trên Android Emulator (xem `MOBILE_SETUP_GUIDE.md`)
2. Test trên device thật (USB debugging)
3. Build APK và cài trên device

---

## 💡 Pro Tips

1. **Bookmark**: Bookmark Edge với mobile size để mở nhanh
2. **Multiple Windows**: Mở 2 windows cùng lúc để so sánh
3. **Screenshots**: Dùng DevTools để chụp screenshot mobile view
4. **Console**: Check console logs để debug network issues

---

**Happy Testing! 🎉**

