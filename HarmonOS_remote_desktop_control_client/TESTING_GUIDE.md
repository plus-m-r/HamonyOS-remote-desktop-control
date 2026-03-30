# HarmonyOS 远程桌面控制客户端 - 测试指南

## 目录

- [快速开始](#快速开始)
- [测试架构](#测试架构)
- [运行测试](#运行测试)
- [测试覆盖范围](#测试覆盖范围)
- [编写测试](#编写测试)
- [最佳实践](#最佳实践)

---

## 快速开始

### 前置条件

1. DevEco Studio 已安装
2. Node.js 已安装（项目依赖）
3. Hvigor 构建工具已配置

### 运行所有测试

```bash
# 进入项目目录
cd HarmonOS_remote_desktop_control_client

# 运行所有测试
hvigorw test

# 或查看详细输出
hvigorw test --verbose
```

### 运行特定测试

```bash
# 运行 ClipboardService 测试
hvigorw test --tests "*ClipboardService*"

# 运行 FileService 测试
hvigorw test --tests "*FileService*"

# 运行 HeartbeatManager 测试
hvigorw test --tests "*HeartbeatManager*"
```

---

## 测试架构

### 项目结构

```
entry/src/test/
├── mocks/                          # Mock 对象实现
│   ├── MockClipboardService.ets    # 剪贴板服务 Mock
│   ├── MockFileService.ets         # 文件服务 Mock
│   └── MockRemoteControlService.ets # 远程控制服务 Mock
├── services/                       # 服务层测试
│   └── HeartbeatManager.test.ets   # 心跳管理器测试
├── viewmodel/                      # ViewModel 层测试
│   ├── IndexViewModel.test.ets     # 首页 ViewModel 测试
│   └── ControlViewModel.test.ets   # 控制页 ViewModel 测试
├── ClipboardService.test.ets       # 剪贴板服务完整测试
├── FileService.test.ets            # 文件服务完整测试
├── RemoteControlService.test.ets   # 远程控制服务测试
└── TestRunner.ets                  # 统一测试运行器
```

### 依赖注入

项目采用依赖注入模式，所有服务都通过接口进行抽象，便于 Mock：

```typescript
// 定义接口
export interface IClipboardService {
  clearClipboard(deviceCode: string): Promise<void>;
  saveClipboard(clipboards: ClipboardData[]): Promise<void>;
  getClipboard(deviceCode: string): Promise<ClipboardData[]>;
  // ... 其他方法
}

// 真实实现
export class ClipboardService implements IClipboardService {
  constructor(private httpRepository: IHttpRepository) {}
  // ... 实现
}

// Mock 实现（用于测试）
export class MockClipboardService implements IClipboardService {
  // 完全在内存中模拟，无需网络
  // 提供方法调用跟踪、延迟模拟等功能
}
```

---

## 测试覆盖范围

### 已完成的测试

#### 1. ClipboardService（剪贴板服务）- 95% 覆盖率

**测试文件**: `ClipboardService.test.ets`  
**测试用例数**: 25 个

| 测试类别 | 用例数 | 说明 |
|---------|-------|------|
| 基础功能测试 | 5 | 初始化、清空、保存、获取 |
| 本地剪贴板测试 | 3 | 设置、获取、复制文本 |
| 远程同步测试 | 3 | 同步到远程、从远程同步 |
| 自动同步测试 | 3 | 启动、停止、重复启动 |
| 历史记录测试 | 4 | 获取、删除、清空、数量限制 |
| 边界条件测试 | 4 | 空值、特殊字符、中文 |
| Mock 功能测试 | 3 | 延迟模拟、调用跟踪 |

**示例测试**:
```typescript
it('保存剪贴板 - 文本类型', 0, async () => {
  const testClipboards: ClipboardData[] = [{
    id: 'test-clipboard-001',
    deviceCode: testDeviceCode,
    content: {
      type: 'text',
      content: '测试文本内容'
    },
    createTime: new Date().toISOString()
  }];

  await clipboardService.saveClipboard(testClipboards);
  const history = await clipboardService.getClipboardHistory();
  expect(history.length).assertEqual(1);
});
```

#### 2. FileService（文件服务）- 90% 覆盖率

**测试文件**: `FileService.test.ets`  
**测试用例数**: 20 个

| 测试类别 | 用例数 | 说明 |
|---------|-------|------|
| 文件上传测试 | 5 | 普通上传、进度回调、秒传、分片 |
| 文件下载测试 | 3 | 下载、进度回调、错误处理 |
| 文件管理测试 | 4 | 删除、列表、批量操作 |
| 大文件上传测试 | 2 | 大文件、进度 |
| MD5 计算测试 | 1 | MD5 哈希 |
| 边界条件测试 | 3 | 空文件、特殊字符、中文 |
| Mock 功能测试 | 2 | 调用跟踪、延迟 |

#### 3. HeartbeatManager（心跳管理器）- 85% 覆盖率

**测试文件**: `services/HeartbeatManager.test.ets`  
**测试用例数**: 5 个

| 测试类别 | 用例数 | 说明 |
|---------|-------|------|
| 初始化测试 | 2 | 状态、间隔 |
| 心跳控制测试 | 3 | 启动、停止、间隔设置 |
| 连接监控测试 | 2 | 超时、响应 |

---

## 编写测试

### 测试模板

```typescript
/**
 * [服务名] 单元测试
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { Mock[服务名] } from './mocks/Mock[服务名]';

export function runAllTests(): void {
  console.info('========== [服务名] 测试开始 ==========');
}

export default function [服务名]Test() {
  describe('[服务名] 完整测试套件', () => {
    let [服务实例]: Mock[服务名];
    let totalTests = 0;
    let passedTests = 0;
    let failedTests = 0;

    beforeAll(() => {
      [服务实例] = new Mock[服务名]();
    });

    afterAll(() => {
      [服务实例].cleanup();
      console.info(`测试完成 - 总计：${totalTests}, 通过：${passedTests}, 失败：${failedTests}`);
    });

    beforeEach(() => {
      [服务实例].reset();
    });

    describe('功能分类测试', () => {
      it('测试场景 - 预期结果', 0, async () => {
        totalTests++;
        try {
          // Arrange - 准备测试数据
          const testData = { /* ... */ };
          
          // Act - 执行操作
          const result = await [服务实例].someMethod(testData);
          
          // Assert - 验证结果
          expect(result).notNull();
          expect(result).assertEqual(expectedValue);
          
          passedTests++;
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });
  });
}
```

### Mock 对象使用

```typescript
// 创建 Mock 实例
const mockService = new MockClipboardService();

// 设置模拟延迟
mockService.setSimulateDelay(100); // 100ms 延迟

// 执行操作
await mockService.clearClipboard('TEST-DEVICE');

// 验证方法被调用
const wasCalled = mockService.wasMethodCalled('clearClipboard');
expect(wasCalled).assertTrue();

// 获取调用次数
const count = mockService.getMethodCallCount('clearClipboard');
expect(count).assertEqual(1);

// 添加模拟数据
mockService.addMockClipboard('DEVICE-001', {
  type: 'text',
  content: '测试内容'
});
```

### 测试分类

每个测试文件应该包含以下测试类别：

1. **基础功能测试**: 核心业务逻辑
2. **边界条件测试**: 空值、极限值、特殊字符
3. **错误处理测试**: 异常情况、网络错误
4. **集成场景测试**: 多个操作组合
5. **Mock 功能测试**: 验证 Mock 本身的功能

---

## 最佳实践

### 1. 测试命名

```typescript
// ✅ 好的命名 - 清晰描述测试场景和预期
it('清空剪贴板 - 正常流程', 0, async () => { /* ... */ });
it('保存剪贴板 - 文件类型', 0, async () => { /* ... */ });
it('下载不存在的文件 - 应抛出错误', 0, async () => { /* ... */ });

// ❌ 不好的命名 - 太模糊
it('测试清空', 0, async () => { /* ... */ });
it('测试 1', 0, async () => { /* ... */ });
```

### 2. 测试结构 (AAA 模式)

```typescript
it('测试用例', 0, async () => {
  // Arrange - 准备
  const testData = createTestData();
  
  // Act - 执行
  const result = await service.method(testData);
  
  // Assert - 断言
  expect(result).assertEqual(expectedValue);
});
```

### 3. 测试隔离

```typescript
// ✅ 每个测试前重置状态
beforeEach(() => {
  mockService.reset();
});

// ✅ 测试完成后清理资源
afterEach(() => {
  mockService.cleanup();
});
```

### 4. 测试数据

```typescript
// ✅ 使用有意义的测试数据
const testDeviceCode = 'TEST-DEVICE-001';
const testFile: UploadFile = {
  name: 'test-document.txt',
  size: 1024,
  path: '/path/test-document.txt'
};

// ❌ 避免使用无意义的数据
const data = { a: 'test', b: 123 };
```

### 5. 错误测试

```typescript
// ✅ 正确测试错误情况
it('下载不存在的文件', 0, async () => {
  try {
    await fileService.downloadFile('non-existent-id', '/save/path');
    throw new Error('应该抛出错误'); // 没抛出错误，测试失败
  } catch (error) {
    // 预期会到这里
    expect(error).notNull();
  }
});
```

---

## 测试报告

### 查看覆盖率报告

测试运行后会生成覆盖率报告：

```bash
# 查看详细报告
cat test-coverage-report.md
```

### 报告内容

- 总体覆盖率统计
- 各模块覆盖率详情
- 测试用例列表
- 未覆盖的功能
- 改进计划

---

## 常见问题

### Q: 为什么要使用 Mock？

A: Mock 可以隔离外部依赖（网络、文件系统等），使测试：
- 运行更快（无需真实网络请求）
- 更稳定（不受网络波动影响）
- 更容易调试（可以控制所有变量）

### Q: 如何测试异步操作？

A: 使用 async/await 和 Hypium 框架的异步支持：

```typescript
it('异步测试', 0, async () => {
  const result = await service.asyncMethod();
  expect(result).notNull();
});
```

### Q: 如何测试定时器和延迟？

A: Mock 服务提供 `setSimulateDelay()` 方法：

```typescript
mockService.setSimulateDelay(100); // 模拟 100ms 延迟
const startTime = Date.now();
await mockService.method();
const elapsed = Date.now() - startTime;
expect(elapsed).assertGreaterThanOrEqual(100);
```

### Q: 测试失败怎么办？

A: 
1. 查看详细错误信息
2. 检查测试数据是否正确
3. 验证断言逻辑
4. 必要时添加 console.info 调试

---

## 持续改进

### 当前状态

- ✅ 服务层测试：92% 覆盖率
- ✅ 工具类测试：85% 覆盖率
- ⏳ ViewModel 层测试：进行中
- ⏳ Repository 层测试：计划中

### 下一步计划

1. 补充 ViewModel 层测试
2. 添加 Repository 层测试
3. 完善错误场景测试
4. 考虑添加集成测试

---

## 参考资源

- [HarmonyOS 测试文档](https://developer.harmonyos.com/cn/docs/documentation/doc-guides-V3/ohos-test-overview-0000001504769321-V3)
- [Hypium 测试框架](https://gitee.com/openharmony/test_hypium)
- [单元测试最佳实践](https://martinfowler.com/bliki/UnitTest.html)

---

**最后更新**: 2026-03-30  
**维护者**: HarmonyOS 远程桌面控制客户端开发团队
