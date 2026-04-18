# Flutter 客户端快速启动指南

## 环境要求

- **Flutter SDK**: 3.0.0 或以上
- **Dart SDK**: 3.0.0 或以上
- **IDE**: VS Code, Android Studio, 或 Xcode
- **操作系统**: Windows, macOS, 或 Linux

## 安装步骤

### 1. 安装 Flutter

如果尚未安装 Flutter，请访问 [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)

验证安装：
```bash
flutter --version
dart --version
```

### 2. 克隆项目

```bash
cd /mnt/c/learn/HamonyOS-remote-desktop-control
git clone <repo-url> flutter_client
cd flutter_client
```

### 3. 获取依赖

```bash
flutter pub get
```

### 4. 生成代码（如果需要）

```bash
flutter pub run build_runner build
```

## 运行应用

### 开发模式

```bash
# 自动检测设备
flutter run

# 指定设备
flutter run -d <device-id>

# 查看可用设备
flutter devices
```

### 发布模式

```bash
# 构建APK (Android)
flutter build apk --release

# 构建AAB (Google Play)
flutter build appbundle

# 构建IPA (iOS)
flutter build ios

# 构建Web
flutter build web
```

## 常用命令

```bash
# 清理构建
flutter clean

# 检查代码质量
flutter analyze

# 运行测试
flutter test

# 生成文档
dartdoc

# 查看日志
flutter logs

# 启用日志详情
flutter run -v

# 热重载
R

# 完全重启
Shift + R
```

## 项目配置

### 修改服务器地址

编辑 `lib/constants/app_constants.dart`：

```dart
static const String defaultServerIp = 'your-server-ip';
static const int defaultServerPort = 8080;
```

### 修改应用名称

编辑 `pubspec.yaml`：

```yaml
name: your_app_name
description: Your app description
```

### 修改应用图标

替换以下文件：
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### 修改应用主题

编辑 `lib/theme/app_theme.dart`：

```dart
static const Color primaryColor = Color(0xFF0A59F7); // 修改主色
static const Color accentColor = Color(0xFF00D4F7); // 修改辅助色
```

## 首次使用

### 1. 启动应用
```bash
flutter run
```

### 2. 登录页面
- 输入设备代码（来自远程设备）
- 输入服务器地址（Java后端服务器）
- 输入服务器端口（默认8080）
- 输入密码
- 点击"连接并登录"

### 3. 设备列表
- 查看已注册的远程设备
- 点击"连接"按钮开始远程控制

### 4. 远程控制
- 使用鼠标移动、点击
- 使用虚拟键盘输入
- 使用工具栏功能（截图、剪贴板等）

## 调试技巧

### 启用 DevTools

```bash
flutter pub global activate devtools
devtools
# 然后在浏览器中打开显示的地址
```

### 性能分析

```bash
flutter run --profile
# 使用 DevTools 中的 Performance 标签
```

### 网络请求日志

所有网络请求都会被记录。查看日志：

```bash
flutter logs
```

### 本地存储调试

在 SharedPreferences 中查看数据：

```dart
import 'package:shared_preferences/shared_preferences.dart';

final prefs = await SharedPreferences.getInstance();
print(prefs.getKeys()); // 查看所有键
```

## 常见问题

### Q: 应用启动缓慢
**A:** 
- 使用 `--profile` 模式测试性能
- 检查网络连接
- 确保后端服务正常运行

### Q: 连接失败
**A:**
- 检查服务器地址和端口是否正确
- 确保防火墙允许连接
- 查看日志获取具体错误信息

### Q: 视频显示但无法交互
**A:**
- 检查连接状态
- 尝试重新连接
- 查看是否有权限问题

### Q: 输入法不工作
**A:**
- 对于Android：确保输入法已安装并启用
- 对于iOS：使用虚拟键盘
- 尝试重启应用

### Q: 应用崩溃
**A:**
- 查看崩溃日志：`flutter logs`
- 检查依赖版本兼容性
- 尝试 `flutter clean` 后重新运行

## 开发工作流程

### 1. 创建特性分支
```bash
git checkout -b feature/new-feature
```

### 2. 开发功能
- 修改代码
- 运行 `flutter analyze` 检查质量
- 运行 `flutter test` 测试功能

### 3. 提交更改
```bash
git add .
git commit -m "feat: add new feature"
```

### 4. 创建 Pull Request
```bash
git push origin feature/new-feature
```

## 性能优化清单

- [ ] 使用 `const` 构造函数减少重建
- [ ] 在 ListView 中使用 `.builder`
- [ ] 分离业务逻辑和UI
- [ ] 使用 `GetBuilder` 而不是 `Obx` 在可能的地方
- [ ] 优化图片大小和加载
- [ ] 使用适当的图像缓存策略

## 安全最佳实践

- [ ] 不在代码中硬编码敏感信息
- [ ] 使用 HTTPS 连接
- [ ] 验证所有用户输入
- [ ] 定期更新依赖
- [ ] 使用加密存储敏感数据
- [ ] 实现适当的错误处理

## 下一步

1. **阅读详细文档**：[DEVELOPMENT.md](DEVELOPMENT.md)
2. **查看示例代码**：[README.md](README.md)
3. **参考API文档**：[docs/api/](../docs/api/)
4. **联系支持**：提交Issue或反馈

## 有用的资源

- [Flutter官方文档](https://flutter.dev/docs)
- [Dart语言指南](https://dart.dev/guides)
- [GetX文档](https://github.com/jonataslaw/getx)
- [Material Design](https://material.io/design)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

## 获取帮助

遇到问题？尝试：

1. 查看[常见问题](#常见问题)部分
2. 搜索[Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
3. 提交[GitHub Issue](https://github.com/your-repo/issues)
4. 查看[Flutter Discord社区](https://discord.gg/N7Yshp7)
