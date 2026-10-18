import 'package:flutter/material.dart';
import '../stopwatch_task.dart';

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
    final bool running = task.isRunning;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: running ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: running
              ? const Color(0xFF00897B).withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: running ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: running
                ? const Color(0xFF00796B).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Thông tin Tên đồng hồ & Thời gian thực
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: running
                              ? const Color(0xFF00897B)
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      if (running) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Đang chạy',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00695C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // StreamBuilder tự động cập nhật thời gian thực từ Stream<Duration>
                  StreamBuilder<Duration>(
                    stream: task.stream,
                    initialData: task.elapsed,
                    builder: (context, snapshot) => Text(
                      formatTime(snapshot.data ?? Duration.zero),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: running
                            ? const Color(0xFF00695C)
                            : const Color(0xFF334155),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Nút Chạy / Tạm dừng
            IconButton.filled(
              tooltip: running ? 'Tạm dừng' : 'Chạy',
              onPressed: () {
                if (running) {
                  task.pause();
                } else {
                  task.start();
                }
                onChanged();
              },
              icon: Icon(
                running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24,
              ),
              style: IconButton.styleFrom(
                backgroundColor: running
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF00897B),
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
              ),
            ),
            const SizedBox(width: 8),

            // Nút Đặt lại (Vô hiệu hóa khi đang chạy)
            IconButton.outlined(
              tooltip: 'Đặt lại',
              onPressed: running
                  ? null
                  : () {
                      task.reset();
                      onChanged();
                    },
              icon: const Icon(Icons.replay_rounded, size: 20),
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: BorderSide(color: Colors.grey.shade300),
                minimumSize: const Size(42, 42),
              ),
            ),
            const SizedBox(width: 8),

            // Nút Xóa
            IconButton.outlined(
              tooltip: 'Xóa',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              style: IconButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.red.shade100),
                backgroundColor: Colors.red.shade50.withValues(alpha: 0.4),
                minimumSize: const Size(42, 42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}