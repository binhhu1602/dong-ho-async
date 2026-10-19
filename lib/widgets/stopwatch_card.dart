import 'package:flutter/material.dart';
import '../stopwatch_task.dart';

class StopwatchCard extends StatelessWidget {
  const StopwatchCard({
    super.key,
    required this.task,
    required this.onChanged,
    required this.onDelete,
    required this.onLapMessage,
  });

  final StopwatchTask task;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final void Function(String message) onLapMessage;

  @override
  Widget build(BuildContext context) {
    final bool running = task.isRunning;
    final bool countingDown = task.isCountingDown;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: running
            ? const Color(0xFFF0FDF4)
            : countingDown
                ? const Color(0xFFFFFBEB)
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: running
              ? const Color(0xFF00897B).withValues(alpha: 0.5)
              : countingDown
                  ? Colors.amber.shade400
                  : Colors.grey.shade200,
          width: (running || countingDown) ? 1.5 : 1,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                                  : countingDown
                                      ? Colors.amber.shade700
                                      : Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              task.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          if (countingDown) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Chuẩn bị: ${task.countdownValue}s...',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ] else if (running) ...[
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
                      // StreamBuilder cập nhật thời gian thực từ Stream<Duration>
                      StreamBuilder<Duration>(
                        stream: task.stream,
                        initialData: task.elapsed,
                        builder: (context, snapshot) => Text(
                          countingDown
                              ? '00:0${task.countdownValue}.00'
                              : formatTime(snapshot.data ?? Duration.zero),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: countingDown
                                ? Colors.amber.shade800
                                : running
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

                // Nút Đếm ngược 3s xuất phát (Dùng Future & async/await thực tế)
                if (!running && task.elapsed == Duration.zero) ...[
                   OutlinedButton.icon(
                    onPressed: countingDown
                        ? null
                        : () => task.startWithCountdown(onChanged),
                    icon: const Icon(Icons.timer_3_select_rounded, size: 18),
                    label: const Text('Đếm ngược'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00796B),
                      side: BorderSide(color: Colors.teal.shade200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Nút Chạy / Tạm dừng
                IconButton.filled(
                  tooltip: running ? 'Tạm dừng' : 'Chạy ngay',
                  onPressed: countingDown
                      ? null
                      : () {
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

                // Nút Chốt vòng (Lap - khi đang chạy) HOẶC Đặt lại (Reset - khi đang dừng)
                if (running)
                  IconButton.outlined(
                    tooltip: 'Chốt vòng (Ứng dụng Event Loop)',
                    onPressed: () {
                      task.recordLap(
                        onUIUpdate: onChanged,
                        onLapAnalyzed: onLapMessage,
                      );
                    },
                    icon: const Icon(Icons.flag_rounded, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF00695C),
                      side: const BorderSide(color: Color(0xFF00897B)),
                      backgroundColor: Colors.white,
                      minimumSize: const Size(42, 42),
                    ),
                  )
                else
                  IconButton.outlined(
                    tooltip: 'Đặt lại',
                    onPressed: (countingDown || task.elapsed == Duration.zero)
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

            // Hiển thị danh sách các vòng chạy (Lap) nếu có
            if (task.laps.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: task.laps.take(4).map((lap) {
                  Color bgColor = Colors.grey.shade100;
                  Color textColor = const Color(0xFF334155);
                  String prefix = 'Vòng ${lap.lapNumber}';

                  if (lap.isFastest) {
                    bgColor = const Color(0xFFD1FAE5);
                    textColor = const Color(0xFF065F46);
                    prefix = '⚡ Vòng ${lap.lapNumber}';
                  } else if (lap.isSlowest) {
                    bgColor = const Color(0xFFFEE2E2);
                    textColor = const Color(0xFF991B1B);
                    prefix = '🐢 Vòng ${lap.lapNumber}';
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$prefix: +${formatTime(lap.splitTime)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}