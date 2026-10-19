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

  bool _loadingPreset = false;

  @override
  void initState() {
    super.initState();

    // Lắng nghe dữ liệu ô tìm kiếm: chuẩn hóa chữ và áp dụng debounce 400ms
    _searchSub = _searchController.stream
        .map((text) => text.trim().toLowerCase())
        .transform(debounce(const Duration(milliseconds: 400)))
        .listen((text) {
      log('Debounce 400ms hoàn tất, lọc theo từ khóa: "$text"', isDev: true);
      setState(() => _query = text);
    });

    // Tự động tạo đồng hồ đầu tiên nếu danh sách trống
    if (_tasks.isEmpty) {
      _addStopwatchImmediate();
    } else {
      for (final task in _tasks) {
        _listenToAlert(task);
      }
    }
  }

  // Mở trang Lịch sử & Nhật ký riêng biệt
  void _openLogScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogScreen(
          onRunEventLoopBenchmark: _runStopwatchBenchmarkWithEventLoop,
        ),
      ),
    );
  }

  // Lắng nghe broadcast stream để cảnh báo mốc 10 giây
  void _listenToAlert(StopwatchTask task) {
    final startSecond = task.elapsed.inSeconds;
    _alertSubs[task] = task.stream
        .map((d) => d.inSeconds)
        .distinct()
        .skipWhile((s) => s == startSecond)
        .where((s) => s > 0 && s % 10 == 0)
        .listen((s) {
      if (!mounted) return;
      log('🏆 [${task.name}] Đạt cột mốc duy trì $s giây!',
          isDev: false, category: 'alert');
      log('[${task.name}] Broadcast Stream phát sự kiện mốc $s giây (qua map -> distinct -> where)',
          isDev: true, category: 'alert');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF00695C),
          content: Text('⏰ ${task.name} đã đạt mốc $s giây!'),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  // Tạo đồng hồ mới NGAY LẬP TỨC (Không bắt chờ 500ms vô lý nữa)
  void _addStopwatchImmediate([String? customName]) {
    int number = 1;
    while (_tasks.any((t) => t.name == 'Đồng hồ $number')) {
      number++;
    }
    final name = customName ?? 'Đồng hồ $number';
    final task = StopwatchTask(name);
    _listenToAlert(task);

    setState(() {
      if (customName == null && number - 1 <= _tasks.length) {
        _tasks.insert(number - 1, task);
      } else {
        _tasks.add(task);
      }
    });
    log('➕ Đã thêm "$name"', isDev: false);
    log('Đã khởi tạo đối tượng StopwatchTask("$name") & đăng ký lắng nghe Broadcast Stream',
        isDev: true);
  }

  // TÍNH NĂNG FUTURE & ASYNC/AWAIT THỰC TẾ: Nạp bộ mẫu bài tập (Preset) từ cấu hình
  Future<void> _loadWorkoutPreset() async {
    setState(() => _loadingPreset = true);
    log('📦 Đang tải bộ đồng hồ mẫu (Tập HIIT)...', isDev: false);
    log('Bắt đầu tác vụ bất đồng bộ Future.delayed(600ms) nạp danh sách Preset',
        isDev: true);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final presets = ['Khởi động (Warm-up)', 'Chạy nước rút (Sprint)', 'Giãn cơ (Cool-down)'];
    for (final name in presets) {
      if (!_tasks.any((t) => t.name == name)) {
        _addStopwatchImmediate(name);
      }
    }

    setState(() => _loadingPreset = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF00695C),
        content: Text('✅ Đã nạp xong bộ 3 đồng hồ tập luyện!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Xóa một đồng hồ khỏi danh sách và hủy luồng an toàn
  void _removeStopwatch(StopwatchTask task) {
    final sub = _alertSubs.remove(task);
    sub?.cancel();
    task.dispose();

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
        behavior: SnackBarBehavior.floating,
        content: Text('Đã hủy an toàn toàn bộ luồng đồng hồ'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // TÍNH NĂNG EVENT LOOP GẮN VỚI ĐỒNG HỒ: Kiểm tra độ trễ xung nhịp (Benchmark Latency)
  void _runStopwatchBenchmarkWithEventLoop() {
    final sw = Stopwatch()..start();
    log('--- KIỂM TRA ĐỘ TRỄ XUNG NHỊP ĐỒNG HỒ (EVENT LOOP BENCHMARK) ---',
        isDev: true, category: 'event_loop');
    log('1. [Sync] Bắt đầu đo tại: ${sw.elapsedMicroseconds} µs',
        isDev: true, category: 'event_loop');

    Future(() {
      log('5. [Event Queue - Future] Xử lý tác vụ UI nền tại: ${sw.elapsedMicroseconds} µs',
          isDev: true, category: 'event_loop');
    });

    Timer(Duration.zero, () {
      final totalUs = sw.elapsedMicroseconds;
      sw.stop();
      log('6. [Event Queue - Timer(0)] Hoàn tất chu kỳ kiểm tra tại: $totalUs µs',
          isDev: true, category: 'event_loop');
      log('⚡ Kết quả kiểm tra độ trễ hệ thống: $totalUs micro-giây (Độ chính xác cao)',
          isDev: false, category: 'event_loop');
    });

    scheduleMicrotask(() {
      log('3. [Microtask Queue - scheduleMicrotask] Ưu tiên tính toán mốc giờ tại: ${sw.elapsedMicroseconds} µs',
          isDev: true, category: 'event_loop');
    });

    Future.microtask(() {
      log('4. [Microtask Queue - Future.microtask] Đồng bộ trạng thái luồng tại: ${sw.elapsedMicroseconds} µs',
          isDev: true, category: 'event_loop');
    });

    log('2. [Sync] Kết thúc lệnh đồng bộ tại: ${sw.elapsedMicroseconds} µs',
        isDev: true, category: 'event_loop');
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
            const Expanded(
              child: Text(
                'Future & Stream – Đồng hồ',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Nút mở trang Lịch sử & Nhật ký kèm Badge trên AppBar
          ValueListenableBuilder<int>(
            valueListenable: logCountNotifier,
            builder: (context, count, _) {
              return IconButton(
                tooltip: 'Lịch sử & Nhật ký hệ thống',
                onPressed: _openLogScreen,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: const Color(0xFF00796B),
                  child: const Icon(
                    Icons.history_edu_rounded,
                    color: Color(0xFF1E293B),
                  ),
                ),
              );
            },
          ),
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
      // Nút nổi dưới góc phải để mở nhanh trang Nhật ký / Lịch sử
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: logCountNotifier,
        builder: (context, count, _) {
          return FloatingActionButton.extended(
            onPressed: _openLogScreen,
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.terminal_rounded, color: Color(0xFF4DB6AC)),
            label: Text(
              'Lịch sử & Log ($count)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hàng nút thao tác chính (Hợp lý 100% với nghiệp vụ đồng hồ)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _addStopwatchImmediate(),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Thêm đồng hồ',
                          style: TextStyle(
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
                        onPressed: _loadingPreset ? null : _loadWorkoutPreset,
                        icon: _loadingPreset
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00695C),
                                ),
                              )
                            : const Icon(Icons.fitness_center_rounded,
                                size: 19),
                        label: Text(
                          _loadingPreset
                              ? 'Đang nạp mẫu...'
                              : 'Nạp mẫu tập HIIT (Async)',
                          style: const TextStyle(
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
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: visibleTasks.length,
                          itemBuilder: (context, index) {
                            final task = visibleTasks[index];
                            return StopwatchCard(
                              key: ObjectKey(task),
                              task: task,
                              onChanged: () => setState(() {}),
                              onDelete: () => _removeStopwatch(task),
                              onLapMessage: (msg) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context)
                                    .hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 1),
                                    content: Text(msg),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}