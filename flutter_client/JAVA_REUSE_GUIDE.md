# Flutter客户端 - 复用Java客户端的指南

## 概述

虽然Flutter客户端和Java客户端使用不同的编程语言和UI框架，但可以充分复用Java客户端的业务逻辑和通信协议。本文档说明如何有效地进行代码复用。

## 1. 什么可以复用？

### ✅ 可以复用的部分

| 类别 | Java实现 | Flutter实现 | 复用方式 |
|:--|:--|:--|:--|
| **通信协议** | CmdType枚举 | API端点映射 | 协议转换 |
| **数据结构** | 各种Bean类 | Dart模型类 | JSON序列化/反序列化 |
| **业务逻辑** | RemoteClient业务 | 控制器层逻辑 | 算法和流程参考 |
| **常量定义** | Constants.java | app_constants.dart | 直接复用值 |
| **错误处理** | 异常类型 | 错误枚举 | 错误码映射 |

### ❌ 不能复用的部分

| 类别 | 原因 |
|:--|:--|
| **UI界面** | Swing vs Flutter, 完全不同的框架 |
| **JNI代码** | Java特定, 不适用于Dart |
| **Netty实现** | Netty框架vs Dio/WebSocket |
| **AWT操作** | 桌面特定, 移动设备不支持 |
| **文件路径** | Windows vs Android/iOS/Web路径不同 |

---

## 2. 数据模型映射

### 2.1 鼠标控制 (MouseEvent)

**Java源代码**:
```java
// common/command/CmdMouseControl.java
public CmdMouseControl(int x, int y, ButtonState buttonState, int button) {
    this(x, y, (buttonState == ButtonState.PRESSED ? PRESSED : RELEASED) | button, 0);
}

// 使用示例
CmdMouseControl cmd = new CmdMouseControl(100, 200, 
    CmdMouseControl.ButtonState.PRESSED, 
    CmdMouseControl.BUTTON1);
```

**Flutter复用代码**:
```dart
// lib/models/models.dart
MouseEvent mouseEvent = MouseEvent(
  x: 100,
  y: 200,
  button: 'left',
  action: 'down',
);

// 转换为Java协议格式
Map<String, dynamic> javaFormat = mouseEvent.toJavaProtocol();
// {x: 100, y: 200, info: 5, rotations: 0}
```

### 2.2 键盘控制 (KeyboardEvent)

**Java源代码**:
```java
// common/command/CmdKeyControl.java
public CmdKeyControl(KeyState buttonState, int keyCode, char keyChar) {
    this(buttonState == KeyState.PRESSED ? PRESSED : RELEASED, keyCode, keyChar);
}

// 使用示例
CmdKeyControl cmd = new CmdKeyControl(
    CmdKeyControl.KeyState.PRESSED, 
    KeyEvent.VK_A, 
    'A');
```

**Flutter复用代码**:
```dart
// lib/models/models.dart
KeyboardEvent keyEvent = KeyboardEvent(
  keyCode: 65,  // 'A'键
  action: 'down',
);

// 转换为Java协议格式
Map<String, dynamic> javaFormat = keyEvent.toJavaProtocol();
// {info: 1, keyCode: 65, keyChar: ''}
```

### 2.3 屏幕捕获响应 (FrameData)

**Java源代码**:
```java
// common/remote/bean/RobotCaptureResponse.java
public class RobotCaptureResponse implements Serializable {
    private byte[] screenBytes;
    private Long id;
}

// 服务器响应示例
RobotCaptureResponse response = new RobotCaptureResponse(
    compressedScreenData, 
    frameId);
```

**Flutter复用代码**:
```dart
// lib/models/models.dart
FrameData frameData = FrameData.fromJavaResponse(
  {
    'screenBytes': compressedScreenData,
    'id': frameId,
  },
  screenWidth: 1920,
  screenHeight: 1080,
);
```

---

## 3. 常量复用

### 3.1 心跳配置

**Java Constants.java**:
```java
public static final int HEARTBEAT_DURATION_SECONDS = 3;
public static final int CLIENT_SESSION_TIMEOUT_MILLS = 1000 * 15;
```

**Flutter app_constants.dart**:
```dart
// 从Java定义复用
const Duration HEARTBEAT_INTERVAL = Duration(seconds: 3);
const Duration SESSION_TIMEOUT = Duration(milliseconds: 15000);
```

### 3.2 按钮码

**Java CmdMouseControl**:
```java
public static final int BUTTON1 = 1 << 2;     // 左键
public static final int BUTTON2 = 1 << 3;     // 中键
public static final int BUTTON3 = 1 << 4;     // 右键
```

**Flutter MouseEvent**:
```dart
static const int BUTTON1 = 1 << 2;    // 左键
static const int BUTTON2 = 1 << 3;    // 中键
static const int BUTTON3 = 1 << 4;    // 右键
```

---

## 4. 业务逻辑复用

### 4.1 连接管理

**Java RemoteClient**:
```java
public class RemoteClient extends RemoteFrame {
    private boolean connectStatus;
    
    public void openRemoteScreen(String deviceCode, String password) {
        controller.openSession(deviceCode, password);
    }
    
    public void closeRemoteScreen() {
        controller.closeSession();
    }
    
    public boolean isConnect() {
        return connectStatus;
    }
}
```

**Flutter ConnectionService**:
```dart
// lib/services/connection_service.dart
class ConnectionService {
  final isConnected = false.obs;
  final isConnecting = false.obs;
  
  Future<void> openRemoteScreen(String deviceCode, String password) async {
    // 复用Java的业务逻辑
    // 1. 建立连接
    // 2. 发送开屏幕请求
    // 3. 更新连接状态
  }
  
  Future<void> closeRemoteScreen() async {
    // 复用Java的关闭逻辑
  }
}
```

### 4.2 事件处理

**Java RemoteController**:
```java
public class RemoteController {
    public void fireCmd(Cmd cmd) {
        // 发送命令到服务器
    }
}

// 使用示例
RemoteController controller = new RemoteController();
controller.fireCmd(new CmdMouseControl(100, 200, 
    CmdMouseControl.ButtonState.PRESSED, 
    CmdMouseControl.BUTTON1));
```

**Flutter RemoteControlController**:
```dart
// lib/controllers/remote_control_controller.dart
class RemoteControlController extends GetxController {
  Future<void> handleMouseEvent(MouseEvent event) async {
    try {
      // 转换为Java格式并发送
      final javaFormat = event.toJavaProtocol();
      await connectionService.sendMouseEvent(javaFormat);
    } catch (e) {
      // 错误处理
    }
  }
}
```

### 4.3 重连逻辑

**Java RemoteClient**:
```java
// Netty自动处理重连
// SimpleChannelInboundHandler 处理连接状态变化
```

**Flutter ConnectionService**:
```dart
// lib/services/connection_service.dart - 已实现
class ConnectionService {
  Future<void> _reconnect() async {
    int attempts = 0;
    while (attempts < maxReconnectAttempts) {
      try {
        await initializeConnection();
        return;
      } catch (e) {
        attempts++;
        await Future.delayed(Duration(seconds: 5 * attempts));
      }
    }
  }
}
```

---

## 5. 协议集成实例

### 5.1 完整的鼠标点击流程

**Java方式**:
```java
// 1. 创建命令
CmdMouseControl pressCmd = new CmdMouseControl(500, 300,
    CmdMouseControl.ButtonState.PRESSED,
    CmdMouseControl.BUTTON1);

// 2. 发送给服务器
controller.fireCmd(pressCmd);

// 3. 创建释放命令
CmdMouseControl releaseCmd = new CmdMouseControl(500, 300,
    CmdMouseControl.ButtonState.RELEASED,
    CmdMouseControl.BUTTON1);

// 4. 发送给服务器
controller.fireCmd(releaseCmd);
```

**Flutter方式** (复用Java逻辑):
```dart
// lib/controllers/remote_control_controller.dart
Future<void> clickMouse(int x, int y, String button) async {
  try {
    // 1. 创建按下事件
    final pressEvent = MouseEvent(
      x: x,
      y: y,
      button: button,
      action: 'down',
    );
    
    // 2. 发送给服务器 (转换为Java格式)
    await connectionService.sendMouseEvent(pressEvent.toJavaProtocol());
    
    // 3. 等待50ms (模拟真实点击时间)
    await Future.delayed(Duration(milliseconds: 50));
    
    // 4. 创建释放事件
    final releaseEvent = MouseEvent(
      x: x,
      y: y,
      button: button,
      action: 'up',
    );
    
    // 5. 发送给服务器
    await connectionService.sendMouseEvent(releaseEvent.toJavaProtocol());
  } catch (e) {
    showError('鼠标点击失败: $e');
  }
}
```

### 5.2 完整的屏幕刷新流程

**Java方式**:
```java
// RemoteScreen 监听屏幕更新
RemoteScreen remoteScreen = new RemoteScreen();
remoteScreen.addListener(new RemoteScreenListener() {
    @Override
    public void screenUpdated(RobotCaptureResponse response) {
        // 处理屏幕数据
        byte[] screenData = response.getScreenBytes();
        // 解码并显示
    }
});
```

**Flutter方式** (复用Java逻辑):
```dart
// lib/services/connection_service.dart
void _startFrameCapture() {
  frameStream.listen((FrameData frame) {
    // 1. 接收屏幕数据
    final imageBytes = frame.imageData;
    
    // 2. 解码 (如果是压缩格式)
    if (frame.compressionType == 'gzip') {
      final decoded = gzip.decode(imageBytes);
      // 显示图像
    }
    
    // 3. 更新UI
    currentFrame.value = frame;
  });
}
```

---

## 6. 错误码映射

### Java错误

**Java RemoteClient**:
```java
public class RemoteException extends Exception {
    // 自定义异常
}
```

**Flutter映射**:
```dart
// lib/models/models.dart
enum ErrorCode {
  connectionFailed(1001),
  authenticationFailed(1002),
  screenCaptureFailed(1003),
  mouseEventFailed(1004),
  keyboardEventFailed(1005),
  sessionTimeout(1006),
  networkError(1007),
  unknown(9999);

  final int code;
  const ErrorCode(this.code);
}

// 使用
void _handleError(dynamic error) {
  if (error.code == 1002) {
    showError('认证失败');
  }
}
```

---

## 7. 配置参数复用

### Java client配置

**RemoteClient构造函数参数**:
```java
public RemoteClient(
    String serverIp,      // 服务器IP
    Integer serverPort,   // 服务器端口
    String clipboardServer, // 剪贴板服务器
    int robotPort         // 机器人控制端口
)
```

**Flutter配置**:
```dart
// lib/models/models.dart
class ConnectionConfig {
  final String serverIp;
  final int serverPort;
  final String clipboardServer;
  final int robotPort;
  // 完全对应Java参数
}

// lib/config/app_config.dart - 默认值
const serverPort = 8080;
const robotPort = 8888;
```

---

## 8. 实现检查清单

### 核心功能复用

- [x] **鼠标控制** - 按照Java CmdMouseControl实现
  - [x] 坐标计算
  - [x] 按键状态编码
  - [x] 滚轮支持
  
- [x] **键盘控制** - 按照Java CmdKeyControl实现
  - [x] 键码转换
  - [x] 按键状态编码
  
- [x] **屏幕捕获** - 按照Java RobotCaptureResponse实现
  - [x] 帧ID管理
  - [x] 数据解析
  
- [x] **连接管理** - 参考Java RemoteClient
  - [x] 连接状态跟踪
  - [x] 自动重连
  - [x] 会话超时

### 协议集成

- [x] 心跳(Ping/Pong)
- [x] 屏幕打开/关闭
- [x] 鼠标事件
- [x] 键盘事件
- [ ] 剪贴板同步
- [ ] 文件传输

---

## 9. 常见问题解答

### Q1: 如何测试协议兼容性？

**方案**:
1. 启动Java服务器
2. 运行Flutter客户端
3. 在日志中验证命令格式

```dart
// lib/services/api_service.dart
print('发送命令: ${event.toJavaProtocol()}');
```

### Q2: 性能考虑

| 操作 | Java | Flutter | 优化 |
|:--|:--|:--|:--|
| 鼠标事件 | 帧率60Hz | 目标60Hz | 使用StreamController缓冲 |
| 屏幕更新 | 30fps | 目标30fps | 实现帧跳跃 |
| 心跳 | 3秒 | 3秒 | 保持一致 |

### Q3: 可以同时运行Java和Flutter客户端吗？

**答**: 取决于服务器实现。通常：
- 一台设备同时只能有一个CONTROLLER
- 多个客户端可以连接，但只有一个能控制
- 建议检查服务器的会话管理实现

### Q4: 如何处理版本兼容性？

**建议**:
```dart
// lib/constants/app_constants.dart
const PROTOCOL_VERSION = '1.0';
const MIN_SERVER_VERSION = '1.0';

// 握手时验证
Future<void> initializeConnection() async {
  final serverVersion = await getServerVersion();
  if (versionCompare(serverVersion, MIN_SERVER_VERSION) < 0) {
    throw Exception('服务器版本过旧');
  }
}
```

---

## 10. 将来改进建议

### 短期 (1-2周)

1. **完整的剪贴板支持** - 复用Java ClipboardTransfer逻辑
2. **性能基准测试** - 对标Java客户端
3. **错误恢复** - 更完善的异常处理

### 中期 (1-2月)

1. **文件传输** - 复用Java FileTransfer逻辑
2. **音频支持** - 参考Java音频实现
3. **自动更新** - 类似Java的自动更新机制

### 长期 (3个月+)

1. **插件系统** - 支持扩展功能
2. **本地录屏** - 支持会话记录
3. **性能优化** - 硬件加速

---

## 11. 参考文件位置

### Java Client 关键代码

```
/client/src/main/java/io/github/springstudent/dekstop/
├── client/
│   ├── RemoteClient.java ✓ 主要业务逻辑
│   ├── core/
│   │   ├── RemoteScreen.java ✓
│   │   ├── RemoteController.java ✓
│   │   └── RemoteControlled.java ✓
│   └── netty/RemoteChannelHandler.java ✓
└── common/
    ├── command/ ✓ 协议定义
    │   ├── CmdMouseControl.java
    │   ├── CmdKeyControl.java
    │   └── CmdType.java
    └── remote/bean/ ✓ 数据模型
        ├── RobotMouseControl.java
        ├── RobotKeyControl.java
        └── RobotCaptureResponse.java
```

### Flutter Client 对应代码

```
/flutter_client/lib/
├── models/models.dart ✓ 数据模型 + 转换方法
├── services/
│   ├── api_service.dart ✓ API通信
│   └── connection_service.dart ✓ 连接管理
├── controllers/
│   ├── remote_control_controller.dart ✓ 事件处理
│   └── login_controller.dart ✓ 认证
└── constants/app_constants.dart ✓ 常量定义
```

---

## 12. 总结

虽然Flutter客户端和Java客户端使用不同的技术栈，但通过以下方式可以有效地复用Java的设计和实现：

1. **协议复用** ✅ - 使用相同的通信协议
2. **数据模型复用** ✅ - 转换为JSON格式
3. **业务逻辑参考** ✅ - 参考实现细节
4. **常量统一** ✅ - 使用相同的常量值
5. **错误处理** ✅ - 映射错误码

这样既保证了两个客户端的兼容性，又利用了Flutter在移动/跨平台方面的优势。

---

**最后更新**: 2024年  
**维护者**: Flutter客户端开发团队
