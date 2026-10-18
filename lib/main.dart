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

// =============================================================================
// MÀN HÌNH CHÍNH: 2 nút + nhật ký
// =============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // EVENT LOOP & MICROTASK QUEUE
  // Dart chạy theo thứ tự:
  //   1. Code đồng bộ (chạy ngay)
  //   2. Microtask Queue (ưu tiên cao, chạy hết rồi mới tới event)
  //   3. Event Queue (Future, Timer…)
  void _runEventLoopDemo() {
    appLogs.clear();
    log('--- EVENT LOOP DEMO ---');
    log('1. Code đồng bộ: bắt đầu');

    Future(() => log('5. Future() → Event Queue'));
    Timer(Duration.zero, () => log('6. Timer(0) → Event Queue'));
    scheduleMicrotask(() => log('3. scheduleMicrotask → Microtask Queue'));
    Future.microtask(() => log('4. Future.microtask → Microtask Queue'));

    log('2. Code đồng bộ: kết thúc');

    // Đợi các hàng đợi chạy xong rồi vẽ lại để xem kết quả.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _openStopwatches() async {
    appLogs.clear();
    // AWAIT: chờ tới khi người dùng bấm Back quay về.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StopwatchScreen()),
    );
    // Quay về rồi → vẽ lại để xem nhật ký dọn dẹp (dispose).
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
            const Text('Nhật ký:',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
