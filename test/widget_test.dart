import 'package:flutter_test/flutter_test.dart';

import 'package:dong_ho_async/main.dart';

void main() {
  testWidgets('HomeScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Chờ Future.delayed(500ms) tạo đồng hồ ban đầu hoàn tất
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Future & Stream – Đồng hồ'), findsOneWidget);
    expect(find.text('Thêm đồng hồ'), findsOneWidget);
    expect(find.text('Chạy thử Event Loop'), findsOneWidget);
    expect(find.text('Nhật ký hoạt động:'), findsOneWidget);
  });
}
