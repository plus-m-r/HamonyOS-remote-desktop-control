import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'screen_capturer.dart';

/// Windows 抓屏：用 GDI 的 BitBlt 把屏幕像素复制到内存，再读出 BGRA 字节。
/// 对应 Java 端 RobotCaptureFactory + ScreenUtilities.captureColors()。
///
/// 性能优化：屏幕 DC/内存 DC/位图/像素缓冲在【构造时创建一次】并复用，
/// capture() 每帧只做 BitBlt（复制像素）+ GetDIBits（读像素）——
/// 避免每帧创建/销毁 GDI 对象（30ms/帧 = 每秒 33 次），抓屏耗时显著下降。
class WindowsCapturer implements ScreenCapturer {
  late final int _width;
  late final int _height;

  // 复用的 GDI 对象（构造创建，dispose 释放）
  late final HDC _screenDc; // 屏幕 DC
  late final HDC _memDc; // 内存 DC
  late final HBITMAP _bitmap; // 内存位图（与屏幕同尺寸）
  late final Pointer<BITMAPINFO> _bmi; // 位图信息（GetDIBits 用）
  late final Pointer<Uint8> _pixelBuffer; // 像素缓冲（宽×高×4，复用）

  WindowsCapturer() {
    // 初始化：拿主屏幕尺寸
    final probe = GetDC(null);
    _width = GetDeviceCaps(probe, HORZRES);
    _height = GetDeviceCaps(probe, VERTRES);
    ReleaseDC(null, probe);

    // 创建复用的 GDI 对象（一次）
    _screenDc = GetDC(null);
    _memDc = CreateCompatibleDC(_screenDc);
    _bitmap = CreateCompatibleBitmap(_screenDc, _width, _height);
    SelectObject(_memDc, HGDIOBJ(_bitmap));

    // 准备位图信息 + 像素缓冲
    _bmi = calloc<BITMAPINFO>();
    _bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    _bmi.ref.bmiHeader.biWidth = _width;
    _bmi.ref.bmiHeader.biHeight = -_height; // 负值 = 从上往下读
    _bmi.ref.bmiHeader.biPlanes = 1;
    _bmi.ref.bmiHeader.biBitCount = 32; // BGRA
    _bmi.ref.bmiHeader.biCompression = BI_RGB;
    _pixelBuffer = calloc<Uint8>(_width * _height * 4);
  }

  @override
  int get width => _width;

  @override
  int get height => _height;

  @override
  Future<Uint8List> capture() async {
    // BitBlt：屏幕 → 内存位图（复用的对象，每帧只做这一次拷贝）
    final result =
        BitBlt(_memDc, 0, 0, _width, _height, _screenDc, 0, 0, SRCCOPY);
    if (!result.value) {
      throw Exception('BitBlt 失败，错误码: ${result.error}');
    }

    // GetDIBits：位图 → 像素缓冲（复用，不每帧分配）
    final lines =
        GetDIBits(_memDc, _bitmap, 0, _height, _pixelBuffer, _bmi, DIB_RGB_COLORS);
    if (lines == 0) {
      throw Exception('GetDIBits 失败');
    }

    // 必须拷贝：asTypedList 返回视图（指向原生内存），
    // 复用缓冲下次会被覆盖；sublist(0) 复制成独立 Uint8List
    final pixelSize = _width * _height * 4;
    return _pixelBuffer.asTypedList(pixelSize).sublist(0);
  }

  /// 释放复用的 GDI 对象（页面销毁时调用）。
  void dispose() {
    calloc.free(_pixelBuffer);
    calloc.free(_bmi);
    DeleteObject(HGDIOBJ(_bitmap)); // HBITMAP → HGDIOBJ 转换
    DeleteDC(_memDc);
    ReleaseDC(null, _screenDc);
  }
}
