import 'dart:async';
import 'package:flutter/material.dart';
import 'stopwatch_task.dart';
import 'widgets/stopwatch_card.dart';
import 'widgets/console_log_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<StopwatchTask> get _tasks => appStopwatchTasks;
  final Map<StopwatchTask, StreamSubscription<int>> _alertSubs = {};

  final StreamController<String> _searchController = StreamController<String>();
  final TextEditingController _textController = TextEditingController();
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
      if (!mounted) return;
      // setState để khung Nhật ký vẽ lại ngay khi có dòng mới
      setState(() {
        log('[${task.name}] Cảnh báo Stream: đã chạy mốc $s giây');
      });
      _scrollToBottom();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF00695C),
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
        behavior: SnackBarBehavior.floating,
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
    _textController.dispose();

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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.timer_outlined,
                  color: Color(0xFF00796B), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Future & Stream – Đồng hồ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        actions: [
          if (_tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: Colors.redAccent),
              tooltip: 'Hủy toàn bộ luồng đồng hồ',
              onPressed: _clearAllStopwatches,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hàng nút thao tác chính
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
                            : const Icon(Icons.add_rounded, size: 20),
                        label: Text(
                          _adding ? 'Đang tạo (500ms)…' : 'Thêm đồng hồ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00695C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _runEventLoopDemo,
                        icon: const Icon(Icons.loop_rounded, size: 20),
                        label: const Text(
                          'Chạy thử Event Loop',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00695C),
                          side: const BorderSide(
                              color: Color(0xFF00695C), width: 1.5),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Ô tìm kiếm có áp dụng StreamTransformer Debounce
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    onChanged: (text) => _searchController.add(text),
                    decoration: InputDecoration(
                      hintText: 'Tìm đồng hồ theo tên (Debounce 400ms)...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFF00796B)),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _textController.clear();
                                _searchController.add('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF00796B), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Danh sách các đồng hồ bấm giờ
                Expanded(
                  child: visibleTasks.isEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_off_outlined,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text(
                                  _tasks.isEmpty
                                      ? 'Chưa có đồng hồ nào. Hãy bấm "Thêm đồng hồ"!'
                                      : 'Không tìm thấy đồng hồ nào phù hợp.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
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
                const SizedBox(height: 12),

                // 4. Khung Nhật ký hoạt động ở đáy màn hình
                ConsoleLogPanel(
                  scrollController: _logScrollController,
                  onClear: () {
                    setState(() {
                      appLogs.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
