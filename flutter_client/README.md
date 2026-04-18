# HarmonyOS Remote Desktop Control - Flutter Client

这是HarmonyOS远程桌面控制应用的Flutter实现版本，用于替代Java客户端的UI。该应用提供了一个现代化、响应式的用户界面，与HarmonyOS设计风格保持一致。

## 功能特性

- 🔐 **安全连接**：支持加密连接和身份验证
- 🖥️ **远程控制**：鼠标、键盘、触摸板支持
- 📱 **响应式设计**：支持多种屏幕尺寸
- 🎨 **HarmonyOS风格**：采用Material Design 3和HarmonyOS配色
- 🌓 **深色模式**：支持浅色和深色主题
- 📋 **剪贴板同步**：支持文本和剪贴板同步
- ⚡ **实时流传输**：高效的视频帧传输
- 🔄 **自动重连**：连接断开时自动重新连接
- 📝 **连接历史**：保存最近使用的连接

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── theme/
│   └── app_theme.dart                # 主题配置
├── routes/
│   └── app_routes.dart               # 路由配置
├── screens/
│   ├── login/                        # 登录屏幕
│   ├── home/                         # 首页屏幕
│   ├── remote_control/               # 远程控制屏幕
│   ├── device_list/                  # 设备列表屏幕
│   ├── connection/                   # 连接设置屏幕
│   └── settings/                     # 设置屏幕
├── controllers/
│   ├── login_controller.dart         # 登录控制器
│   ├── home_controller.dart          # 首页控制器
│   ├── remote_control_controller.dart # 远程控制控制器
│   ├── device_list_controller.dart   # 设备列表控制器
│   └── settings_controller.dart      # 设置控制器
├── services/
│   ├── api_service.dart              # API服务
│   └── connection_service.dart       # 连接服务
├── models/
│   └── models.dart                   # 数据模型
├── constants/
│   └── app_constants.dart            # 常量定义
└── utils/
    └── app_utils.dart                # 工具函数
```

## 安装和运行

### 前置条件

- Flutter SDK 3.0.0 或更高版本
- Dart SDK 3.0.0 或更高版本
- Android Studio / Xcode（用于iOS）

### 安装步骤

1. **克隆项目**
```bash
cd /mnt/c/learn/HamonyOS-remote-desktop-control/flutter_client
```

2. **安装依赖**
```bash
flutter pub get
```

3. **运行应用**
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

## 主要屏幕说明

### 1. 登录屏幕 (LoginScreen)
- 输入设备代码、服务器地址、端口和密码
- 支持记住登录信息
- 错误提示和加载状态显示

### 2. 首页屏幕 (HomeScreen)
- 显示已连接的设备列表
- 设备在线状态指示
- 快速连接按钮
- 下拉刷新功能

### 3. 远程控制屏幕 (RemoteControlScreen)
- 实时显示远程屏幕
- 鼠标事件处理（移动、点击、滚轮）
- 键盘输入支持
- 虚拟键盘和触摸板
- 工具栏：截图、键盘、鼠标、更多选项

### 4. 设备列表屏幕 (DeviceListScreen)
- 浏览所有可用设备
- 搜索和筛选功能
- 添加新设备

### 5. 连接设置屏幕 (ConnectionScreen)
- 服务器配置
- 视频质量设置
- 高级选项配置

### 6. 设置屏幕 (SettingsScreen)
- 语言和主题切换
- 连接历史管理
- 帮助和反馈
- 登出账户

## API集成

该应用与Java后端服务通过REST API通信，主要端点包括：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/login` | POST | 用户登录 |
| `/api/devices` | GET | 获取设备列表 |
| `/api/remote/open` | POST | 打开远程屏幕 |
| `/api/remote/close` | POST | 关闭远程屏幕 |
| `/api/password/change` | POST | 修改密码 |
| `/api/events/mouse` | POST | 发送鼠标事件 |
| `/api/events/keyboard` | POST | 发送键盘事件 |
| `/api/clipboard` | GET/POST | 剪贴板同步 |

## 设计特点

### 颜色方案
- **主色**：`#0A59F7` (HarmonyOS深蓝)
- **辅助色**：`#00D4F7` (HarmonyOS青色)
- **成功色**：`#36AE00` (成功绿)
- **警告色**：`#FF8E00` (警告橙)
- **错误色**：`#FF3B00` (错误红)

### 响应式设计
应用支持以下断点：
- **小屏幕** (< 600px)：手机
- **中屏幕** (600px - 960px)：平板
- **大屏幕** (960px - 1280px)：桌面平板
- **超大屏幕** (> 1280px)：桌面

### 状态管理
使用 GetX 框架进行状态管理：
- 响应式状态管理
- 依赖注入
- 路由导航
- 事件总线

## 核心服务

### ConnectionService
管理与远程桌面的连接生命周期：
- 初始化连接
- 打开/关闭远程屏幕
- 发送鼠标和键盘事件
- 自动重连机制
- 流处理视频帧

### ApiService
处理所有HTTP API调用：
- 请求拦截
- 响应处理
- 错误处理和日志记录
- 自动重试

## 配置常量

所有主要配置常量定义在 `lib/constants/app_constants.dart`：

```dart
// 服务器配置
static const String defaultServerIp = 'localhost';
static const int defaultServerPort = 8080;

// 超时设置
static const Duration connectionTimeout = Duration(seconds: 30);

// 重连配置
static const int maxReconnectAttempts = 5;
static const Duration reconnectDelay = Duration(seconds: 5);
```

## 开发工具

- **状态管理**：GetX
- **网络请求**：Dio
- **本地存储**：SharedPreferences, GetStorage
- **日志**：Logger
- **字体**：Google Fonts
- **国际化**：intl

## 构建和部署

### 构建APK (Android)
```bash
flutter build apk
```

### 构建AAB (Android Play Store)
```bash
flutter build appbundle
```

### 构建IPA (iOS)
```bash
flutter build ios
```

### 构建Web
```bash
flutter build web
```

## 测试

运行单元测试：
```bash
flutter test
```

运行集成测试：
```bash
flutter drive --target=test_driver/app.dart
```

## 故障排除

### 连接失败
- 检查服务器地址和端口是否正确
- 确保服务器正在运行
- 检查网络连接

### 视频播放卡顿
- 降低视频质量设置
- 减少帧率
- 检查网络带宽

### 输入不响应
- 确保远程屏幕已打开
- 检查连接状态
- 重新连接设备

## 相关文档

- [Java客户端实现](../client/README.md)
- [HarmonyOS客户端](../HarmonOS_remote_desktop_control_client/README.md)
- [服务器API文档](../docs/api/server-api.md)
- [架构设计文档](../docs/development/architecture.md)

## 许可证

本项目遵循 [LICENSE.txt](../LICENSE.txt) 中的许可证条款。

## 贡献

欢迎提交问题、功能请求和拉取请求。

## 联系方式

如有问题或建议，请通过以下方式联系我们：
- GitHub Issues
- 邮件反馈
- 应用内反馈功能

## 更新日志

### v1.0.0 (2024)
- 初始版本发布
- 基础远程控制功能
- HarmonyOS风格UI
- 跨平台支持
