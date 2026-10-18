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
  // Demo thứ tự chạy: Code đồng bộ -> Microtask Queue -> Event Queue
  void _runEventLoopDemo() {
    appLogs.clear();
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
      if (mounted) setState(() {});
    });
  }

  // Chuyển sang màn hình đồng hồ
  Future<void> _openStopwatches() async {
    appLogs.clear();

    // Chờ người dùng thoát màn hình đồng hồ quay về
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StopwatchScreen()),
    );

    // Cập nhật lại giao diện để xem nhật ký dọn dẹp
    if (mounted) setState(() {});
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
            const Text(
              'Nhật ký:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black87,
                child: ListView(
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
