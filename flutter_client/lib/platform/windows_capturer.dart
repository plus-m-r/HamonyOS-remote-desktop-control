import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'screen_capturer.dart';

/// Windows 抓屏：用 GDI 的 BitBlt 把屏幕像素复制到内存，再读出 BGRA 字节。
/// 对应 Java 端 RobotCaptureFactory + ScreenUtilities.captureColors()。
class WindowsCapturer implements ScreenCapturer {
  int _width = 0;
  int _height = 0;

  WindowsCapturer() {
    // 初始化：拿主屏幕尺寸（GetDC(null) 拿屏幕 DC，null = 主屏幕）
    final dc = GetDC(null);
    try {
      _width = GetDeviceCaps(dc, HORZRES); // 屏幕宽（像素）
      _height = GetDeviceCaps(dc, VERTRES); // 屏幕高（像素）
    } finally {
      ReleaseDC(null, dc); // 用完释放 DC
    }
  }

  @override
  int get width => _width;

  @override
  int get height => _height;

  @override
  Future<Uint8List> capture() async {
    // 屏幕 DC（画布）+ 内存 DC（临时画布）
    final screenDc = GetDC(null);
    final memDc = CreateCompatibleDC(screenDc);
    try {
      // 建一块和屏幕一样大的内存位图（临时存像素）
      final bitmap = CreateCompatibleBitmap(screenDc, _width, _height);
      try {
        // 把位图"挂"到内存 DC 上（HBITMAP → HGDIOBJ 包装转换）
        SelectObject(memDc, HGDIOBJ(bitmap));

        // BitBlt：把屏幕这块区域复制到内存位图（SRCCOPY = 直接复制）
        final result = BitBlt(memDc, 0, 0, _width, _height, screenDc, 0, 0, SRCCOPY);
        if (!result.value) {
          throw Exception('BitBlt 失败，错误码: ${result.error}');
        }

        return _readPixels(memDc, bitmap);
      } finally {
        bitmap.close(); // 删位图（内部转 HGDIOBJ 调 DeleteObject）
      }
    } finally {
      DeleteDC(memDc); // 删内存 DC
      ReleaseDC(null, screenDc); // 释放屏幕 DC
    }
  }

  /// 用 GetDIBits 把位图读成 BGRA 字节数组。
  Uint8List _readPixels(HDC memDc, HBITMAP bitmap) {
    // BITMAPINFO：描述位图格式的结构体，GetDIBits 需要它
    final bmi = calloc<BITMAPINFO>();
    try {
      // 填头信息：宽/高/每像素 32 位(BGRA)/BI_RGB 未压缩
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = _width;
      bmi.ref.bmiHeader.biHeight = -_height; // 负值 = 从上往下读（顺序正常）
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32; // 32 位 = 每像素 4 字节
      bmi.ref.bmiHeader.biCompression = BI_RGB; // 未压缩

      // 分配像素缓冲（宽 × 高 × 4 字节）
      final pixelSize = _width * _height * 4;
      final pixels = calloc<Uint8>(pixelSize);
      try {
        // 读像素到缓冲
        final lines =
            GetDIBits(memDc, bitmap, 0, _height, pixels, bmi, DIB_RGB_COLORS);
        if (lines == 0) {
          throw Exception('GetDIBits 失败');
        }
        return pixels.asTypedList(pixelSize); // 拷贝成 Uint8List（BGRA）
      } finally {
        calloc.free(pixels);
      }
    } finally {
      calloc.free(bmi);
    }
  }
}
