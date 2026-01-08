# Hướng dẫn Setup và Chạy Mobile Apps trong Android Studio

## 📱 Tổng quan

Dự án có 2 mobile apps:
- **collab_mobile**: App cho Collaborator
- **ev_user_mobile**: App cho EV User

---

## 🛠️ Phần 1: Setup Android Studio

### Bước 1: Cài đặt Android Studio

1. **Download Android Studio**: https://developer.android.com/studio
2. **Cài đặt Flutter Plugin**:
   - Mở Android Studio
   - File → Settings (hoặc `Ctrl+Alt+S`)
   - Plugins → Tìm "Flutter" → Install
   - Cài kèm "Dart" plugin (tự động cài khi cài Flutter)

### Bước 2: Cấu hình Flutter SDK

1. **File → Settings → Languages & Frameworks → Flutter**
2. **Flutter SDK path**: Chọn đường dẫn Flutter SDK (ví dụ: `C:\flutter`)
3. **Apply → OK**

### Bước 3: Cài đặt Android SDK

1. **File → Settings → Appearance & Behavior → System Settings → Android SDK**
2. **SDK Platforms tab**: 
   - Chọn **Android 13.0 (Tiramisu)** hoặc **Android 14.0 (UpsideDownCake)**
   - Click **Apply** để cài đặt
3. **SDK Tools tab**:
   - Đảm bảo đã chọn:
     - ✅ Android SDK Build-Tools
     - ✅ Android SDK Command-line Tools
     - ✅ Android SDK Platform-Tools
     - ✅ Android Emulator
     - ✅ Google Play services
   - Click **Apply**

---

## 📲 Phần 2: Tạo Android Platform cho Apps

### Tạo platform cho collab_mobile

```bash
cd apps/collab_mobile
flutter create . --platforms=android,ios
flutter pub get
```

### Tạo platform cho ev_user_mobile

```bash
cd apps/ev_user_mobile
flutter create . --platforms=android,ios
flutter pub get
```

**Lưu ý**: Nếu đã chạy lệnh trên, bỏ qua bước này.

---

## 🚀 Phần 3: Mở Project trong Android Studio

### Cách 1: Mở từng app riêng lẻ (Khuyến nghị)

1. **Mở Android Studio**
2. **File → Open**
3. Chọn folder app (ví dụ: `apps/collab_mobile`)
4. Click **OK**
5. Android Studio sẽ tự động detect Flutter project và sync

### Cách 2: Mở toàn bộ workspace (Nâng cao)

1. **File → Open**
2. Chọn folder root: `VoltGo`
3. Android Studio sẽ hiển thị tất cả modules
4. Chọn app cần chạy từ dropdown ở trên

---

## 📱 Phần 4: Tạo và Chạy Android Emulator

### Bước 1: Tạo AVD (Android Virtual Device)

1. **Tools → Device Manager** (hoặc click icon Device Manager ở toolbar)
2. Click **Create Device**
3. Chọn device:
   - **Phone**: Pixel 5, Pixel 6, hoặc Pixel 7
   - Click **Next**
4. Chọn System Image:
   - **Release Name**: Tiramisu (API 33) hoặc UpsideDownCake (API 34)
   - Click **Download** nếu chưa có
   - Click **Next**
5. **AVD Configuration**:
   - Đặt tên: `Pixel_5_API_33`
   - Click **Finish**

### Bước 2: Khởi động Emulator

1. Trong **Device Manager**, click **▶️ Play** button bên cạnh AVD
2. Đợi emulator khởi động (có thể mất 1-2 phút lần đầu)

### Bước 3: Kiểm tra device

```bash
flutter devices
```

Bạn sẽ thấy emulator trong danh sách, ví dụ:
```
sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64 • Android 13 (API 33)
```

---

## ▶️ Phần 5: Chạy App trong Android Studio

### Chạy collab_mobile

1. **Mở project**: `apps/collab_mobile` trong Android Studio
2. **Chọn device**: Ở dropdown trên cùng, chọn emulator hoặc device đã kết nối
3. **Chọn main file**: `lib/main.dart` (nếu chưa được chọn)
4. **Click Run** (▶️) hoặc nhấn `Shift+F10`
5. Đợi app build và chạy (lần đầu có thể mất vài phút)

### Chạy ev_user_mobile

1. **Mở project**: `apps/ev_user_mobile` trong Android Studio
2. Làm tương tự như trên

### Chạy từ Terminal (Alternative)

```bash
# Chạy collab_mobile
cd apps/collab_mobile
flutter run

# Chạy ev_user_mobile
cd apps/ev_user_mobile
flutter run
```

---

## 🔧 Phần 6: Troubleshooting

### Lỗi: "No devices found"

**Giải pháp:**
1. Kiểm tra emulator đã khởi động chưa
2. Chạy: `flutter doctor` để kiểm tra setup
3. Đảm bảo Android SDK đã được cài đặt

### Lỗi: "Gradle sync failed"

**Giải pháp:**
1. **File → Invalidate Caches → Invalidate and Restart**
2. Hoặc xóa cache:
   ```bash
   cd apps/collab_mobile/android
   ./gradlew clean
   ```

### Lỗi: "SDK location not found"

**Giải pháp:**
1. Tạo file `local.properties` trong `android/` folder:
   ```properties
   sdk.dir=C:\\Users\\YourUsername\\AppData\\Local\\Android\\Sdk
   ```
2. Thay `YourUsername` bằng username của bạn

### Lỗi: "Cannot connect to server"

**Giải pháp:**
1. Kiểm tra backend đang chạy: `http://localhost:8080/healthz`
2. Kiểm tra file `.env` có `BASE_URL=http://localhost:8080`
3. **Lưu ý**: Trên Android emulator, `localhost` trỏ về emulator, không phải máy host
   - Thay `localhost` bằng `10.0.2.2` (Android emulator special IP)
   - Hoặc dùng IP máy của bạn (ví dụ: `192.168.1.100`)

**Sửa file `.env` cho Android emulator:**
```env
BASE_URL=http://10.0.2.2:8080
```

---

## 🍎 Phần 7: Build iOS App (Sau này)

### Yêu cầu

1. **macOS** (bắt buộc - không thể build iOS trên Windows)
2. **Xcode** (download từ App Store)
3. **CocoaPods**: `sudo gem install cocoapods`
4. **Apple Developer Account** (để build cho device thật)

### Setup iOS Platform

```bash
cd apps/collab_mobile
flutter create . --platforms=ios
cd ios
pod install
```

### Chạy trên iOS Simulator

1. **Mở Xcode**
2. **Xcode → Preferences → Components**: Download iOS Simulator
3. **Mở terminal**:
   ```bash
   cd apps/collab_mobile
   flutter run -d ios
   ```
4. Flutter sẽ tự động mở iOS Simulator

### Build iOS App

#### Build cho Simulator (Debug)

```bash
cd apps/collab_mobile
flutter build ios --simulator
```

#### Build cho Device thật (Release)

1. **Mở Xcode**:
   ```bash
   cd apps/collab_mobile/ios
   open Runner.xcworkspace
   ```

2. **Cấu hình Signing**:
   - Chọn **Runner** project
   - Tab **Signing & Capabilities**
   - Chọn **Team** (Apple Developer Account)
   - Xcode sẽ tự động tạo provisioning profile

3. **Build**:
   - Chọn device từ dropdown
   - Click **▶️ Run** hoặc `Cmd+R`

#### Build IPA file (cho App Store)

```bash
cd apps/collab_mobile
flutter build ipa
```

File `.ipa` sẽ ở: `build/ios/ipa/`

### Lưu ý iOS

- **Network**: iOS Simulator dùng `localhost` bình thường
- **Permissions**: Cần config trong `ios/Runner/Info.plist`:
  - Camera, Location, etc.
- **App Icons**: Thêm vào `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

---

## 📝 Checklist Setup

### Android
- [ ] Android Studio đã cài đặt
- [ ] Flutter plugin đã cài
- [ ] Android SDK đã cài (API 33+)
- [ ] Android Emulator đã tạo và chạy được
- [ ] File `.env` đã tạo với `BASE_URL`
- [ ] Platform đã tạo: `flutter create . --platforms=android`
- [ ] App chạy được trên emulator

### iOS (Sau này)
- [ ] macOS đã sẵn sàng
- [ ] Xcode đã cài đặt
- [ ] CocoaPods đã cài
- [ ] iOS Simulator đã download
- [ ] Apple Developer Account (nếu build cho device)
- [ ] Platform đã tạo: `flutter create . --platforms=ios`
- [ ] Pods đã install: `cd ios && pod install`

---

## 🎯 Quick Commands

```bash
# Kiểm tra setup
flutter doctor

# Xem devices
flutter devices

# Chạy app
cd apps/collab_mobile
flutter run

# Build APK (Android)
flutter build apk

# Build App Bundle (cho Play Store)
flutter build appbundle

# Build iOS (trên macOS)
flutter build ios
```

---

## 📚 Tài liệu tham khảo

- [Flutter Documentation](https://docs.flutter.dev/)
- [Android Studio Guide](https://developer.android.com/studio)
- [iOS Setup Guide](https://docs.flutter.dev/deployment/ios)
- [Flutter Doctor](https://docs.flutter.dev/get-started/install/windows)

---

## 💡 Tips

1. **Hot Reload**: Nhấn `r` trong terminal khi app đang chạy để reload
2. **Hot Restart**: Nhấn `R` để restart app
3. **DevTools**: Nhấn `d` để mở Flutter DevTools
4. **Quit**: Nhấn `q` để thoát

5. **Network Debugging**: 
   - Android emulator: Dùng `10.0.2.2` thay cho `localhost`
   - iOS Simulator: Dùng `localhost` bình thường
   - Device thật: Dùng IP máy của bạn

6. **Performance**: 
   - Chạy ở **Release mode** để test performance: `flutter run --release`
   - Profile mode: `flutter run --profile`

