# 测试与质量

## 1. 测试策略

- 以单元测试为主，覆盖关键业务逻辑
- 使用 Mock 对象隔离外部依赖
- 在必要时补充集成测试，验证模块间交互
- UI 与设备相关测试通过模拟器或真机执行

## 2. 现有测试目录

- `entry/src/test/`：HarmonyOS 客户端测试代码
- `entry/src/test/mocks/`：Mock 实现
- `entry/src/test/services/`：服务层测试
- `entry/src/test/viewmodel/`：ViewModel 层测试

## 3. 质量保障

### 3.1 代码审查

- 关注接口变更、协议流程、异常处理
- 检查文档与代码是否一致
- 保证新增功能同时补充测试和更新文档

### 3.2 测试覆盖

- 核心服务：RemoteControlService、ClipboardService、FileService
- 连接层：TCP/HTTP 连接与重连逻辑
- UI 交互：页面状态与操作反馈
- 数据模型：消息命令、剪贴板、文件结构

## 4. 测试执行命令

```powershell
cd HarmonOS_remote_desktop_control_client
.\build_with_env.bat test
```

### 4.1 运行单个测试

```powershell
hvigorw test --tests "*ClipboardService*"
hvigorw test --tests "*FileService*"
```

## 5. 文档一致性检查

- 添加新功能时，先更新对应开发文档
- 如果文档与实际实现不一致，应立即修正
- 定期审核 `docs/development/` 目录，保持系统性文档有效

## 6. 测试改进建议

- 补充 `RemoteControlService` 和协议层测试
- 增加 `ViewModel` 与 `Repository` 层测试
- 引入自动化测试流水线，减少手动验证
