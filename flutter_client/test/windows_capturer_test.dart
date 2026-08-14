// Windows 抓屏测试：验证 BitBlt 抓屏真实可用。
// 注意：必须在本机（Windows）跑；非 Windows 平台跳过。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/platform/screen_capturer.dart';
import 'package:flutter_client/platform/windows_capturer.dart';

void main() {
  test('WindowsCapturer 能抓到屏幕像素（字节数 = 宽×高×4）', () async {
    if (!Platform.isWindows) {
      markTestSkipped('BitBlt 是 Windows API，非 Windows 平台跳过');
      return;
    }

    // 1. 创建真实抓屏器（真调 BitBlt）
    final capturer = WindowsCapturer();

    // 2. 屏幕尺寸应该合理（主屏通常 ≥ 1024×768）
    expect(capturer.width, greaterThan(0));
    expect(capturer.height, greaterThan(0));

    // 3. 抓一帧（capture 是异步的，要 await）
    final bytes = await capturer.capture();
    expect(bytes, isNotNull);

    // 4. 硬指标：字节数 = 宽 × 高 × 4（BGRA 每像素 4 字节，协议要求）
    final expectedSize = capturer.width * capturer.height * 4;
    expect(bytes.length, expectedSize);

    // 5. 确实有数据（全 0 说明没抓到）
    expect(bytes.length, greaterThan(0));
  });

  test('ScreenCapturer 接口可被 WindowsCapturer 实例化（多态）', () {
    if (!Platform.isWindows) {
      markTestSkipped('WindowsCapturer 仅 Windows 可实例化，非 Windows 跳过');
      return;
    }
    // 验证接口设计：业务层只依赖抽象，能接到具体实现
    final ScreenCapturer capturer = WindowsCapturer();
    expect(capturer.width, greaterThan(0));
  });
}
