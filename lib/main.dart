import 'dart:async';

import 'package:flutter/material.dart';

import 'stopwatch_screen.dart';
import 'stopwatch_task.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomeScreen(),
    );
  }
}

// Màn hình chính
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _logScrollController = ScrollController();

  // Cuộn xuống dòng nhật ký mới nhất
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

    // Chờ các hàng đợi chạy xong rồi cập nhật giao diện
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    });
  }

  // Chuyển sang màn hình đồng hồ
  Future<void> _openStopwatches() async {
    ScaffoldMessenger.of(context).clearSnackBars();

    // Chờ người dùng thoát màn hình đồng hồ quay về
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StopwatchScreen()),
    );

    // Cập nhật lại giao diện để xem nhật ký và xóa thông báo cũ
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      setState(() {});
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Future & Stream – Đồng hồ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _openStopwatches,
              icon: const Icon(Icons.timer),
              label: const Text('Mở đồng hồ bấm giờ'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _runEventLoopDemo,
              icon: const Icon(Icons.loop),
              label: const Text('Chạy thử Event Loop'),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black87,
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
