// 基本冒烟测试：验证应用能启动并显示左侧导航与连接页。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/main.dart';

void main() {
  testWidgets('App starts and shows nav + connect page', (WidgetTester tester) async {
    await tester.pumpWidget(const RemoteControlApp());

    expect(find.text('连接'), findsWidgets);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('工具'), findsOneWidget);
    expect(find.text('连接远程设备'), findsOneWidget);
  });
}
