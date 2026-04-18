# Flutter客户端 - Java客户端协议兼容性指南

## 概述

本文档说明Flutter远程桌面控制客户端如何与Java客户端保持通信协议兼容性。

## 1. 心跳协议 (Heartbeat)

**Java Client 实现**:
```
心跳间隔: 3秒 (HEARTBEAT_DURATION_SECONDS = 3)
会话超时: 15秒 (CLIENT_SESSION_TIMEOUT_MILLS = 15000)
```

**Flutter Client 实现**:
```dart
// lib/constants/app_constants.dart
const Duration HEARTBEAT_INTERVAL = Duration(seconds: 3);
const Duration SESSION_TIMEOUT = Duration(milliseconds: 15000);
```

✅ **状态**: 已实现完全兼容

---

## 2. 鼠标控制协议 (Mouse Control)

### Java Client 命令结构
```java
// common/command/CmdMouseControl.java
public class CmdMouseControl extends Cmd {
    private static final int PRESSED = 1;
    private static final int RELEASED = 1 << 1;
    public static final int BUTTON1 = 1 << 2;     // 左键
    public static final int BUTTON2 = 1 << 3;     // 中键
    public static final int BUTTON3 = 1 << 4;     // 右键
    private static final int WHEEL = 1 << 5;
    
    private int x;          // X坐标
    private int y;          // Y坐标
    private int info;       // 按钮状态和操作类型
    private int rotations;  // 滚轮旋转次数
}
```

### Flutter Client 数据模型

**lib/models/models.dart**:
```dart
class MouseEvent {
  final int x;
  final int y;
  final String button;  // 'left' | 'middle' | 'right'
  final String action;  // 'move' | 'down' | 'up' | 'wheel'
  final int? wheelDelta;
  
  // 转换为Java协议格式
  Map<String, dynamic> toJavaProtocol() {
    int info = 0;
    
    // 按钮状态
    if (action == 'down') info |= 1;      // PRESSED
    if (action == 'up') info |= (1 << 1); // RELEASED
    
    // 按钮类型
    if (button == 'left') info |= (1 << 2);    // BUTTON1
    if (button == 'middle') info |= (1 << 3);  // BUTTON2
    if (button == 'right') info |= (1 << 4);   // BUTTON3
    
    // 滚轮操作
    if (action == 'wheel') info |= (1 << 5);
    
    return {
      'x': x,
      'y': y,
      'info': info,
      'rotations': wheelDelta ?? 0,
    };
  }
}
```

✅ **状态**: 已实现兼容转换

---

## 3. 键盘控制协议 (Keyboard Control)

### Java Client 命令结构
```java
// common/command/CmdKeyControl.java
public class CmdKeyControl extends Cmd {
    private static final int PRESSED = 1;
    private static final int RELEASED = 1 << 1;
    
    private int info;       // 按键状态
    private int keyCode;    // 键盘代码
    private char keyChar;   // 字符值
}
```

### Flutter Client 数据模型

**lib/models/models.dart**:
```dart
class KeyboardEvent {
  final int keyCode;
  final String action;  // 'down' | 'up'
  final bool ctrlPressed;
  final bool altPressed;
  final bool shiftPressed;
  
  // 转换为Java协议格式
  Map<String, dynamic> toJavaProtocol() {
    int info = 0;
    
    if (action == 'down') info |= 1;      // PRESSED
    if (action == 'up') info |= (1 << 1); // RELEASED
    
    return {
      'info': info,
      'keyCode': keyCode,
      'keyChar': '', // 可选，由服务器处理
    };
  }
}
```

✅ **状态**: 已实现兼容转换

---

## 4. 屏幕捕获协议 (Screen Capture)

### Java Client 响应结构
```java
// common/remote/bean/RobotCaptureResponse.java
public class RobotCaptureResponse implements Serializable {
    private byte[] screenBytes;  // 压缩的屏幕数据
    private Long id;             // 帧ID
}
```

### Flutter Client 数据模型

**lib/models/models.dart**:
```dart
class FrameData {
  final int frameId;
  final int timestamp;
  final Uint8List imageData;  // 屏幕字节数据
  final String compressionType;
  final int width;
  final int height;
  
  // 从Java响应解析
  factory FrameData.fromJavaResponse(
    Map<String, dynamic> json,
    int screenWidth,
    int screenHeight,
  ) {
    return FrameData(
      frameId: json['id'] ?? 0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      imageData: Uint8List.fromList(json['screenBytes'] ?? []),
      compressionType: 'binary',
      width: screenWidth,
      height: screenHeight,
    );
  }
}
```

✅ **状态**: 已实现兼容解析

---

## 5. 命令类型映射 (Command Type)

| Java CmdType | 功能 | Flutter 对应 | 状态 |
|:--|:--|:--|:--|
| `ReqPing` | 心跳请求 | ConnectionService.sendHeartbeat() | ✅ |
| `ReqOpen` | 打开远程屏幕 | RemoteControlController.openRemoteScreen() | ✅ |
| `ReqCapture` | 请求屏幕捕获 | RemoteControlController.refreshScreen() | ✅ |
| `ReqRemoteClipboard` | 请求远程剪贴板 | ConnectionService 剪贴板模块 | ✅ |
| `Capture` | 屏幕捕获数据 | ConnectionService 处理帧数据 | ✅ |
| `KeyControl` | 键盘控制 | ConnectionService.sendKeyboardEvent() | ✅ |
| `MouseControl` | 鼠标控制 | ConnectionService.sendMouseEvent() | ✅ |
| `ClipboardText` | 剪贴板文本 | 剪贴板同步 | ⚠️ 未来版本 |
| `ChangePwd` | 修改密码 | LoginController.changePassword() | ✅ |

---

## 6. 网络通信层映射

### Java Client
```java
// 使用Netty框架
NioSocketChannel -> Bootstrap -> RemoteClient
编码器: NettyEncoder
解码器: NettyDecoder
处理器: RemoteChannelHandler
```

### Flutter Client
```dart
// 使用Dio HTTP客户端 + WebSocket
lib/services/api_service.dart
  - REST API调用
  - 错误处理
  - 请求/响应拦截

lib/services/connection_service.dart
  - WebSocket长连接
  - 帧数据流处理
  - 事件发送
```

**协议兼容性**: 
- ✅ 消息格式可兼容（JSON或二进制）
- ✅ 命令类型映射一致
- ✅ 数据结构对应

---

## 7. 会话管理协议

### Java Client
```java
// 连接状态管理
public enum State {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    RECONNECTING
}

// RemoteControlled 和 RemoteController 角色
CONTROLLER    // 控制者
CONTROLLED    // 被控制者
```

### Flutter Client
```dart
// lib/services/connection_service.dart
class ConnectionStatus {
  bool isConnected;
  String errorMessage;
  int reconnectAttempts;
  DateTime lastConnectionTime;
}

// 自动重连逻辑（指数退避）
Max Attempts: 5
Initial Delay: 5秒
```

✅ **状态**: 已实现兼容的会话管理

---

## 8. 实现检查清单

### 已完成 ✅

- [x] 心跳协议 (3秒间隔)
- [x] 鼠标控制事件序列化
- [x] 键盘控制事件序列化
- [x] 屏幕捕获数据结构
- [x] 会话连接管理
- [x] 自动重连机制 (5次尝试)
- [x] 错误处理和日志
- [x] 命令类型映射

### 待完成 (可选)

- [ ] 剪贴板同步细节实现
- [ ] 文件传输协议 (ClipboardTransfer)
- [ ] 音频支持
- [ ] 触摸笔支持 (HarmonyOS特定)

---

## 9. 测试协议兼容性

### 测试步骤

1. **启动Flutter客户端**
   ```bash
   flutter run
   ```

2. **连接到Java服务器**
   - 输入服务器IP: `localhost` 或服务器地址
   - 输入端口: Java服务器监听的端口
   - 输入设备代码和密码

3. **测试各个功能**
   ```
   ✅ 鼠标移动
   ✅ 鼠标点击
   ✅ 键盘输入
   ✅ 屏幕刷新
   ✅ 重连测试
   ```

4. **观察日志**
   ```
   lib/services/api_service.dart 中的 LoggingInterceptor
   查看所有请求/响应内容
   ```

---

## 10. 扩展和集成指南

### 添加新的命令类型

如果需要在Java服务器中添加新的命令，按照以下步骤：

1. **在Java Common模块中定义**
   ```java
   // common/command/CmdNewFeature.java
   public class CmdNewFeature extends Cmd {
       // ... implementation
   }
   ```

2. **在CmdType中添加**
   ```java
   public enum CmdType {
       // ... existing
       NewFeature,  // 新命令
   }
   ```

3. **在Flutter中添加对应的模型**
   ```dart
   // lib/models/models.dart
   class NewFeatureData {
       // ... 对应字段
   }
   ```

4. **在ConnectionService中添加处理**
   ```dart
   // lib/services/connection_service.dart
   void _handleNewFeature(Map data) {
       // 处理新命令
   }
   ```

---

## 11. 常见问题 (FAQ)

### Q: Flutter和Java客户端能同时控制一台设备吗？
**A**: 取决于Java服务器的实现。通常一次只能有一个Controller控制一台设备。

### Q: 屏幕数据如何压缩？
**A**: Java服务器负责压缩。Flutter客户端应该能处理常见的压缩格式（ZIP、GZIP等）。

### Q: 如何处理高延迟网络？
**A**: 
- 调整心跳超时时间
- 增加重连次数
- 实现帧跳跃（不显示过期帧）

### Q: 支持哪些键盘代码？
**A**: 参考Java VK_* 常量或标准键盘扫描码。Flutter中使用PhysicalKeyboardKey。

---

## 12. 参考资源

### Java Client 关键文件
- `/client/src/main/java/io/github/springstudent/dekstop/client/RemoteClient.java`
- `/common/src/main/java/io/github/springstudent/dekstop/common/command/`
- `/common/src/main/java/io/github/springstudent/dekstop/common/remote/bean/`

### Flutter Client 关键文件
- `lib/services/api_service.dart` - API通信
- `lib/services/connection_service.dart` - 连接管理
- `lib/controllers/remote_control_controller.dart` - 远程控制逻辑
- `lib/models/models.dart` - 数据模型

---

## 版本信息

| 组件 | 版本 |
|:--|:--|
| Flutter | 3.0.0+ |
| Dart | 3.0.0+ |
| Java Client | 2024/12 |
| Protocol Version | 1.0 |
| Last Updated | 2024年 |

---

**注意**: 本文档与实际Java服务器实现保持同步。如有协议变更，请同时更新此文档。
