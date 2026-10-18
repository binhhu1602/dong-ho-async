import 'dart:async';

import 'package:flutter/material.dart';

import 'stopwatch_task.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Future & Stream – Đồng hồ',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
      ),
      home: const HomeScreen(),
    );
  }
}

// Màn hình chính tích hợp toàn bộ tính năng trên một trang
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<StopwatchTask> get _tasks => appStopwatchTasks;
  final Map<StopwatchTask, StreamSubscription<int>> _alertSubs = {};

  final StreamController<String> _searchController = StreamController<String>();
  StreamSubscription<String>? _searchSub;
  String _query = '';

  final ScrollController _logScrollController = ScrollController();
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
      _scrollToBottom();
    });

    // Tự động tạo đồng hồ đầu tiên nếu danh sách trống
    if (_tasks.isEmpty) {
      _addStopwatch();
    } else {
      for (final task in _tasks) {
        _listenToAlert(task);
      }
    }
  }

  // Tự động cuộn xuống dòng nhật ký mới nhất
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Lắng nghe broadcast stream để cảnh báo mốc 10 giây
  void _listenToAlert(StopwatchTask task) {
    _alertSubs[task] = task.stream
        .map((d) => d.inSeconds)
        .distinct()
        .where((s) => s > 0 && s % 10 == 0)
        .listen((s) {
      log('[${task.name}] Cảnh báo Stream: đã chạy mốc $s giây');
      _scrollToBottom();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ ${task.name} đã chạy $s giây'),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  // Thêm đồng hồ mới (giả lập tác vụ bất đồng bộ mất 0.5s với Future & async/await)
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
    _scrollToBottom();
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
    _scrollToBottom();
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
    _scrollToBottom();
  }

  // Demo thứ tự chạy: Code đồng bộ -> Microtask Queue -> Event Queue
  void _runEventLoopDemo() {
    log('--- THỬ NGHIỆM EVENT LOOP ---');
    log('1. Code đồng bộ: bắt đầu');

    // Đẩy vào Event Queue (độ ưu tiên sau Microtask)
    Future(() => log('5. Future() -> Event Queue'));
    Timer(Duration.zero, () => log('6. Timer(0) -> Event Queue'));

    // Đẩy vào Microtask Queue (ưu tiên cao, chạy trước Event Queue)
    scheduleMicrotask(() => log('3. scheduleMicrotask -> Microtask Queue'));
    Future.microtask(() => log('4. Future.microtask -> Microtask Queue'));

    log('2. Code đồng bộ: kết thúc');

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _searchSub?.cancel();
    _searchController.close();

    for (final sub in _alertSubs.values) {
      sub.cancel();
    }
    _alertSubs.clear();

    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTasks =
        _tasks.where((t) => t.name.toLowerCase().contains(_query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Future & Stream – Đồng hồ'),
        actions: [
          if (_tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Hủy toàn bộ luồng đồng hồ',
              onPressed: _clearAllStopwatches,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hàng nút thao tác chính
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _adding ? null : _addStopwatch,
                    icon: _adding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(_adding ? 'Đang tạo…' : 'Thêm đồng hồ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _runEventLoopDemo,
                    icon: const Icon(Icons.loop),
                    label: const Text('Chạy thử Event Loop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Ô tìm kiếm có áp dụng Debounce
            TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm đồng hồ theo tên (Debounce 400ms)...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.all(10),
              ),
              onChanged: (text) => _searchController.add(text),
            ),
            const SizedBox(height: 10),

            // Danh sách các đồng hồ bấm giờ (chiếm không gian giữa)
            Expanded(
              child: visibleTasks.isEmpty
                  ? Center(
                      child: Text(
                        _tasks.isEmpty
                            ? 'Chưa có đồng hồ nào. Hãy bấm "Thêm đồng hồ"!'
                            : 'Không tìm thấy đồng hồ nào phù hợp.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final task in visibleTasks)
                          StopwatchCard(
                            key: ValueKey(task.name),
                            task: task,
                            onChanged: () {
                              setState(() {});
                              _scrollToBottom();
                            },
                            onDelete: () => _removeStopwatch(task),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),

            // Phần khung Nhật ký hoạt động
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nhật ký:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (appLogs.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        appLogs.clear();
                      });
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xóa nhật ký'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 180,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: appLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có nhật ký nào. Hãy bấm các nút phía trên để thử nghiệm!',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(
                        controller: _logScrollController,
                        children: [
                          for (final line in appLogs)
                            Text(
                              line,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
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
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // StreamBuilder tự động cập nhật thời gian thực
                  StreamBuilder<Duration>(
                    stream: task.stream,
                    initialData: task.elapsed,
                    builder: (context, snapshot) => Text(
                      formatTime(snapshot.data ?? Duration.zero),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: task.isRunning ? Colors.teal : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: task.isRunning ? 'Tạm dừng' : 'Chạy',
              icon: Icon(
                task.isRunning ? Icons.pause_circle : Icons.play_circle,
                color: task.isRunning ? Colors.orange : Colors.teal,
                size: 32,
              ),
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
              onPressed: task.isRunning
                  ? null
                  : () {
                      task.reset();
                      onChanged();
                    },
            ),
            IconButton(
              tooltip: 'Xóa',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
