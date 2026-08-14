import 'dart:typed_data';

/// 屏幕捕获器接口：每个平台一份实现。
/// 对照 Java 端 CaptureFactory（getDimension + captureScreen）。
abstract class ScreenCapturer {
  int get width; // 屏幕宽（像素）
  int get height; // 屏幕高（像素）

  /// 抓一帧屏幕，返回 BGRA 像素（4 字节/像素）。
  /// 对应 Java 的 captureScreen(Gray8Bits) 彩色分支。
  Future<Uint8List> capture();

  /// 释放平台原生资源（display/DC/位图等）。
  void dispose();
}
