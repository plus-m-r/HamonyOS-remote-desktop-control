# Flutter 客户端开发指南

## 项目概述

本项目是HarmonyOS远程桌面控制应用的Flutter实现版本。该应用提供了与Java客户端相同的功能，但采用了现代化的Flutter框架和HarmonyOS设计风格。

## 架构设计

### 分层架构

```
UI Layer (Screens & Widgets)
    ↓
Logic Layer (Controllers)
    ↓
Service Layer (Services)
    ↓
Data Layer (Models & APIs)
```

### 核心组件

#### 1. Screens（屏幕/页面）
位置：`lib/screens/`

每个屏幕是一个完整的页面，负责：
- 构建UI布局
- 与Controller通信
- 显示Loading和Error状态
- 处理用户交互

#### 2. Controllers（控制器）
位置：`lib/controllers/`

每个Controller负责：
- 管理屏幕的业务逻辑
- 维护响应式状态（Rx对象）
- 与Service通信
- 处理错误和异常

#### 3. Services（服务）
位置：`lib/services/`

服务负责：
- 与后端API通信
- 管理网络连接
- 处理实时数据流
- 缓存和本地存储

#### 4. Models（数据模型）
位置：`lib/models/`

数据模型定义：
- API响应结构
- 业务实体
- 数据转换

## 开发流程

### 1. 添加新屏幕

```dart
// 1. 在 lib/screens/new_screen/ 目录下创建文件
// lib/screens/new_screen/new_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/new_screen_controller.dart';

class NewScreen extends StatelessWidget {
  const NewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NewScreenController());
    
    return Scaffold(
      appBar: AppBar(title: const Text('New Screen')),
      body: Obx(() {
        // UI代码
      }),
    );
  }
}
```

```dart
// 2. 在 lib/controllers/ 目录下创建Controller
// lib/controllers/new_screen_controller.dart

import 'package:get/get.dart';

class NewScreenController extends GetxController {
  final data = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadData();
  }
  
  void loadData() {
    // 实现业务逻辑
  }
}
```

```dart
// 3. 在 lib/routes/app_routes.dart 中添加路由
static const String newScreen = '/new-screen';

static final List<GetPage> pages = [
  // ... 其他路由
  GetPage(
    name: newScreen,
    page: () => const NewScreen(),
  ),
];
```

### 2. 添加新的API端点

```dart
// lib/services/api_service.dart

class ApiService {
  // 添加新的方法
  Future<Map<String, dynamic>> getNewData() async {
    try {
      final response = await _dio.get('/api/new-endpoint');
      return response.data;
    } catch (e) {
      logger.e('获取数据失败: $e');
      rethrow;
    }
  }
}
```

### 3. 添加新的模型

```dart
// lib/models/models.dart

class NewModel {
  final String id;
  final String name;
  final String description;

  NewModel({
    required this.id,
    required this.name,
    required this.description,
  });

  factory NewModel.fromJson(Map<String, dynamic> json) {
    return NewModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}
```

## 状态管理（GetX）

### 基本用法

```dart
// 创建响应式变量
final count = 0.obs;
final name = ''.obs;
final items = <String>[].obs;
final user = Rxn<User>();

// 修改值
count.value = 10;
name.value = 'John';
items.add('item1');
user.value = User(...);

// 在Widget中观察
Obx(() {
  return Text('Count: ${count.value}');
});

// 监听变化
ever(count, (value) {
  print('Count changed to: $value');
});

// 条件监听
once(count, (value) {
  print('Count changed first time to: $value');
});
```

### 依赖注入

```dart
// 注册Service
Get.put(ConnectionService());

// 获取Service
final service = Get.find<ConnectionService>();

// 延迟初始化
Get.lazyPut(() => ExpensiveService());

// 单例
Get.putSingleton<ConfigService>(ConfigService());
```

## 通信流

### 网络请求流

```
Widget
  ↓ (用户交互)
Controller (处理业务逻辑)
  ↓ (调用服务)
Service (发送HTTP请求)
  ↓ (API调用)
Backend Server
```

### 事件流

```
Backend (WebSocket推送)
  ↓
ConnectionService (处理事件)
  ↓ (发送stream)
Controller (监听stream)
  ↓ (更新状态)
Widget (更新UI)
```

## 错误处理

```dart
// 统一错误处理
class ApiService {
  Future<T> _handleError<T>(dynamic error) async {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout) {
        throw '连接超时';
      } else if (error.type == DioExceptionType.receiveTimeout) {
        throw '请求超时';
      } else if (error.response?.statusCode == 401) {
        // 处理未认证错误
        await _handleUnauthorized();
      }
    }
    throw error;
  }
}

// 在Controller中使用
try {
  await apiService.login(...);
} on SocketException {
  errorMessage.value = '网络连接失败';
} on TimeoutException {
  errorMessage.value = '请求超时';
} catch (e) {
  errorMessage.value = e.toString();
}
```

## 本地存储

```dart
import 'package:shared_preferences/shared_preferences.dart';

// 保存数据
final prefs = await SharedPreferences.getInstance();
await prefs.setString('key', 'value');
await prefs.setInt('number', 42);
await prefs.setBool('flag', true);

// 读取数据
final value = prefs.getString('key') ?? 'default';
final number = prefs.getInt('number') ?? 0;
final flag = prefs.getBool('flag') ?? false;

// 删除数据
await prefs.remove('key');
await prefs.clear(); // 清除所有

// 监听变化
prefs.addListener(() {
  // 数据已改变
});
```

## 性能优化

### 1. 减少重建
```dart
// ❌ 不好：所有依赖都会导致重建
Obx(() => Text(controller.value.toString()));

// ✅ 好：只观察必要的字段
Obx(() => Text(controller.count.toString()));
```

### 2. 使用GetBuilder
```dart
// 对于不需要响应式的简单更新
GetBuilder<MyController>(
  builder: (controller) {
    return Text(controller.data);
  },
);
```

### 3. 分离业务逻辑
```dart
// ❌ 不好：混合UI和业务逻辑
build() {
  return GestureDetector(
    onTap: () {
      // 复杂业务逻辑在这里
    },
    child: Widget(),
  );
}

// ✅ 好：业务逻辑在Controller
class MyController extends GetxController {
  void handleTap() {
    // 业务逻辑
  }
}
```

## 测试

### 单元测试

```dart
// test/controllers/login_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('LoginController Tests', () {
    late LoginController controller;
    
    setUp(() {
      controller = LoginController();
    });
    
    test('Login should fail with empty credentials', () {
      controller.deviceCodeController.text = '';
      controller.login();
      
      expect(controller.errorMessage.value, isNotEmpty);
    });
  });
}
```

### Widget测试

```dart
// test/screens/login_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const RemoteDesktopApp());
    
    expect(find.text('设备代码'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
```

## 国际化（i18n）

### 1. 创建翻译文件

```dart
// lib/localization/messages_en.dart
const Map<String, String> en = {
  'login_title': 'Login',
  'device_code': 'Device Code',
  'server_address': 'Server Address',
  'password': 'Password',
};

// lib/localization/messages_zh.dart
const Map<String, String> zh = {
  'login_title': '登录',
  'device_code': '设备代码',
  'server_address': '服务器地址',
  'password': '密码',
};
```

### 2. 使用翻译

```dart
// 使用intl包
import 'package:intl/intl.dart';

Text(Intl.message('Hello', name: 'greeting'))
```

## 调试技巧

### 1. 日志记录
```dart
import 'package:logger/logger.dart';

final logger = Logger();

logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
```

### 2. DevTools
```bash
flutter pub global activate devtools
devtools
```

### 3. 性能分析
```bash
flutter run --profile
```

### 4. 网络监控
使用Charles或Fiddler代理来监控HTTP请求

## 常见问题

### Q: 如何在后台保持连接？
A: 使用`foreground_service`包来实现后台服务

### Q: 如何处理应用进入后台？
```dart
AppLifecycleListener(
  onDetach: () {
    connectionService.disconnect();
  },
);
```

### Q: 如何处理横竖屏切换？
```dart
OrientationBuilder(
  builder: (context, orientation) {
    if (orientation == Orientation.portrait) {
      return PortraitLayout();
    } else {
      return LandscapeLayout();
    }
  },
);
```

## 部署清单

- [ ] 更新版本号（`pubspec.yaml`）
- [ ] 更新README和文档
- [ ] 运行`flutter test`确保所有测试通过
- [ ] 运行`flutter analyze`检查代码质量
- [ ] 更新构建签名和应用配置
- [ ] 生成release构建
- [ ] 测试release版本
- [ ] 提交到应用商店

## 相关资源

- [Flutter官方文档](https://flutter.dev/docs)
- [GetX文档](https://github.com/jonataslaw/getx)
- [Dart官方指南](https://dart.dev/guides)
- [Material Design指南](https://material.io/design)
- [HarmonyOS设计规范](https://developer.harmonyos.com)
