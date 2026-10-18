import 'package:flutter_test/flutter_test.dart';

import 'package:dong_ho_async/main.dart';

void main() {
  // Kiểm thử giao diện màn hình chính
  testWidgets('HomeScreen smoke test', (WidgetTester tester) async {
    // Khởi tạo ứng dụng
    await tester.pumpWidget(const MyApp());

    // Kiểm tra các thành phần chính có hiển thị đầy đủ
    expect(find.text('Future & Stream – Đồng hồ'), findsOneWidget);
    expect(find.text('Mở đồng hồ bấm giờ'), findsOneWidget);
    expect(find.text('Chạy thử Event Loop'), findsOneWidget);
    expect(find.text('Nhật ký:'), findsOneWidget);
  });
}
