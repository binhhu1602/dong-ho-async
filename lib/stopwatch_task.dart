import 'dart:async';

// Danh sách nhật ký hiển thị lên màn hình
final List<String> appLogs = [];

// Danh sách các đồng hồ trong ứng dụng (giữ trạng thái khi chuyển màn hình)
final List<StopwatchTask> appStopwatchTasks = [];

// Biến đếm số lượng đồng hồ đã tạo
int appStopwatchCounter = 0;

// Ghi nhật ký có kèm mốc thời gian giờ:phút:giây
void log(String message) {
  final now = DateTime.now();
  final h = now.hour.toString().padLeft(2, '0');
  final m = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  appLogs.add('[$h:$m:$s] $message');
}

// Hủy và dọn dẹp toàn bộ đồng hồ (giải phóng bộ nhớ)
void disposeAllStopwatches() {
  for (final task in appStopwatchTasks) {
    task.dispose();
  }
  appStopwatchTasks.clear();
  log('Đã dọn dẹp và hủy toàn bộ luồng đồng hồ');
}

// Lớp quản lý một đồng hồ bấm giờ (chạy độc lập)
class StopwatchTask {
  StopwatchTask(this.name);

  final String name;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  // StreamController dạng broadcast để nhiều nơi cùng lắng nghe
  final StreamController<Duration> _controller =
      StreamController<Duration>.broadcast();

  Stream<Duration> get stream => _controller.stream;
  bool get isRunning => _stopwatch.isRunning;
  Duration get elapsed => _stopwatch.elapsed;

  // Bắt đầu bấm giờ
  void start() {
    if (isRunning) return;
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _send(_stopwatch.elapsed);
    });
    log('[$name] Bắt đầu chạy (Timer 50ms & phát Stream)');
  }

  // Tạm dừng bấm giờ
  void pause() {
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    _send(_stopwatch.elapsed);
    log('[$name] Tạm dừng (đã hủy Timer)');
  }

  // Đặt lại về 0
  void reset() {
    _stopwatch.reset();
    _send(Duration.zero);
    log('[$name] Đặt lại về 00:00.00');
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
    log('[$name] dispose: đã tắt Timer và đóng Stream an toàn');
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
