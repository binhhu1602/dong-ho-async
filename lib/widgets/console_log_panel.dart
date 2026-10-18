import 'package:flutter/material.dart';
import '../stopwatch_task.dart';

class ConsoleLogPanel extends StatelessWidget {
  const ConsoleLogPanel({
    super.key,
    required this.scrollController,
    required this.onClear,
  });

  final ScrollController scrollController;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header của khung Nhật ký
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal_rounded,
                        color: Color(0xFF4DB6AC), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Nhật ký hoạt động:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${appLogs.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                if (appLogs.isNotEmpty)
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Xóa nhật ký',
                        style: TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4DB6AC),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Danh sách các dòng nhật ký
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: appLogs.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có nhật ký nào. Hãy bấm các nút phía trên để thử nghiệm!',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: appLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            appLogs[index],
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}