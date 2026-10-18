import 'dart:async';

// Danh sách nhật ký để hiển thị lên màn hình chính
final List<String> appLogs = [];

void log(String message) {
  appLogs.add(message);
  print(message); // ignore: avoid_print
}

// Lớp quản lý một đồng hồ bấm giờ (chạy độc lập)
class StopwatchTask {
  StopwatchTask(this.name);

  final String name;

  // Đối tượng đếm thời gian
  final Stopwatch _stopwatch = Stopwatch();

  // Hẹn giờ định kỳ 50ms để phát thời gian mới vào Stream
  Timer? _timer;

  // StreamController dạng broadcast để nhiều nơi có thể cùng lắng nghe
  final StreamController<Duration> _controller =
      StreamController<Duration>.broadcast();

  // Luồng dữ liệu thời gian cho bên ngoài lắng nghe
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
  }

  // Tạm dừng bấm giờ
  void pause() {
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    _send(_stopwatch.elapsed);
  }

  // Đặt lại về 0
  void reset() {
    _stopwatch.reset();
    _send(Duration.zero);
  }

  // Gửi thời gian vào Stream nếu Stream chưa bị đóng
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
    log('[$name] dispose: đã tắt Timer và đóng Stream');
  }
}

// Toán tử debounce: chỉ phát dữ liệu khi người dùng ngừng gõ sau một khoảng thời gian
StreamTransformer<String, String> debounce(Duration duration) {
  Timer? timer;
  return StreamTransformer<String, String>.fromHandlers(
    handleData: (text, sink) {
      // Hủy lần chờ trước khi có ký tự mới
      timer?.cancel();
      // Bắt đầu đếm lại thời gian chờ
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

// Định dạng thời gian dạng mm:ss.ms (ví dụ: 01:23.45)
String formatTime(Duration d) {
  int minutes = d.inMinutes;
  int seconds = d.inSeconds % 60;
  int milliseconds = (d.inMilliseconds % 1000) ~/ 10;

  String m = minutes.toString().padLeft(2, '0');
  String s = seconds.toString().padLeft(2, '0');
  String ms = milliseconds.toString().padLeft(2, '0');

  return '$m:$s.$ms';
}
