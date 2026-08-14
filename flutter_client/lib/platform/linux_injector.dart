import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'input_injector.dart';

/// X11 特殊键的 keysym 常量（来自 `&lt;X11/keysymdef.h&gt;`）。
const int _ksEscape = 0xFF1B;
const int _ksReturn = 0xFF0D;
const int _ksBackSpace = 0xFF08;
const int _ksTab = 0xFF09;
const int _ksDelete = 0xFFFF;
const int _ksInsert = 0xFF63;
const int _ksHome = 0xFF50;
const int _ksEnd = 0xFF57;
const int _ksPageUp = 0xFF55;
const int _ksPageDown = 0xFF56;
const int _ksLeft = 0xFF51;
const int _ksUp = 0xFF52;
const int _ksRight = 0xFF53;
const int _ksDown = 0xFF54;
const int _ksCapsLock = 0xFFE5;
const int _ksShiftL = 0xFFE1;
const int _ksControlL = 0xFFE3;
const int _ksAltL = 0xFFE9;
const int _ksSuperL = 0xFFEB; // Win 键
const int _ksNumLock = 0xFF7F;
const int _ksScrollLock = 0xFF14;
const int _ksPause = 0xFF13;
const int _ksPrint = 0xFF61;
const int _ksF1 = 0xFFBE; // F1..F12 依次 +0

/// 把 AWT KeyEvent.VK_* 码映射为 X11 keysym。
/// 协议里的 keyCode 来自鸿蒙/Java 端（AWT 语义），Windows 上可直接当 VK 用，
/// 但 X11 需要 keysym。字母/数字/标点（A-Z、0-9、空格等）AWT VK == ASCII == keysym，
/// 仅功能键（回车/方向/编辑/修饰键）需要专门映射。
///
/// 注意 VK 与 ASCII 有重叠：AWT VK_LEFT=0x25 同时是 ASCII '%'，
/// 所以【先查特殊键表】再回退可打印字符，方向键必须命中功能键分支。
///
/// 返回 0 表示无法映射（调用方应跳过该键）。
int awtVkToKeysym(int vk) {
  // 先查功能键：方向/编辑/修饰键等（与 ASCII 重叠的键以功能键优先）
  final special = _specialKeys[vk];
  if (special != null) return special;
  // 回退可打印字符（A-Z / 0-9 / 标点 / 空格）：AWT VK == ASCII == X11 keysym
  if (vk >= 0x20 && vk <= 0x7E) return vk;
  return 0;
}

/// AWT VK → X11 keysym 的特殊键映射表。
/// 键值来自 java.awt.event.KeyEvent 常量。
const Map<int, int> _specialKeys = {
  0x1B: _ksEscape, // VK_ESCAPE
  0x0D: _ksReturn, // VK_ENTER
  0x0A: _ksReturn, // VK_ENTER 变体
  0x08: _ksBackSpace, // VK_BACK_SPACE
  0x09: _ksTab, // VK_TAB
  0x7F: _ksDelete, // VK_DELETE=127
  0x9B: _ksInsert, // VK_INSERT=155
  0x24: _ksHome, // VK_HOME
  0x23: _ksEnd, // VK_END
  0x21: _ksPageUp, // VK_PAGE_UP
  0x22: _ksPageDown, // VK_PAGE_DOWN
  0x25: _ksLeft, // VK_LEFT
  0x26: _ksUp, // VK_UP
  0x27: _ksRight, // VK_RIGHT
  0x28: _ksDown, // VK_DOWN
  0x14: _ksCapsLock, // VK_CAPS_LOCK
  0x10: _ksShiftL, // VK_SHIFT
  0x11: _ksControlL, // VK_CONTROL
  0x12: _ksAltL, // VK_ALT
  0x020C: _ksSuperL, // VK_WINDOWS=0x020C
  0x01D8: _ksSuperL, // VK_META（mac 端可能发这个）
  0x90: _ksNumLock, // VK_NUM_LOCK
  0x91: _ksScrollLock, // VK_SCROLL_LOCK
  0x13: _ksPause, // VK_PAUSE
  0x9A: _ksPrint, // VK_PRINTSCREEN
  0x6C: 0xFFAF, // VK_SEPARATOR=108（小键盘分隔符）
};

/// F1..F12（AWT VK 112..123 → keysym 0xFFBE..0xFFC9）。
int awtFunctionKeyToKeysym(int vk) {
  if (vk >= 112 && vk <= 123) return _ksF1 + (vk - 112);
  return 0;
}

/// Linux 输入注入：XTest 扩展（libXtst）模拟全局鼠标/键盘。
/// 对应 Windows 的 SendInput。仅 X11 环境有效（XTest 作用于 X server）。
class LinuxInjector implements InputInjector {
  late final Pointer<Void> _display;
  late final int _screen;
  late final bool _ready;

  // libX11（XKeysymToKeycode 需要）+ libXtst（XTestFake*）
  static final DynamicLibrary _x11 = DynamicLibrary.open('libX11.so.6');
  static final DynamicLibrary _xtst = DynamicLibrary.open('libXtst.so.6');

  static final _openDisplay = _x11.lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>),
      Pointer<Void> Function(Pointer<Utf8>)>('XOpenDisplay');
  // DefaultScreen 是 X11 宏（((dpy)->default_screen)），不是导出的符号，
  // 必须用真实的导出函数 XDefaultScreenOfDisplay + XScreenNumberOfScreen。
  static final _defaultScreenOfDisplay = _x11.lookupFunction<
      Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)>(
          'XDefaultScreenOfDisplay'); // Screen* XDefaultScreenOfDisplay(Display*)
  static final _screenNumberOfScreen = _x11.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>(
          'XScreenNumberOfScreen'); // int XScreenNumberOfScreen(Screen*)
  static final _closeDisplay = _x11.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('XCloseDisplay');
  static final _keysymToKeycode = _x11.lookupFunction<
      Uint8 Function(Pointer<Void>, Uint64),
      int Function(Pointer<Void>, int)>('XKeysymToKeycode');

  static final _fakeMotion = _xtst.lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Int32, Int32, Uint64),
      int Function(Pointer<Void>, int, int, int, int)>('XTestFakeMotionEvent');
  static final _fakeButton = _xtst.lookupFunction<
      Int32 Function(Pointer<Void>, Uint32, Int32, Uint64),
      int Function(Pointer<Void>, int, int, int)>('XTestFakeButtonEvent');
  static final _fakeKey = _xtst.lookupFunction<
      Int32 Function(Pointer<Void>, Uint32, Int32, Uint64),
      int Function(Pointer<Void>, int, int, int)>('XTestFakeKeyEvent');

  LinuxInjector() {
    _display = _openDisplay(nullptr);
    if (_display == nullptr) {
      _ready = false;
      _screen = 0;
      return; // 无 X 环境（如 Wayland 原生会话），注入直接空转
    }
    _ready = true;
    _screen = _screenNumberOfScreen(_defaultScreenOfDisplay(_display));
  }

  static const int _delayUs = 0; // 事件间不等待（连续注入）

  @override
  void moveMouse(int x, int y) {
    if (!_ready) return;
    _fakeMotion(_display, _screen, x, y, _delayUs);
  }

  @override
  void mouseDown(int button) {
    if (!_ready) return;
    // X11 按钮号：1=左 2=中 3=右
    final b = switch (button) {
      1 => 1,
      2 => 2,
      3 => 3,
      _ => 1,
    };
    _fakeButton(_display, b, 1, _delayUs); // 1=press
  }

  @override
  void mouseUp(int button) {
    if (!_ready) return;
    final b = switch (button) {
      1 => 1,
      2 => 2,
      3 => 3,
      _ => 1,
    };
    _fakeButton(_display, b, 0, _delayUs); // 0=release
  }

  @override
  void mouseWheel(int rotations) {
    if (!_ready) return;
    // X11 滚轮：按钮 4=上 5=下，多格就多次 press+release
    final steps = rotations.abs();
    final button = rotations >= 0 ? 4 : 5;
    for (var i = 0; i < steps; i++) {
      _fakeButton(_display, button, 1, _delayUs);
      _fakeButton(_display, button, 0, _delayUs);
    }
  }

  @override
  void keyDown(int keyCode) {
    if (!_ready) return;
    final keycode = _toKeycode(keyCode);
    if (keycode != 0) _fakeKey(_display, keycode, 1, _delayUs);
  }

  @override
  void keyUp(int keyCode) {
    if (!_ready) return;
    final keycode = _toKeycode(keyCode);
    if (keycode != 0) _fakeKey(_display, keycode, 0, _delayUs);
  }

  /// AWT VK → X11 keycode（keysym → XKeysymToKeycode），0=无法映射。
  int _toKeycode(int vk) {
    var keysym = awtVkToKeysym(vk);
    if (keysym == 0) keysym = awtFunctionKeyToKeysym(vk);
    if (keysym == 0) return 0;
    return _keysymToKeycode(_display, keysym); // 0 表示键盘上没有该键
  }

  /// 释放 X display 连接。
  @override
  void dispose() {
    if (_ready && _display != nullptr) _closeDisplay(_display);
  }
}