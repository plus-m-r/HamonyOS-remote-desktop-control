import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'input_injector.dart';

/// Windows 输入注入：用 SendInput 模拟鼠标/键盘。
/// 对应 Java 端 java.awt.Robot（RemoteControlled.handleMessage）。
class WindowsInjector implements InputInjector {
  static final _sendInput = _user32
      .lookupFunction<Uint32 Function(Uint32, Pointer<INPUT>, Int32),
          int Function(int, Pointer<INPUT>, int)>('SendInput');

  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

  @override
  void moveMouse(int x, int y) {
    // 移动鼠标：MOUSEEVENTF_ABSOLUTE 时 dx/dy 是 0~65535 的归一化坐标，
    // 不是屏幕像素！必须换算：归一化 = 像素 / 屏幕尺寸 * 65535。
    final screenW = GetSystemMetrics(SM_CXSCREEN);
    final screenH = GetSystemMetrics(SM_CYSCREEN);
    final nx = screenW == 0 ? 0 : x * 65535 ~/ screenW;
    final ny = screenH == 0 ? 0 : y * 65535 ~/ screenH;
    _sendMouse(nx, ny, MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE, 0);
  }

  @override
  void mouseDown(int button) {
    // 按下：左=LEFTDOWN(2) 中=MIDDLEDOWN(32) 右=RIGHTDOWN(8)
    final flag = switch (button) {
      1 => MOUSEEVENTF_LEFTDOWN,
      2 => MOUSEEVENTF_MIDDLEDOWN,
      3 => MOUSEEVENTF_RIGHTDOWN,
      _ => MOUSEEVENTF_LEFTDOWN,
    };
    _sendMouse(0, 0, flag, 0);
  }

  @override
  void mouseUp(int button) {
    // 释放：左=LEFTUP(4) 中=MIDDLEUP(64) 右=RIGHTUP(16)
    final flag = switch (button) {
      1 => MOUSEEVENTF_LEFTUP,
      2 => MOUSEEVENTF_MIDDLEUP,
      3 => MOUSEEVENTF_RIGHTUP,
      _ => MOUSEEVENTF_LEFTUP,
    };
    _sendMouse(0, 0, flag, 0);
  }

  @override
  void mouseWheel(int rotations) {
    // 滚轮：mouseData = 滚动格数（正=上），WHEEL 标志
    _sendMouse(0, 0, MOUSEEVENTF_WHEEL, rotations * 120);
  }

  @override
  void keyDown(int keyCode) {
    _sendKey(keyCode, 0); // 按下：flags=0
  }

  @override
  void keyUp(int keyCode) {
    _sendKey(keyCode, KEYEVENTF_KEYUP); // 释放：KEYUP(2)
  }

  /// SendInput 无需持有型资源，dispose 只保留接口一致性。
  @override
  void dispose() {}

  /// 发一个鼠标事件（SendInput，type=INPUT_MOUSE）。
  void _sendMouse(int x, int y, int flags, int mouseData) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE; // 类型 = 鼠标
      input.ref.Anonymous.mi.dx = x;
      input.ref.Anonymous.mi.dy = y;
      input.ref.Anonymous.mi.mouseData = mouseData;
      input.ref.Anonymous.mi.dwFlags = MOUSE_EVENT_FLAGS(flags); // int → 强类型枚举
      _sendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }

  /// 发一个键盘事件（SendInput，type=INPUT_KEYBOARD）。
  void _sendKey(int keyCode, int flags) {
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_KEYBOARD; // 类型 = 键盘
      input.ref.Anonymous.ki.wVk = VIRTUAL_KEY(keyCode); // 虚拟键码
      input.ref.Anonymous.ki.dwFlags = KEYBD_EVENT_FLAGS(flags);
      _sendInput(1, input, sizeOf<INPUT>());
    } finally {
      calloc.free(input);
    }
  }
}
