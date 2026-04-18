# HarmonyOS 远程桌面控制客户端 - 文档中心

欢迎使用 HarmonyOS 远程桌面控制客户端的文档中心。本文档包含了项目的架构设计、开发指南、测试文档、故障排除和 API 参考。

---

## 📁 文档目录结构

```
docs/
├── README.md                 # 本文档（索引）
├── architecture/             # 架构设计文档
│   ├── architecture-analysis.md
│   ├── client-implementation.md
│   └── client-interface-report.md
├── testing/                  # 测试文档
│   ├── TESTING_GUIDE.md
│   ├── test-coverage-report.md
│   ├── TEST_COVERAGE_REPORT.md
│   └── TEST_SETUP_GUIDE.md
├── troubleshooting/          # 故障排除
│   ├── emulator_solution.md
│   ├── diagnose_connection.md
│   └── SOLUTION_模拟器连接问题.md
├── guides/                   # 开发指南
│   ├── harmonyos-color-encoding.md
│   ├── java-client-color-encoding.md
│   ├── napi-zstd-scheme.md
│   └── responsive-ui-adaptation.md
├── development/              # 系统化开发文档
│   ├── README.md
│   ├── architecture.md
│   ├── component-design.md
│   ├── build-and-environment.md
│   └── testing-and-quality.md
└── api/                      # API 参考
    └── server-api.md
```

---

## 📚 文档分类

### 1. 架构设计 🏗️

**位置**: `docs/architecture/`

| 文档名称 | 描述 |
|---------|------|
| [architecture-analysis.md](architecture/architecture-analysis.md) | HarmonyOS 客户端架构分析，包括整体架构设计、核心流程图、模块职责等 |
| [client-implementation.md](architecture/client-implementation.md) | 客户端实现细节，包括核心功能实现、关键技术点 |
| [client-interface-report.md](architecture/client-interface-report.md) | 客户端接口设计报告，包括接口定义、数据结构等 |

**适用人群**: 架构师、开发人员、技术负责人

---

### 2. 测试文档 🧪

**位置**: `docs/testing/`

| 文档名称 | 描述 |
|---------|------|
| [TESTING_GUIDE.md](testing/TESTING_GUIDE.md) | 测试指南，包含测试架构、运行测试方法、编写测试最佳实践 |
| [test-coverage-report.md](testing/test-coverage-report.md) | 单元测试覆盖率报告，详细列出各模块的测试覆盖情况 |
| [TEST_COVERAGE_REPORT.md](testing/TEST_COVERAGE_REPORT.md) | 测试覆盖率报告（备用版本） |
| [TEST_SETUP_GUIDE.md](testing/TEST_SETUP_GUIDE.md) | 测试环境搭建指南 |

**适用人群**: 测试工程师、开发人员

**快速开始**:
```bash
# 运行所有测试
hvigorw test

# 运行特定测试
hvigorw test --tests "*ClipboardService*"
```

---

### 3. 故障排除 🔧

**位置**: `docs/troubleshooting/`

| 文档名称 | 描述 |
|---------|------|
| [emulator_solution.md](troubleshooting/emulator_solution.md) | HarmonyOS 模拟器连接问题解决方案 |
| [diagnose_connection.md](troubleshooting/diagnose_connection.md) | 连接问题诊断指南 |
| [SOLUTION_模拟器连接问题.md](troubleshooting/SOLUTION_模拟器连接问题.md) | 模拟器连接问题详细解决方案（中文版） |

**常见问题**:
- 模拟器无法连接到服务端
- TCP 连接频繁断开
- 防火墙阻止连接
- IP 地址配置问题

**适用人群**: 所有用户、开发人员、运维人员

---

### 4. 开发指南 📖

**位置**: `docs/guides/`

| 文档名称 | 描述 |
|---------|------|
| [harmonyos-color-encoding.md](guides/harmonyos-color-encoding.md) | HarmonyOS 颜色编码规范和实现 |
| [java-client-color-encoding.md](guides/java-client-color-encoding.md) | Java 客户端颜色编码实现（参考） |
| [napi-zstd-scheme.md](guides/napi-zstd-scheme.md) | N-API ZSTD 压缩方案设计 |
| [responsive-ui-adaptation.md](guides/responsive-ui-adaptation.md) | 响应式 UI 适配方案 |

**适用人群**: 前端开发人员、UI 开发人员

---

### 5. 系统化开发文档 📘

**位置**: `docs/development/`

| 文档名称 | 描述 |
|---------|------|
| [README.md](development/README.md) | 系统化开发文档目录和维护说明 |
| [architecture.md](development/architecture.md) | 项目架构、模块分层、数据流说明 |
| [component-design.md](development/component-design.md) | 组件设计与模块职责说明 |
| [build-and-environment.md](development/build-and-environment.md) | 构建流程、开发环境、依赖管理 |
| [testing-and-quality.md](development/testing-and-quality.md) | 测试策略、质量保障和文档一致性 |

**适用人群**: 开发人员、技术负责人、测试工程师

---

### 6. API 参考 📡

**位置**: `docs/api/`

| 文档名称 | 描述 |
|---------|------|
| [server-api.md](api/server-api.md) | 服务端 API 接口文档，包括 HTTP API 和 TCP 协议 |

**适用人群**: 后端开发人员、前端开发人员

---

## 🚀 快速导航

### 新开发人员入门

1. 阅读 [架构分析](architecture/architecture-analysis.md) 了解整体设计
2. 查看 [开发指南](guides/) 了解编码规范
3. 参考 [测试指南](testing/TESTING_GUIDE.md) 学习如何编写测试

### 遇到问题？

1. 查看 [故障排除](troubleshooting/) 寻找解决方案
2. 如果问题未解决，创建 Issue 并附上错误日志

### 测试相关

1. 阅读 [测试指南](testing/TESTING_GUIDE.md)
2. 查看 [覆盖率报告](testing/test-coverage-report.md) 了解测试情况

---

## 📊 文档统计

| 分类 | 文档数量 | 最后更新 |
|------|---------|---------|
| 架构设计 | 3 | 2026-03-30 |
| 测试文档 | 4 | 2026-03-30 |
| 故障排除 | 3 | 2026-03-30 |
| 开发指南 | 4 | 2026-03-30 |
| API 参考 | 1 | 2026-03-30 |
| **总计** | **15** | **2026-03-30** |

---

## 🤝 贡献指南

### 添加新文档

1. 确定文档分类（architecture/testing/troubleshooting/guides/api）
2. 将文档放入对应的文件夹
3. 更新本文档的索引
4. 提交时编写清晰的 commit message

### 文档命名规范

- 使用小写字母
- 单词间用连字符 `-` 分隔
- 使用英文文件名（除非是中文专用文档）
- 示例：`architecture-analysis.md`

### 文档结构建议

```markdown
# 文档标题

## 概述
简要介绍文档内容

## 主要内容
详细内容...

## 示例代码
```typescript
// 代码示例
```

## 参考资源
- 相关链接
```

---

## 📝 更新日志

### 2026-03-30
- ✅ 重构文档目录结构
- ✅ 添加文档索引
- ✅ 移动所有文档到对应分类目录
- ✅ 创建测试文档专区

### 之前
- 架构分析文档
- 客户端实现文档
- 测试指南文档

---

## 📧 联系方式

如有问题或建议，请：
1. 创建 GitHub Issue
2. 联系项目维护者

---

**最后更新**: 2026-03-30  
**维护者**: HarmonyOS 远程桌面控制客户端开发团队
