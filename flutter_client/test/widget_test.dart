// 基本冒烟测试：验证应用能启动并显示左侧导航与连接页。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/main.dart';

void main() {
  testWidgets('App starts and shows nav + connect page', (WidgetTester tester) async {
    await tester.pumpWidget(const RemoteControlApp());

    expect(find.text('连接'), findsWidgets);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('工具'), findsOneWidget);
    expect(find.text('连接服务端'), findsWidgets); // 卡片标题 + 连接按钮，出现多次
    expect(find.text('连接设备'), findsWidgets); // 同上
    expect(find.text('本机设置'), findsOneWidget);
  });
}
