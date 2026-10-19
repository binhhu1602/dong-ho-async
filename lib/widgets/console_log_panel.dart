import 'package:flutter/material.dart';
import '../stopwatch_task.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.onRunEventLoopBenchmark});

  final VoidCallback onRunEventLoopBenchmark;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showDevLogs = false; // Mặc định chỉ hiện Lịch sử bấm giờ cho người dùng

  @override
  void initState() {
    super.initState();
    logCountNotifier.addListener(_onLogChanged);
    _scrollToBottom();
  }

  void _onLogChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    logCountNotifier.removeListener(_onLogChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _showDevLogs
        ? appLogs
        : appLogs.where((entry) => !entry.isDevLog).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(
              _showDevLogs ? Icons.terminal_rounded : Icons.history_rounded,
              color: const Color(0xFF4DB6AC),
              size: 22,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _showDevLogs
                    ? 'Developer Log (Stream & Event Loop)'
                    : 'Lịch sử phiên bấm giờ',
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
       actions: [
          
          Row(
            children: [
              const Text(
                'Dev Debug',
                style: TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
              Switch(
                value: _showDevLogs,
                activeThumbColor: const Color(0xFF4DB6AC), 
                onChanged: (val) {
                  setState(() => _showDevLogs = val);
                  _scrollToBottom();
                },
              ),
            ],
          ),
          if (appLogs.isNotEmpty)
            const IconButton( 
              tooltip: 'Xóa sạch nhật ký',
              onPressed: clearLogs,
              icon: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showDevLogs
                              ? 'Đang hiển thị toàn bộ luồng kỹ thuật: Sync -> Microtask Queue -> Event Queue, Debounce 400ms và Broadcast Stream.'
                              : 'Đang hiển thị lịch sử bấm giờ gọn gàng cho người dùng. Bật "Dev Debug" ở góc trên để xem chi tiết luồng kỹ thuật.',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() => _showDevLogs = true);
                          widget.onRunEventLoopBenchmark();
                        },
                        icon: const Icon(Icons.speed_rounded, size: 18),
                        label: const Text('Kiểm tra Event Loop'),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF00796B).withValues(alpha: 0.3),
                          foregroundColor: const Color(0xFF80CBC4),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ConsoleLogPanel(
                    scrollController: _scrollController,
                    logs: filteredLogs,
                    onClear: clearLogs,
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

class ConsoleLogPanel extends StatelessWidget {
  const ConsoleLogPanel({
    super.key,
    required this.scrollController,
    required this.logs,
    required this.onClear,
  });

  final ScrollController scrollController;
  final List<LogEntry> logs;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header cửa sổ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildDot(const Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    _buildDot(const Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    _buildDot(const Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    Text(
                      'Hiển thị: ${logs.length} sự kiện',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Danh sách các dòng nhật ký
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có dữ liệu nhật ký nào trong chế độ này.',
                        style: TextStyle(color: Colors.white54, fontSize: 13.5),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final item = logs[index];
                        Color textColor = const Color(0xFF69F0AE);

                        if (item.category == 'alert') {
                          textColor = Colors.amberAccent;
                        } else if (item.category == 'event_loop') {
                          textColor = Colors.cyanAccent;
                        } else if (item.category == 'lap') {
                          textColor = Colors.white;
                        } else if (item.isDevLog) {
                          textColor = Colors.blueGrey.shade200;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SelectableText(
                            '[${item.timestamp}] ${item.message}',
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'monospace',
                              fontSize: 13.5,
                              height: 1.4,
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

  Widget _buildDot(Color color) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}