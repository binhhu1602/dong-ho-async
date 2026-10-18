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
  // Danh sách đồng hồ được lưu dùng chung để không bị mất khi thoát ra vào lại
  List<StopwatchTask> get _tasks => appStopwatchTasks;

  // Quản lý subscription thông báo của từng đồng hồ
  final Map<StopwatchTask, StreamSubscription<int>> _alertSubs = {};

  final StreamController<String> _searchController = StreamController<String>();
  StreamSubscription<String>? _searchSub;
  String _query = '';

  bool _adding = false;

  @override
  void initState() {
    super.initState();

    // Lắng nghe dữ liệu ô tìm kiếm: chuẩn hóa chữ và áp dụng debounce 400ms
    _searchSub = _searchController.stream
        .map((text) => text.trim().toLowerCase())
        .transform(debounce(const Duration(milliseconds: 400)))
        .listen((text) {
      log('Đã debounce, tìm kiếm theo: "$text"');
      setState(() => _query = text);
    });

    // Nếu chưa có đồng hồ nào thì tự động tạo Đồng hồ 1
    if (_tasks.isEmpty) {
      _addStopwatch();
    } else {
      // Gắn lắng nghe thông báo mốc 10s cho các đồng hồ đang có
      for (final task in _tasks) {
        _listenToAlert(task);
      }
    }
  }

  // Lắng nghe broadcast stream để cảnh báo mốc 10 giây
  void _listenToAlert(StopwatchTask task) {
    _alertSubs[task] = task.stream
        .map((d) => d.inSeconds)
        .distinct()
        .where((s) => s > 0 && s % 10 == 0)
        .listen((s) {
      log('[${task.name}] Cảnh báo Stream: đã chạy mốc $s giây');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ ${task.name} đã chạy $s giây'),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  // Thêm đồng hồ mới (giả lập tác vụ bất đồng bộ mất 0.5s)
  Future<void> _addStopwatch() async {
    setState(() => _adding = true);

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    appStopwatchCounter++;
    final task = StopwatchTask('Đồng hồ $appStopwatchCounter');
    _listenToAlert(task);

    setState(() {
      _tasks.add(task);
      _adding = false;
    });
    log('Đã tạo xong ${task.name} và mở Broadcast Stream');
  }

  // Xóa một đồng hồ khỏi danh sách và hủy luồng an toàn
  void _removeStopwatch(StopwatchTask task) {
    final sub = _alertSubs.remove(task);
    if (sub != null) {
      sub.cancel();
    }

    task.dispose();
    log('[${task.name}] Đã xóa khỏi danh sách');

    setState(() {
      _tasks.remove(task);
    });
  }

  // Hủy tất cả đồng hồ và dọn dẹp bộ nhớ an toàn
  void _clearAllStopwatches() {
    for (final sub in _alertSubs.values) {
      sub.cancel();
    }
    _alertSubs.clear();

    disposeAllStopwatches();

    setState(() {});
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã hủy an toàn toàn bộ luồng đồng hồ'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _searchSub?.cancel();
    _searchController.close();

    for (final sub in _alertSubs.values) {
      sub.cancel();
    }
    _alertSubs.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _tasks.where((t) => t.name.toLowerCase().contains(_query)).toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        ScaffoldMessenger.of(context).clearSnackBars();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nhiều đồng hồ bấm giờ'),
          actions: [
            if (_tasks.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Hủy và dọn dẹp tất cả đồng hồ',
                onPressed: _clearAllStopwatches,
              ),
          ],
        ),
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
