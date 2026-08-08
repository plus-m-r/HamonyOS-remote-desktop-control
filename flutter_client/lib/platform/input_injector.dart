/// 输入注入器接口：每个平台一份实现。
/// 对照 Java 端 RemoteControlled.handleMessage（CmdMouseControl/CmdKeyControl 执行）。
abstract class InputInjector {
  /// 移动鼠标到屏幕坐标 (x, y)。
  void moveMouse(int x, int y);

  /// 按下鼠标按键。button: 1=左 2=中 3=右。
  void mouseDown(int button);

  /// 释放鼠标按键。button: 1=左 2=中 3=右。
  void mouseUp(int button);

  /// 滚轮滚动。rotations 为滚动格数（正=上 负=下）。
  void mouseWheel(int rotations);

  /// 按下键盘按键。keyCode 为虚拟键码（VK_*）。
  void keyDown(int keyCode);

  /// 释放键盘按键。keyCode 为虚拟键码（VK_*）。
  void keyUp(int keyCode);
}
