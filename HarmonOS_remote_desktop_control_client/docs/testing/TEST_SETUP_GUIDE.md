# HarmonyOS单元测试设置指南

## 1. 环境要求

### 开发环境
- **DevEco Studio**: 最新版本
- **HarmonyOS SDK**: 6.0.2 或更高
- **Node.js**: 16.0.0 或更高
- **ohpm**: HarmonyOS包管理器

### 测试框架
```json5
// oh-package.json5
{
  "devDependencies": {
    "@ohos/hypium": "1.0.25",  // 测试框架
    "@ohos/hamock": "1.0.0"    // Mock框架
  }
}
```

## 2. 项目结构

### 测试目录结构
```
entry/
├── src/
│   ├── main/          # 主代码
│   │   └── ets/
│   └── test/          # 单元测试
│       ├── *.test.ets # 测试文件
│       └── mocks/     # Mock对象
└── ohosTest/          # HarmonyOS测试模块
    └── ets/test/      # 测试入口
```

## 3. 测试配置

### module.json5 (测试模块)
```json5
{
  "module": {
    "name": "entry_test",
    "type": "feature",
    "deviceTypes": [
      "phone",
      "tablet",
      "2in1",
      "tv"
    ],
    "deliveryWithInstall": true,
    "installationFree": false
  }
}
```

### 依赖安装
```bash
# 安装测试依赖
ohpm install @ohos/hypium@1.0.25 --save-dev
ohpm install @ohos/hamock@1.0.0 --save-dev

# 同步项目
ohpm install
```

## 4. 编写测试

### 基本测试结构
```typescript
// Example.test.ets
import { describe, it, expect } from '@ohos/hypium';

export default function exampleTest() {
  describe('ExampleTestSuite', () => {
    it('testExample', 0, () => {
      // 测试逻辑
      const result = 1 + 1;
      expect(result).assertEqual(2);
    });
  });
}
```

### ViewModel测试示例
```typescript
// IndexViewModel.test.ets
import { IndexViewModel } from '../main/ets/viewmodel/IndexViewModel';
import { MockRemoteControlService } from '../mocks/MockRemoteControlService';

export class IndexViewModelTest {
  private viewModel: IndexViewModel;
  private mockService: MockRemoteControlService;

  constructor() {
    this.mockService = new MockRemoteControlService();
    this.viewModel = new IndexViewModel({
      remoteControlService: this.mockService,
      // ... 其他依赖
    });
  }

  async testInitialize() {
    // 测试初始化逻辑
    this.viewModel.initialize();
    // 验证状态
    expect(this.viewModel.getState()).assertNotNull();
  }
}
```

### Mock对象示例
```typescript
// MockRemoteControlService.ets
import { IRemoteControlService } from '../main/ets/services/interfaces/IRemoteControlService';

export class MockRemoteControlService implements IRemoteControlService {
  public callHistory: Array<{ method: string; args: unknown[] }> = [];
  
  async connect(): Promise<void> {
    this.recordCall('connect', []);
    // Mock实现
  }
  
  private recordCall(method: string, args: unknown[]): void {
    this.callHistory.push({ method, args });
  }
}
```

## 5. 运行测试

### 在DevEco Studio中运行
1. **打开测试文件**
2. **右键点击测试类或方法**
3. **选择 "Run Test"**
4. **查看测试结果窗口**

### 命令行运行
```bash
# 构建测试HAP
hvigor assembleHap --mode test

# 安装测试HAP
hdc install entry_test.hap

# 运行测试
hdc shell aa test -b com.plusml.remote.client -m entry_test -s unittest OpenHarmonyTestRunner
```

### 测试运行器
```typescript
// TestRunner.ets - 统一运行所有测试
import { describe, it, expect } from '@ohos/hypium';
import { runAllTests as runIndexViewModelTests } from './viewmodel/IndexViewModel.test';

export default function testRunner() {
  describe('完整测试套件', () => {
    it('IndexViewModel测试', 0, async () => {
      await runIndexViewModelTests();
    });
    
    // 添加更多测试...
  });
}
```

## 6. 测试断言

### 常用断言方法
```typescript
// 相等断言
expect(actual).assertEqual(expected);

// 包含断言
expect(array).assertContain(value);
expect(string).assertContain(substring);

// 布尔断言
expect(condition).assertTrue();
expect(condition).assertFalse();

// 空值断言
expect(value).assertNull();
expect(value).assertNotNull();

// 类型断言
expect(value).assertInstanceOf(Class);
```

### 异步断言
```typescript
it('异步测试', 0, async () => {
  const result = await asyncFunction();
  expect(result).assertEqual(expected);
});
```

## 7. 测试生命周期

### 测试套件生命周期
```typescript
describe('TestSuite', () => {
  beforeAll(() => {
    // 在所有测试之前执行一次
  });
  
  beforeEach(() => {
    // 在每个测试之前执行
  });
  
  afterEach(() => {
    // 在每个测试之后执行
  });
  
  afterAll(() => {
    // 在所有测试之后执行一次
  });
  
  it('测试用例', 0, () => {
    // 测试逻辑
  });
});
```

## 8. Mock和Stub

### 依赖注入模式
```typescript
// 生产代码
class MyService {
  constructor(private dependency: IDependency) {}
  
  async doSomething(): Promise<Result> {
    return await this.dependency.performAction();
  }
}

// 测试代码
class MockDependency implements IDependency {
  async performAction(): Promise<Result> {
    return { success: true }; // Mock实现
  }
}

const mockDependency = new MockDependency();
const service = new MyService(mockDependency);
```

### 行为验证
```typescript
// 验证方法调用
expect(mockService.callHistory).assertContain({
  method: 'connect',
  args: ['device123', 'password']
});

// 验证调用次数
const connectCalls = mockService.callHistory.filter(
  call => call.method === 'connect'
);
expect(connectCalls.length).assertEqual(1);
```

## 9. 测试数据

### 测试数据工厂
```typescript
class TestDataFactory {
  static createDeviceInfo(): DeviceInfo {
    return {
      deviceCode: 'TEST-' + Date.now(),
      password: 'test123',
      connectionState: ConnectionState.DISCONNECTED
    };
  }
  
  static createUserCredentials(): UserCredentials {
    return {
      userId: 'user-' + Math.random().toString(36).substr(2, 9),
      password: 'pass-' + Math.random().toString(36).substr(2, 9)
    };
  }
}
```

### 边界条件测试
```typescript
// 空值测试
it('应处理空输入', 0, () => {
  expect(() => service.process(null)).toThrow();
});

// 边界值测试
it('应处理最大长度', 0, () => {
  const maxLengthInput = 'a'.repeat(1000);
  const result = service.process(maxLengthInput);
  expect(result.length).assertLess(1001);
});
```

## 10. 调试测试

### 测试日志
```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';

it('带日志的测试', 0, () => {
  hilog.info(0x0000, 'testTag', '测试开始');
  // 测试逻辑
  hilog.info(0x0000, 'testTag', '测试完成');
});
```

### 调试技巧
1. **使用console.info**: 输出调试信息
2. **设置断点**: 在DevEco Studio中设置断点
3. **查看调用栈**: 分析测试失败原因
4. **隔离测试**: 单独运行失败测试

## 11. 常见问题

### 问题1: 测试无法导入模块
**解决方案**: 检查oh-package.json5依赖配置，确保测试框架已正确安装。

### 问题2: Mock对象不工作
**解决方案**: 确保Mock对象正确实现接口，并使用依赖注入。

### 问题3: 异步测试超时
**解决方案**: 增加测试超时时间，或检查异步操作是否正确完成。

### 问题4: 测试环境差异
**解决方案**: 使用环境变量或配置类隔离环境相关代码。

## 12. 最佳实践

### 测试设计原则
1. **FIRST原则**:
   - **F**ast: 测试要快速
   - **I**solated: 测试要独立
   - **R**epeatable: 测试可重复
   - **S**elf-validating: 测试自验证
   - **T**imely: 及时编写测试

2. **AAA模式**:
   - **A**rrange: 准备测试数据
   - **A**ct: 执行测试操作
   - **A**ssert: 验证结果

3. **测试金字塔**:
   - 单元测试: 70%
   - 集成测试: 20%
   - UI测试: 10%

### 代码覆盖率目标
- **语句覆盖率**: >80%
- **分支覆盖率**: >70%
- **函数覆盖率**: >90%
- **行覆盖率**: >80%

---

*文档版本: 1.0*
*最后更新: 2026-03-29*
*适用版本: HarmonyOS 6.0.2+*