import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'screen_capturer.dart';

/// X11 常量（来自 `&lt;X11/X.h&gt;`）。
const int _zPixmap = 2; // 彩色像素格式（XYPixmap=1 单色）
const int _allPlanes = 0xFFFFFFFF; // 抓所有位平面

/// [XImage] 结构体（来自 `&lt;X11/Xutil.h&gt;`），只取用到的字段。
/// 注意：字段顺序/类型必须与 C 结构一致，否则指针偏移错乱。
final class _XImage extends Struct {
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Int32()
  external int xoffset;
  @Int32()
  external int format;
  external Pointer<Uint8> data; // 像素数据（char*）
  @Int32()
  external int byteOrder; // 0=LSBFirst 1=MSBFirst
  @Int32()
  external int bitmapBitOrder;
  @Int32()
  external int bitmapBitUnit; // 8/16/32，扫描行量化
  @Int32()
  external int bitmapBitPad; // 扫描行对齐（8/16/32）
  @Int32()
  external int depth; // 颜色深度（如 24）
  @Int32()
  external int bytesPerLine; // 每行字节数（含对齐 padding）
  @Int32()
  external int bitsPerPixel; // 24 或 32
  @Uint64()
  external int redMask;
  @Uint64()
  external int greenMask;
  @Uint64()
  external int blueMask;
  external Pointer<Uint8> obdata; // 连带的原始分配（obdata_free 用）
}

/// Linux 抓屏：X11 XGetImage 读取根窗口像素 → BGRA。
///
/// 与 Windows 的 BitBlt 对齐：返回 4 字节/像素 BGRA。
/// XGetImage 输出的是 X 服务器原生的 24/32 位 XImage（BGR(A) 居多），
/// 需要逐像素按 mask 转换成 BGRA 格式。
///
/// ⚠️ 限制：仅 X11 会话可用（XWayland 只能抓 X11 客户端的窗口，
/// 抓不到 Wayland 原生桌面）。Wayland 原生会话需 xdg-desktop-portal，后置。
class LinuxCapturer implements ScreenCapturer {
  late final int _width;
  late final int _height;
  late final Pointer<Void> _display;
  late final int _screen;
  late final int _rootWindow;

  // libX11 函数
  static final DynamicLibrary _lib = DynamicLibrary.open('libX11.so.6');

  static final _openDisplay = _lib.lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>),
      Pointer<Void> Function(
          Pointer<Utf8>)>('XOpenDisplay'); // Display* XOpenDisplay(const char*)
  // DefaultScreen 是 X11 宏（((dpy)->default_screen)），不是导出的符号，
  // 必须用真实的导出函数 XDefaultScreenOfDisplay + XScreenNumberOfScreen。
  static final _defaultScreenOfDisplay = _lib.lookupFunction<
      Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)>(
          'XDefaultScreenOfDisplay'); // Screen* XDefaultScreenOfDisplay(Display*)
  static final _screenNumberOfScreen = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>(
          'XScreenNumberOfScreen'); // int XScreenNumberOfScreen(Screen*)
  static final _xRootWindow = _lib.lookupFunction<
      Uint64 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)>('XRootWindow'); // Window XRootWindow(Display*,int)
  static final _displayWidth = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)>(
          'XDisplayWidth'); // int XDisplayWidth(Display*,int)
  static final _displayHeight = _lib.lookupFunction<
      Int32 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)>(
          'XDisplayHeight'); // int XDisplayHeight(Display*,int)
  static final _getImage = _lib.lookupFunction<
      Pointer<_XImage> Function(
          Pointer<Void>, Uint64, Int32, Int32, Uint32, Uint32, Uint64, Int32),
      Pointer<_XImage> Function(
          Pointer<Void>, int, int, int, int, int, int,
          int)>('XGetImage'); // XImage* XGetImage(...)
  static final _destroyImage = _lib.lookupFunction<
      Int32 Function(Pointer<_XImage>),
      int Function(Pointer<_XImage>)>('XDestroyImage');
  static final _closeDisplay = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('XCloseDisplay');

  LinuxCapturer() {
    // 打开默认 display（$DISPLAY）
    _display = _openDisplay(nullptr);
    if (_display == nullptr) {
      throw StateError('XOpenDisplay 失败：无法连接 X 服务器。'
          '请检查 DISPLAY 环境变量（Wayland 原生会话不支持，需 X11/XWayland）。');
    }
    _screen = _screenNumberOfScreen(_defaultScreenOfDisplay(_display));
    _rootWindow = _xRootWindow(_display, _screen);
    _width = _displayWidth(_display, _screen);
    _height = _displayHeight(_display, _screen);
  }

  @override
  int get width => _width;

  @override
  int get height => _height;

  @override
  Future<Uint8List> capture() async {
    // 抓整屏到 XImage（ZPixmap 彩色）
    final image = _getImage(
        _display, _rootWindow, 0, 0, _width, _height, _allPlanes, _zPixmap);
    if (image == nullptr) {
      throw StateError('XGetImage 失败');
    }
    try {
      final width = image.ref.width;
      final height = image.ref.height;
      final bytesPerLine = image.ref.bytesPerLine;
      final bitsPerPixel = image.ref.bitsPerPixel;
      final lsbFirst = image.ref.byteOrder == 0;
      final redMask = image.ref.redMask;
      final greenMask = image.ref.greenMask;
      final blueMask = image.ref.blueMask;

      // 拷贝原生像素（data 指向 XImage 内部缓冲，销毁后失效）
      final size = bytesPerLine * height;
      final raw = image.ref.data.asTypedList(size).sublist(0);

      return xImageToBgra(
        raw: raw,
        width: width,
        height: height,
        bytesPerLine: bytesPerLine,
        bitsPerPixel: bitsPerPixel,
        lsbFirst: lsbFirst,
        redMask: redMask,
        greenMask: greenMask,
        blueMask: blueMask,
      );
    } finally {
      _destroyImage(image); // 释放 XImage（含内部像素缓冲）
    }
  }

  /// 释放 X display（页面销毁/isolate 退出时调用）。
  @override
  void dispose() {
    _closeDisplay(_display);
  }
}

/// 通用 XImage → BGRA 转换（纯函数，任何平台都能单测）。
///
/// X11 的像素排列随服务器字节序/mask 变化，这里用 mask 提取 RGB 分量，
/// 保证任何端序/位深（24/32bpp）都得到协议要求的 BGRA 4 字节/像素。
/// - raw：XImage.data 的拷贝，按 bytesPerLine 布局
/// - lsbFirst：byte_order==0 是小端（常见 x86）
Uint8List xImageToBgra({
  required Uint8List raw,
  required int width,
  required int height,
  required int bytesPerLine,
  required int bitsPerPixel,
  required bool lsbFirst,
  required int redMask,
  required int greenMask,
  required int blueMask,
}) {
  final out = Uint8List(width * height * 4);
  final bytesPerPixel = bitsPerPixel ~/ 8;
  final rShift = redMask == 0 ? 0 : _trailingZeros(redMask);
  final gShift = greenMask == 0 ? 0 : _trailingZeros(greenMask);
  final bShift = blueMask == 0 ? 0 : _trailingZeros(blueMask);

  var di = 0;
  for (var y = 0; y < height; y++) {
    final rowOff = y * bytesPerLine;
    for (var x = 0; x < width; x++) {
      final p = _readPixel(raw, rowOff + x * bytesPerPixel, bytesPerPixel, lsbFirst);
      out[di++] = ((p & blueMask) >> bShift) & 0xFF;
      out[di++] = ((p & greenMask) >> gShift) & 0xFF;
      out[di++] = ((p & redMask) >> rShift) & 0xFF;
      out[di++] = 0xFF; // 固定不透明
    }
  }
  return out;
}

/// 在 raw[offset..offset+n] 读一个像素值（按端序）。
int _readPixel(Uint8List raw, int offset, int bytes, bool lsbFirst) {
  if (lsbFirst) {
    var v = 0;
    for (var i = bytes - 1; i >= 0; i--) {
      v = (v << 8) | raw[offset + i];
    }
    return v;
  } else {
    var v = 0;
    for (var i = 0; i < bytes; i++) {
      v = (v << 8) | raw[offset + i];
    }
    return v;
  }
}

/// 计算 mask 末位连续 0 的个数（即最低置位位的位置）。
int _trailingZeros(int mask) {
  var n = 0;
  while (mask != 0 && (mask & 1) == 0) {
    mask >>= 1;
    n++;
  }
  return n;
}