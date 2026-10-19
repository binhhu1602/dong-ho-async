import 'dart:async';
import 'package:flutter/foundation.dart';

// Phân loại nhật ký: Nhật ký người dùng (Lịch sử bấm giờ) vs Nhật ký kỹ thuật (Dev Debug)
class LogEntry {
  final String timestamp;
  final String message;
  final bool isDevLog; // true: log kỹ thuật (Stream/Timer/Queue), false: lịch sử người dùng
  final String category; // 'info', 'lap', 'event_loop', 'alert', 'system'

  LogEntry({
    required this.timestamp,
    required this.message,
    this.isDevLog = false,
    this.category = 'info',
  });
}

// Danh sách nhật ký toàn cục
final List<LogEntry> appLogs = [];

// Bộ thông báo giúp UI (Badge & Trang Nhật ký) tự động vẽ lại ngay khi có log mới
final ValueNotifier<int> logCountNotifier = ValueNotifier<int>(0);

// Danh sách các đồng hồ trong ứng dụng
final List<StopwatchTask> appStopwatchTasks = [];

// Ghi nhật ký có phân loại
void log(String message, {bool isDev = false, String category = 'info'}) {
  final now = DateTime.now();
  final h = now.hour.toString().padLeft(2, '0');
  final m = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  final ms = (now.millisecond ~/ 10).toString().padLeft(2, '0');

  appLogs.add(
    LogEntry(
      timestamp: '$h:$m:$s.$ms',
      message: message,
      isDevLog: isDev,
      category: category,
    ),
  );
  logCountNotifier.value = appLogs.length;
}

// Xóa toàn bộ nhật ký
void clearLogs() {
  appLogs.clear();
  logCountNotifier.value = 0;
}

// Hủy và dọn dẹp toàn bộ đồng hồ (giải phóng bộ nhớ)
void disposeAllStopwatches() {
  for (final task in appStopwatchTasks) {
    task.dispose();
  }
  appStopwatchTasks.clear();
  log('Đã xóa tất cả đồng hồ bấm giờ', isDev: false, category: 'system');
  log('disposeAll: Đã đóng toàn bộ Timer & Broadcast Stream an toàn',
      isDev: true, category: 'system');
}

// Thông tin một vòng chạy (Lap)
class LapRecord {
  final int lapNumber;
  final Duration splitTime; // Thời gian của riêng vòng này (Delta)
  final Duration totalTime; // Tổng thời gian tính từ lúc xuất phát
  bool isFastest;
  bool isSlowest;

  LapRecord({
    required this.lapNumber,
    required this.splitTime,
    required this.totalTime,
    this.isFastest = false,
    this.isSlowest = false,
  });
}

// Lớp quản lý một đồng hồ bấm giờ (chạy độc lập)
class StopwatchTask {
  StopwatchTask(this.name);

  final String name;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  // Lưu trạng thái đếm ngược chuẩn bị chạy (3 -> 2 -> 1)
  int? countdownValue;
  bool get isCountingDown => countdownValue != null;

  // Danh sách các vòng đã chốt (Lap)
  final List<LapRecord> laps = [];
  Duration _lastLapTotal = Duration.zero;

  // StreamController dạng broadcast để nhiều nơi cùng lắng nghe
  final StreamController<Duration> _controller =
      StreamController<Duration>.broadcast();

  Stream<Duration> get stream => _controller.stream;
  bool get isRunning => _stopwatch.isRunning;
  Duration get elapsed => _stopwatch.elapsed;

  // Bắt đầu bấm giờ ngay lập tức
  void start() {
    if (isRunning || isCountingDown) return;
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _send(_stopwatch.elapsed);
    });
    log('🟢 [$name] Bắt đầu bấm giờ', isDev: false);
    log('[$name] Khởi tạo Timer.periodic(50ms) & phát dữ liệu vào Broadcast Stream',
        isDev: true);
  }

  // TÍNH NĂNG FUTURE & ASYNC/AWAIT THỰC TẾ: Đếm ngược 3-2-1 trước khi tự động chạy
  Future<void> startWithCountdown(VoidCallback onTickUI) async {
    if (isRunning || isCountingDown) return;

    log('⏳ [$name] Chuẩn bị xuất phát (Đếm ngược 3 giây)...', isDev: false);
    log('[$name] Bắt đầu chuỗi async/await Future.delayed(1s) x 3', isDev: true);

    for (int i = 3; i >= 1; i--) {
      countdownValue = i;
      onTickUI();
      await Future.delayed(const Duration(seconds: 1));
      // Nếu đồng hồ đã bị xóa hoặc hủy trong lúc đang chờ
      if (_controller.isClosed) return;
    }

    countdownValue = null;
    start();
    onTickUI();
  }

  // Tạm dừng bấm giờ
  void pause() {
    if (!isRunning) return;
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    _send(_stopwatch.elapsed);
    log('⏸️ [$name] Tạm dừng ở mức ${formatTime(_stopwatch.elapsed)}',
        isDev: false);
    log('[$name] Đã gọi Timer.cancel() để ngừng phát Stream', isDev: true);
  }

  // Đặt lại về 0
  void reset() {
    _stopwatch.reset();
    laps.clear();
    _lastLapTotal = Duration.zero;
    _send(Duration.zero);
    log('🔄 [$name] Đặt lại về 00:00.00 (Đã xóa lịch sử vòng)', isDev: false);
  }

  // TÍNH NĂNG ỨNG DỤNG EVENT LOOP THỰC TẾ: Chốt vòng chạy (Lap) & Phân tích kỷ lục
  void recordLap({
    required VoidCallback onUIUpdate,
    required void Function(String summary) onLapAnalyzed,
  }) {
    if (!isRunning) return;

    // 1. CODE ĐỒNG BỘ (Synchronous - Ưu tiên 1):
    // Chốt ngay mốc thời gian chính xác tại thời điểm bấm nút, không để trễ dù chỉ 1ms
    final Duration exactTotal = _stopwatch.elapsed;
    final Duration split = exactTotal - _lastLapTotal;
    _lastLapTotal = exactTotal;
    final int lapNum = laps.length + 1;

    final newLap = LapRecord(
      lapNumber: lapNum,
      splitTime: split,
      totalTime: exactTotal,
    );
    laps.insert(0, newLap); // Chèn vòng mới nhất lên đầu

    log('[$name - EventLoop #1 Sync] Chốt cứng thời gian Vòng $lapNum: ${formatTime(exactTotal)}',
        isDev: true, category: 'event_loop');
    log('🏁 [$name] Vòng $lapNum: +${formatTime(split)} (Tổng: ${formatTime(exactTotal)})',
        isDev: false, category: 'lap');

    // 2. MICROTASK QUEUE (Ưu tiên 2 - Chạy ngay sau hàm đồng bộ, trước khi Event Queue chạy):
    // Phân tích ngầm xem vòng nào nhanh nhất / chậm nhất để gắn nhãn kỷ lục
    scheduleMicrotask(() {
      if (laps.length >= 2) {
        Duration minSplit = laps.first.splitTime;
        Duration maxSplit = laps.first.splitTime;

        for (final l in laps) {
          if (l.splitTime < minSplit) minSplit = l.splitTime;
          if (l.splitTime > maxSplit) maxSplit = l.splitTime;
        }
        for (final l in laps) {
          l.isFastest = (l.splitTime == minSplit);
          l.isSlowest = (l.splitTime == maxSplit && minSplit != maxSplit);
        }
      }
      log('[$name - EventLoop #2 Microtask] Đã tính toán xong kỷ lục Nhanh/Chậm nhất cho ${laps.length} vòng',
          isDev: true, category: 'event_loop');
      onUIUpdate();
    });

    // 3. EVENT QUEUE (Ưu tiên 3 - Chạy sau cùng khi Microtask đã hoàn tất):
    // Đẩy việc xuất thông báo phân tích sang vòng lặp sự kiện kế tiếp để không làm khựng UI
    Future(() {
      String badge = '';
      if (newLap.isFastest && laps.length >= 2) {
        badge = ' ⚡ (Kỷ lục vòng nhanh nhất!)';
      } else if (newLap.isSlowest && laps.length >= 2) {
        badge = ' 🐢 (Vòng chậm nhất)';
      }
      log('[$name - EventLoop #3 Future/EventQueue] Hoàn tất xuất báo cáo Vòng $lapNum$badge',
          isDev: true, category: 'event_loop');
      onLapAnalyzed('🏁 $name - Vòng $lapNum: +${formatTime(split)}$badge');
    });
  }

  void _send(Duration value) {
    if (!_controller.isClosed) {
      _controller.add(value);
    }
  }

  // Dọn dẹp tài nguyên: hủy Timer và đóng Stream
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    _controller.close();
    log('🗑️ [$name] Đã xóa đồng hồ', isDev: false, category: 'system');
    log('[$name] dispose(): Đã tắt Timer và đóng StreamController an toàn',
        isDev: true, category: 'system');
  }
}

// Toán tử debounce: chỉ phát dữ liệu khi người dùng ngừng gõ sau một khoảng thời gian
StreamTransformer<String, String> debounce(Duration duration) {
  Timer? timer;
  return StreamTransformer<String, String>.fromHandlers(
    handleData: (text, sink) {
      timer?.cancel();
      timer = Timer(duration, () {
        sink.add(text);
      });
    },
    handleDone: (sink) {
      timer?.cancel();
      sink.close();
    },
  );
}

// Định dạng thời gian mm:ss.ms
String formatTime(Duration d) {
  int minutes = d.inMinutes;
  int seconds = d.inSeconds % 60;
  int milliseconds = (d.inMilliseconds % 1000) ~/ 10;

  String m = minutes.toString().padLeft(2, '0');
  String s = seconds.toString().padLeft(2, '0');
  String ms = milliseconds.toString().padLeft(2, '0');

  return '$m:$s.$ms';
}