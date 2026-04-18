# Flutter 客户端与 Java 后端集成指南

## 概述

本指南说明如何将Flutter客户端与现有的Java后端服务集成，实现完整的远程桌面控制系统。

## 系统架构

```
┌─────────────────────────────────────────────────────┐
│           Flutter Client Application                 │
│  ┌──────────────────────────────────────────────┐   │
│  │  UI Layer (Screens & Widgets)                │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Logic Layer (Controllers with GetX)         │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Service Layer (API & Connection Services)   │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                        │
                        │ HTTP/REST API
                        │ WebSocket (optional)
                        ▼
┌─────────────────────────────────────────────────────┐
│          Java Backend Service                        │
│  ┌──────────────────────────────────────────────┐   │
│  │  API Controllers (Spring Boot)               │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Business Logic Layer                        │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Network Communication (Netty)               │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Remote Device Management                    │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                        │
                        │ Socket Connection
                        │
                        ▼
                  Remote Devices
```

## API 端点配置

### 基础配置

编辑 `lib/config/app_config.dart`：

```dart
static const Map<String, String> apiBaseUrl = {
  Environment.dev: 'http://localhost:8080',
  Environment.staging: 'http://api-staging.example.com:8080',
  Environment.production: 'https://api.example.com:443',
};
```

### 认证配置

Java后端应该实现以下认证机制：

```dart
// 登录请求
POST /api/login
Content-Type: application/json

{
  "deviceCode": "DEVICE123",
  "password": "password123"
}

// 响应
{
  "code": 0,
  "message": "success",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userId": "user123",
  "deviceId": "device123"
}
```

后续请求应在Authorization头中包含token：

```dart
headers: {
  'Authorization': 'Bearer $token',
  'Content-Type': 'application/json',
}
```

## 数据同步流程

### 登录流程

```
User Input
    ↓
LoginController.login()
    ↓
ApiService.login(deviceCode, password)
    ↓
POST /api/login
    ↓
Java Backend Authentication
    ↓
Generate JWT Token
    ↓
Response with Token
    ↓
ConnectionService.initializeConnection()
    ↓
Save Token to SharedPreferences
    ↓
Navigate to Home Screen
```

### 设备列表同步

```
HomeScreen.onInit()
    ↓
HomeController.loadDevices()
    ↓
ApiService.getDeviceList()
    ↓
GET /api/devices (with Authorization)
    ↓
Java Backend Query Database
    ↓
Response with Device List
    ↓
Update Devices Observable
    ↓
Refresh UI
```

### 远程控制流程

```
User Taps Connect
    ↓
RemoteControlController.openRemoteScreen()
    ↓
ApiService.openRemoteScreen(deviceCode, password)
    ↓
POST /api/remote/open
    ↓
Java Backend:
  - Verify Credentials
  - Establish Connection to Remote Device
  - Start Frame Capture
    ↓
Response Success
    ↓
ConnectionService.startFrameCapture()
    ↓
Listen on Frame Stream
    ↓
Display Video Stream
```

## API 端点详细规范

### 1. 登录接口

**端点**: `POST /api/login`

**请求**:
```json
{
  "deviceCode": "string",
  "password": "string"
}
```

**响应**:
```json
{
  "code": 0,
  "message": "success",
  "token": "jwt_token",
  "userId": "user_id",
  "deviceId": "device_id",
  "expiresIn": 3600
}
```

**错误响应**:
```json
{
  "code": 401,
  "message": "设备代码或密码错误"
}
```

### 2. 获取设备列表

**端点**: `GET /api/devices`

**请求头**:
```
Authorization: Bearer {token}
```

**响应**:
```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "deviceId": "device_001",
      "deviceName": "Work Computer",
      "deviceModel": "Windows 10",
      "screenResolution": "1920x1080",
      "isOnline": true,
      "lastConnectedTime": "2024-04-18T10:30:00Z"
    }
  ]
}
```

### 3. 打开远程屏幕

**端点**: `POST /api/remote/open`

**请求**:
```json
{
  "deviceCode": "DEVICE123",
  "password": "password123"
}
```

**响应**:
```json
{
  "code": 0,
  "message": "success",
  "sessionId": "session_123",
  "frameStreamUrl": "ws://localhost:8080/api/stream/frames/session_123"
}
```

### 4. 发送鼠标事件

**端点**: `POST /api/events/mouse`

**请求**:
```json
{
  "sessionId": "session_123",
  "x": 500,
  "y": 300,
  "button": "left",
  "action": "move"
}
```

**响应**:
```json
{
  "code": 0,
  "message": "success"
}
```

### 5. 发送键盘事件

**端点**: `POST /api/events/keyboard`

**请求**:
```json
{
  "sessionId": "session_123",
  "keyCode": 65,
  "action": "down",
  "ctrlPressed": false,
  "altPressed": false,
  "shiftPressed": false
}
```

**响应**:
```json
{
  "code": 0,
  "message": "success"
}
```

## WebSocket 连接（实时视频流）

### 连接建立

```dart
// Flutter 客户端
final channel = IOWebSocketChannel.connect(
  'ws://localhost:8080/api/stream/frames/session_123'
);

// 监听帧数据
channel.stream.listen((dynamic message) {
  // 处理视频帧
  final frameData = FrameData.fromJson(jsonDecode(message));
  updateRemoteScreen(frameData);
});
```

### 帧数据格式

```json
{
  "frameId": 1,
  "timestamp": 1713440400000,
  "width": 1920,
  "height": 1080,
  "compressionType": "zstd",
  "data": "base64_encoded_image_data",
  "timestamp": 1713440400000
}
```

## 错误处理和异常

### 网络错误处理

```dart
try {
  await apiService.login(deviceCode, password);
} on SocketException catch (e) {
  // 网络连接失败
  AppUtils.showError('网络连接失败: ${e.message}');
} on TimeoutException catch (e) {
  // 请求超时
  AppUtils.showError('请求超时，请检查网络');
} on DioException catch (e) {
  if (e.response?.statusCode == 401) {
    // 未授权
    handleUnauthorized();
  } else if (e.response?.statusCode == 403) {
    // 禁止访问
    handleForbidden();
  } else if (e.response?.statusCode == 500) {
    // 服务器错误
    handleServerError();
  }
} catch (e) {
  // 其他错误
  AppUtils.showError('发生错误: $e');
}
```

### 自动重连策略

```dart
class ConnectionService extends GetxService {
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 5);
  
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  
  void _handleConnectionError() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      logger.e('达到最大重连次数');
      return;
    }
    
    _reconnectAttempts++;
    _reconnectTimer = Timer(reconnectDelay, _attemptReconnect);
  }
  
  Future<void> _attemptReconnect() async {
    try {
      await initializeConnection(_config);
      _reconnectAttempts = 0;
    } catch (e) {
      _handleConnectionError();
    }
  }
}
```

## 性能优化建议

### 1. 请求优化

```dart
// ❌ 不好：逐个获取设备
for (var deviceId in deviceIds) {
  await getDevice(deviceId);
}

// ✅ 好：批量获取
await getDevicesBatch(deviceIds);
```

### 2. 缓存策略

```dart
// 实现响应缓存
class CachedApiService extends ApiService {
  final Map<String, CacheEntry> _cache = {};
  static const Duration cacheDuration = Duration(minutes: 5);
  
  @override
  Future<List<RemoteDevice>> getDeviceList() async {
    final cacheKey = 'deviceList';
    
    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (DateTime.now().difference(entry.timestamp) < cacheDuration) {
        return entry.data;
      }
    }
    
    final data = await super.getDeviceList();
    _cache[cacheKey] = CacheEntry(data, DateTime.now());
    return data;
  }
}
```

### 3. 连接池复用

```dart
// 重用 Dio 实例而不是创建多个
static final _dio = Dio(BaseOptions(
  baseUrl: apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 30),
));
```

## 安全最佳实践

### 1. Token 管理

```dart
// 自动刷新过期token
class TokenInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = getStoredToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // 处理token过期
      handleTokenExpired();
    }
    super.onError(err, handler);
  }
}
```

### 2. 密钥存储

```dart
// 不要在代码中硬编码敏感信息
// ❌ 不好
const String apiKey = 'sk-1234567890abcdef';

// ✅ 好
// 从服务器获取或从加密存储读取
final apiKey = await _secureStorage.read(key: 'api_key');
```

### 3. 数据验证

```dart
// 验证所有用户输入
bool validateServerAddress(String address) {
  if (address.isEmpty) return false;
  
  // 检查是否为有效的IP或域名
  final ipPattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
  final domainPattern = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  
  return ipPattern.hasMatch(address) || domainPattern.hasMatch(address) || 
         address == 'localhost';
}
```

## 测试指南

### 单元测试示例

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  group('LoginController Tests', () {
    late LoginController controller;
    late MockApiService mockApiService;
    
    setUp(() {
      mockApiService = MockApiService();
      controller = LoginController();
      
      when(mockApiService.login(any, any))
          .thenAnswer((_) async => {'code': 0, 'token': 'test_token'});
    });
    
    test('Login with valid credentials should succeed', () async {
      await controller.login();
      
      expect(controller.isLoading.value, false);
      expect(controller.errorMessage.value, isEmpty);
    });
  });
}
```

### 集成测试

```bash
flutter drive --target=test_driver/app.dart
```

## 故障排除

### 问题1：连接超时

**症状**: 应用卡在连接界面，最终显示"连接超时"

**解决方案**:
1. 检查Java后端是否在运行
2. 确认服务器地址和端口正确
3. 检查防火墙设置
4. 查看服务器日志

### 问题2：认证失败

**症状**: 显示"设备代码或密码错误"

**解决方案**:
1. 确认输入的设备代码和密码正确
2. 检查Java后端的认证逻辑
3. 查看服务器日志中的认证错误

### 问题3：视频流无法显示

**症状**: 远程控制屏幕为黑色，无法看到远程桌面

**解决方案**:
1. 检查WebSocket连接是否建立
2. 确认Java后端正在捕获屏幕
3. 查看网络中是否有丢包
4. 检查视频编码和解码库

### 问题4：输入事件无响应

**症状**: 鼠标和键盘事件无法在远程设备上工作

**解决方案**:
1. 确认远程屏幕已成功打开
2. 检查Java后端的事件处理代码
3. 查看权限设置（Windows UAC, macOS权限等）
4. 查看服务器日志中的错误信息

## 部署检查清单

- [ ] API基URL正确配置
- [ ] 认证token获取和刷新工作正常
- [ ] 所有API端点均已实现
- [ ] 错误处理和日志记录就位
- [ ] WebSocket连接稳定
- [ ] 已进行负载测试
- [ ] 安全性审查完成
- [ ] 用户文档已准备
- [ ] 监控和告警已配置

## 版本兼容性

| 组件 | 版本 | 兼容性 |
|------|------|--------|
| Flutter | 3.0.0+ | ✅ |
| Dart | 3.0.0+ | ✅ |
| Java Spring Boot | 2.7+ | ✅ |
| Netty | 4.1+ | ✅ |
| REST API | v1.0 | ✅ |

## 相关文档

- [Flutter客户端README](./README.md)
- [开发指南](./DEVELOPMENT.md)
- [快速启动](./QUICKSTART.md)
- [Java后端文档](../server/README.md)
- [API参考](../docs/api/server-api.md)

## 支持和反馈

如有问题或建议，请：
1. 提交GitHub Issue
2. 发送邮件至support@example.com
3. 在应用内提交反馈

---

**最后更新**: 2024年
**文档版本**: 1.0.0
