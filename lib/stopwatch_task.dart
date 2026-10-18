import 'dart:async';

// =============================================================================
// NHẬT KÝ: ghi lại các sự kiện để hiện lên màn hình chính
// =============================================================================
final List<String> appLogs = [];

void log(String message) {
  appLogs.add(message);
  print(message); // ignore: avoid_print
}

// =============================================================================
// MỘT ĐỒNG HỒ = MỘT TÁC VỤ CHẠY ĐỘC LẬP
// =============================================================================
class StopwatchTask {
  StopwatchTask(this.name);

  final String name;

  // Stopwatch của Dart: đo thời gian chính xác.
  final Stopwatch _stopwatch = Stopwatch();

  // Timer: cứ 50ms "bắn" thời gian mới vào Stream.
  Timer? _timer;

  // StreamController.broadcast: cho phép NHIỀU nơi cùng nghe một Stream.
  // (Ở đây có 2 nơi nghe: ô hiển thị số và bộ cảnh báo mốc 10 giây.)
  final StreamController<Duration> _controller =
      StreamController<Duration>.broadcast();

  // Bên ngoài chỉ được NGHE (stream), không được tự ý thêm dữ liệu.
  Stream<Duration> get stream => _controller.stream;

  bool get isRunning => _stopwatch.isRunning;

  Duration get elapsed => _stopwatch.elapsed;

  void start() {
    if (isRunning) return;
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _send(_stopwatch.elapsed);
    });
  }

  void pause() {
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    _send(_stopwatch.elapsed);
  }

  void reset() {
    _stopwatch.reset();
    _send(Duration.zero);
  }

  // Chỉ thêm dữ liệu khi Stream chưa bị đóng → tránh lỗi "Bad state".
  void _send(Duration value) {
    if (!_controller.isClosed) _controller.add(value);
  }

  // DỌN DẸP: tắt Timer + đóng Stream. Bắt buộc gọi khi không dùng nữa,
  // nếu không Timer sẽ chạy mãi (rò rỉ bộ nhớ).
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    _controller.close();
    log('🧹 [$name] dispose: đã tắt Timer và đóng Stream');
  }
}

// =============================================================================
// TOÁN TỬ DEBOUNCE: chỉ cho giá trị đi qua khi người dùng NGỪNG gõ một lúc
// =============================================================================
StreamTransformer<T, T> debounce<T>(Duration duration) {
  Timer? timer;
  return StreamTransformer<T, T>.fromHandlers(
    handleData: (value, sink) {
      timer?.cancel(); // có chữ mới → hủy lần chờ trước
      timer = Timer(duration, () => sink.add(value)); // chờ lại từ đầu
    },
    handleDone: (sink) {
      timer?.cancel();
      sink.close();
    },
  );
}

// =============================================================================
// ĐỊNH DẠNG THỜI GIAN: 01:23.45
// =============================================================================
String formatTime(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  final cs = (d.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');
  return '$m:$s.$cs';
}
