import 'dart:async';

import 'package:flutter/material.dart';

import 'stopwatch_task.dart';

// Màn hình quản lý danh sách nhiều đồng hồ bấm giờ
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final List<StopwatchTask> _tasks = [];

  // Lưu subscription thông báo của từng đồng hồ để hủy khi cần
  final Map<StopwatchTask, StreamSubscription<int>> _alertSubs = {};

  // Stream cho ô tìm kiếm
  final StreamController<String> _searchController = StreamController<String>();
  StreamSubscription<String>? _searchSub;
  String _query = '';

  bool _adding = false;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    log('Mở màn hình đồng hồ');

    // Lắng nghe dữ liệu ô tìm kiếm: chuẩn hóa chữ và áp dụng debounce 400ms
    _searchSub = _searchController.stream
        .map((text) => text.trim().toLowerCase())
        .transform(debounce(const Duration(milliseconds: 400)))
        .listen((text) {
      log('Đã debounce, tìm kiếm theo: "$text"');
      setState(() => _query = text);
    });

    // Thêm đồng hồ đầu tiên khi mở màn hình
    _addStopwatch();
  }

  // Thêm đồng hồ mới (giả lập tác vụ bất đồng bộ mất 0.5s)
  Future<void> _addStopwatch() async {
    setState(() => _adding = true);

    await Future.delayed(const Duration(milliseconds: 500));

    // Kiểm tra xem màn hình còn hiển thị hay không trước khi gọi setState
    if (!mounted) {
      log('Màn hình đã đóng trước khi tạo xong đồng hồ');
      return;
    }

    _counter++;
    final task = StopwatchTask('Đồng hồ $_counter');

    // Lắng nghe broadcast stream để hiển thị thông báo mỗi khi đồng hồ chạy được 10s
    _alertSubs[task] = task.stream
        .map((d) => d.inSeconds)
        .distinct()
        .where((s) => s > 0 && s % 10 == 0)
        .listen((s) {
      if (!mounted) return;
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
    log('Đã thêm ${task.name}');
  }

  // Xóa một đồng hồ khỏi danh sách
  void _removeStopwatch(StopwatchTask task) {
    // Hủy lắng nghe thông báo mốc 10s
    final sub = _alertSubs.remove(task);
    if (sub != null) {
      sub.cancel();
    }

    // Tắt Timer và đóng Stream của đồng hồ
    task.dispose();

    setState(() {
      _tasks.remove(task);
    });
  }

  // Hủy luồng an toàn khi thoát khỏi màn hình
  @override
  void dispose() {
    log('Thoát màn hình: bắt đầu dọn dẹp tài nguyên');

    // 1. Hủy lắng nghe ô tìm kiếm
    _searchSub?.cancel();

    // 2. Đóng StreamController ô tìm kiếm
    _searchController.close();

    // 3. Hủy các subscription lắng nghe thông báo
    for (final sub in _alertSubs.values) {
      sub.cancel();
    }

    // 4. Hủy Timer và đóng Stream của từng đồng hồ
    for (final task in _tasks) {
      task.dispose();
    }

    log('Dọn dẹp hoàn tất: không còn Stream hay Timer nào chạy ngầm');
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
              onChanged: (text) {
                // Đẩy ký tự vừa gõ vào Stream
                _searchController.add(text);
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                for (final task in visible)
                  StopwatchCard(
                    key: ValueKey(task.name),
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

// Widget hiển thị từng thẻ đồng hồ
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
                  // StreamBuilder tự động lắng nghe Stream và cập nhật UI khi có số mới
                  StreamBuilder<Duration>(
                    stream: task.stream,
                    initialData: task.elapsed,
                    builder: (context, snapshot) => Text(
                      formatTime(snapshot.data ?? Duration.zero),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
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
                if (task.isRunning) {
                  task.pause();
                } else {
                  task.start();
                }
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
