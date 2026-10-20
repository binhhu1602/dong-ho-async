# Đồng hồ bấm giờ đa tác vụ – Future & Stream

Ứng dụng Flutter (chạy được trên **Web**, Windows, Android, iOS…) minh họa lập trình bất đồng bộ trong Dart:
`Future`, `async/await`, `Stream`, `StreamController.broadcast`, `StreamTransformer` (debounce), `StreamBuilder`, Event Loop và cách hủy luồng an toàn.

## Tính năng

- **Nhiều đồng hồ chạy song song** – mỗi đồng hồ có `Timer` và `Stream` riêng, chạy / tạm dừng / đặt lại / xóa độc lập.
- **Đánh số thông minh** – đồng hồ mới lấy số nhỏ nhất còn trống (đang có 1 2 3 5 6 → đồng hồ mới là số 4).
- **Thêm đồng hồ bất đồng bộ** – giả lập tác vụ mất 500 ms bằng `Future.delayed` + `async/await`, có kiểm tra `mounted`.
- **Cảnh báo mốc 10 giây** – listener thứ hai trên cùng broadcast stream (`map` → `distinct` → `where`), hiện SnackBar.
- **Tìm kiếm có debounce 400 ms** – `StreamTransformer` tự viết, chỉ lọc khi người dùng ngừng gõ.
- **Demo Event Loop** – so sánh thứ tự chạy: code đồng bộ → Microtask Queue → Event Queue.
- **Nhật ký hoạt động** – ghi lại mọi sự kiện kèm mốc giờ:phút:giây.
- **Hủy luồng an toàn** – hủy toàn bộ `Timer`, `StreamSubscription`, đóng `StreamController` khi xóa hoặc thoát màn hình.

## Yêu cầu

| Công cụ | Phiên bản |
|---|---|
| Flutter SDK | 3.27 trở lên (dùng `Color.withValues`, `IconButton.filled`) |
| Dart SDK | `>=3.3.0 <4.0.0` (đi kèm Flutter) |
| Trình duyệt | Chrome hoặc Edge (để chạy bản Web) |

Kiểm tra môi trường:

```bash
flutter --version
flutter doctor
```

## Cài đặt và chạy

```bash
# 1. Tải mã nguồn
git clone https://github.com/binhhu1602/dong-ho-async.git
cd dong-ho-async

# 2. Cài thư viện
flutter pub get

# 3. Chạy trên trình duyệt
flutter run -d chrome
```

Chạy trên nền tảng khác:

```bash
flutter devices          # xem các thiết bị đang có
flutter run -d windows   # ứng dụng desktop Windows
flutter run -d edge      # trình duyệt Edge
flutter run              # thiết bị/giả lập Android đang kết nối
```

### Build bản Web để triển khai

```bash
flutter build web --release
```

Kết quả nằm trong thư mục `build/web/`, có thể đưa lên GitHub Pages, Firebase Hosting, Netlify… Nếu đặt ở thư mục con (ví dụ GitHub Pages `https://<user>.github.io/dong-ho-async/`), build kèm `--base-href`:

```bash
flutter build web --release --base-href /dong-ho-async/
```

### Chạy test

```bash
flutter test
flutter analyze
```

## Cấu hình (.env, google-services.json)

**Dự án hiện không cần file cấu hình nào.** Ứng dụng không gọi API, không dùng Firebase, không có khóa bí mật — chỉ cần `flutter pub get` là chạy được.

- **`.env`**: không dùng. Nếu sau này cần biến môi trường, nên truyền khi build bằng `--dart-define-from-file` (có sẵn trong Flutter, không cần thêm thư viện):

  ```bash
  # tạo file .env (đã được .gitignore bỏ qua, KHÔNG commit)
  echo "API_URL=https://example.com" > .env

  flutter run -d chrome --dart-define-from-file=.env
  ```

  ```dart
  const apiUrl = String.fromEnvironment('API_URL');
  ```

  Nên commit một file mẫu `.env.example` (không chứa giá trị thật) để người khác biết cần khai báo những biến nào.

- **`google-services.json`**: không dùng (chỉ cần khi tích hợp Firebase cho Android). Nếu thêm Firebase, cách đơn giản nhất là dùng FlutterFire CLI:

  ```bash
  dart pub global activate flutterfire_cli
  flutterfire configure
  ```

  Lệnh này tự sinh `lib/firebase_options.dart` (dùng cho cả Web) và `android/app/google-services.json`.

> ⚠️ Lưu ý: trên **Web**, mọi giá trị đưa vào ứng dụng (kể cả qua `--dart-define`) đều có thể bị người dùng xem được trong mã JavaScript. Không đặt khóa bí mật thật ở phía client.

## Cấu trúc thư mục

```
lib/
├── main.dart                     # Điểm khởi chạy, MaterialApp + theme
├── home_screen.dart              # Màn hình chính: thêm/xóa đồng hồ, tìm kiếm, Event Loop
├── stopwatch_task.dart           # Lớp StopwatchTask (Timer + broadcast Stream),
│                                 # hàm log, debounce, formatTime
└── widgets/
    ├── stopwatch_card.dart       # Thẻ một đồng hồ (StreamBuilder + các nút)
    └── console_log_panel.dart    # Khung nhật ký hoạt động
test/
└── widget_test.dart              # Smoke test màn hình chính
```

## Kiến thức minh họa

| Khái niệm | Vị trí trong code |
|---|---|
| `Future` + `async/await`, kiểm tra `mounted` sau `await` | `_addStopwatch()` – `home_screen.dart` |
| `StreamController.broadcast()` | `StopwatchTask` – `stopwatch_task.dart` |
| Nhiều listener trên một stream, `map` / `distinct` / `where` / `skipWhile` | `_listenToAlert()` – `home_screen.dart` |
| `StreamTransformer` (debounce) | `debounce()` – `stopwatch_task.dart` |
| `StreamBuilder` tự hủy subscription | `StopwatchCard` – `widgets/stopwatch_card.dart` |
| Microtask Queue vs Event Queue | `_runEventLoopDemo()` – `home_screen.dart` |
| Dọn dẹp `Timer`, `StreamSubscription`, `StreamController` | `dispose()` – `home_screen.dart`, `stopwatch_task.dart` |

## Hướng dẫn sử dụng nhanh

1. Bấm **Thêm đồng hồ** → sau 0,5 giây đồng hồ mới xuất hiện.
2. Bấm ▶ để chạy, ⏸ để tạm dừng, ↻ để đặt lại (chỉ khi đang dừng), 🗑 để xóa.
3. Gõ vào ô tìm kiếm (ví dụ `2`) → danh sách lọc sau khi ngừng gõ 400 ms.
4. Bấm **Chạy thử Event Loop** rồi xem thứ tự 1 → 6 trong khung nhật ký.
5. Nút 🗑 trên thanh tiêu đề hủy toàn bộ đồng hồ cùng lúc.
