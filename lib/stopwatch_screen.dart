import 'dart:async';

import 'package:flutter/material.dart';

import 'stopwatch_task.dart';

// =============================================================================
// MÀN HÌNH NHIỀU ĐỒNG HỒ (đa tác vụ)
// =============================================================================
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final List<StopwatchTask> _tasks = [];

  // Mỗi đồng hồ có 1 subscription "cảnh báo mốc 10 giây" → phải tự hủy.
  final Map<StopwatchTask, StreamSubscription<int>> _alertSubs = {};

  // Stream cho ô tìm kiếm (người gõ → đẩy chữ vào đây).
  final StreamController<String> _searchController = StreamController<String>();
  StreamSubscription<String>? _searchSub;
  String _query = '';

  bool _adding = false;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    log('▶ Mở màn hình đồng hồ');

    // TRANSFORM + DEBOUNCE:
    // chữ gõ vào → map (bỏ khoảng trắng, viết thường) → debounce 400ms → lọc.
    _searchSub = _searchController.stream
        .map((text) => text.trim().toLowerCase())
        .transform(debounce(const Duration(milliseconds: 400)))
        .listen((text) {
      log('🔍 Debounce xong, lọc theo: "$text"');
      setState(() => _query = text);
    });

    _addStopwatch();
  }

  // FUTURE + ASYNC/AWAIT: giả lập việc tạo đồng hồ mất 0,5 giây.
  Future<void> _addStopwatch() async {
    setState(() => _adding = true);

    await Future.delayed(const Duration(milliseconds: 500)); // chờ, không đơ app

    // Trong lúc chờ, người dùng có thể đã thoát màn hình!
    // Nếu vậy thì dừng lại, không gọi setState (sẽ báo lỗi).
    if (!mounted) {
      log('⚠ Màn hình đã đóng trong lúc await → bỏ qua');
      return;
    }

    _counter++;
    final task = StopwatchTask('Đồng hồ $_counter');

    // BROADCAST: đây là listener THỨ HAI trên cùng stream (listener thứ nhất
    // là StreamBuilder hiển thị số). Stream thường sẽ báo lỗi ở đây.
    _alertSubs[task] = task.stream
        .map((d) => d.inSeconds) // Duration → số giây
        .distinct() // bỏ các giá trị trùng (mỗi giây chỉ giữ 1 lần)
        .where((s) => s > 0 && s % 10 == 0) // chỉ lấy mốc 10, 20, 30…
        .listen((s) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ ${task.name} đã chạy $s giây'),
          duration: const Duration(seconds: 1),
        ),
      );
    });

    setState(() {
      _tasks.add(task);
      _adding = false;
    });
    log('➕ Thêm ${task.name}');
  }

  void _removeStopwatch(StopwatchTask task) {
    _alertSubs.remove(task)?.cancel(); // hủy listener cảnh báo
    task.dispose(); // tắt Timer, đóng Stream
    setState(() => _tasks.remove(task));
  }

  // HỦY LUỒNG AN TOÀN KHI THOÁT MÀN HÌNH
  @override
  void dispose() {
    log('◀ Thoát màn hình → bắt đầu dọn dẹp');
    _searchSub?.cancel(); // 1. hủy nghe ô tìm kiếm
    _searchController.close(); // 2. đóng stream tìm kiếm
    for (final sub in _alertSubs.values) {
      sub.cancel(); // 3. hủy các listener cảnh báo
    }
    for (final task in _tasks) {
      task.dispose(); // 4. tắt Timer + đóng Stream của từng đồng hồ
    }
    log('✅ Dọn dẹp xong, không còn Timer nào chạy');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _tasks.where((t) => t.name.toLowerCase().contains(_query)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Nhiều đồng hồ bấm giờ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _addStopwatch,
        icon: _adding
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_adding ? 'Đang tạo…' : 'Thêm đồng hồ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm đồng hồ (VD: 2)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _searchController.add, // mỗi lần gõ → đẩy vào Stream
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                for (final task in visible)
                  StopwatchCard(
                    key: ObjectKey(task),
                    task: task,
                    onChanged: () => setState(() {}),
                    onDelete: () => _removeStopwatch(task),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// THẺ MỘT ĐỒNG HỒ
// =============================================================================
class StopwatchCard extends StatelessWidget {
  const StopwatchCard({
    super.key,
    required this.task,
    required this.onChanged,
    required this.onDelete,
  });

  final StopwatchTask task;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.name),
                  // STREAMBUILDER: tự lắng nghe stream và vẽ lại khi có số mới.
                  // Khi thẻ bị gỡ khỏi màn hình, nó TỰ hủy subscription.
                  StreamBuilder<Duration>(
                    stream: task.stream,
                    initialData: task.elapsed,
                    builder: (context, snapshot) => Text(
                      formatTime(snapshot.data ?? Duration.zero),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: task.isRunning ? 'Tạm dừng' : 'Chạy',
              icon: Icon(task.isRunning ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                task.isRunning ? task.pause() : task.start();
                onChanged();
              },
            ),
            IconButton(
              tooltip: 'Đặt lại',
              icon: const Icon(Icons.replay),
              onPressed: task.isRunning ? null : task.reset,
            ),
            IconButton(
              tooltip: 'Xóa',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
