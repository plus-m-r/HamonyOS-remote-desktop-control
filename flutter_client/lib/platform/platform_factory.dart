import 'dart:io';

import 'input_injector.dart';
import 'linux_capturer.dart';
import 'linux_injector.dart';
import 'screen_capturer.dart';
import 'windows_capturer.dart';
import 'windows_injector.dart';

/// 平台能力工厂：按运行平台创建对应的抓屏器/注入器。
///
/// 业务层（会话/瓦片/压缩）只依赖 [ScreenCapturer]/[InputInjector] 抽象，
/// 不直接 new 平台类 —— 加新平台只改这里。
class PlatformFactory {
  /// 创建当前平台的抓屏器。
  static ScreenCapturer createCapturer() {
    if (Platform.isWindows) return WindowsCapturer();
    if (Platform.isLinux) return LinuxCapturer();
    throw UnsupportedError('未支持的平台: ${Platform.operatingSystem}');
  }

  /// 创建当前平台的输入注入器。
  static InputInjector createInjector() {
    if (Platform.isWindows) return WindowsInjector();
    if (Platform.isLinux) return LinuxInjector();
    throw UnsupportedError('未支持的平台: ${Platform.operatingSystem}');
  }
}