# 方寸控远程桌面系统 - 架构文档索引

## 📚 文档导航

### ✅ 已完成文档

1. **[总体架构设计](./README.md)** ⭐
   - 系统概述与架构图
   - 核心数据流（控制流/屏幕流/文件流/心跳流）
   - 模块划分与技术栈
   - 性能指标与安全架构

2. **[架构问题与风险分析](./ARCHITECTURE_ISSUES.md)** 🔴 NEW
   - 8个关键架构问题详细分析
   - P0/P1/P2优先级分类
   - 代码级别的根因分析
   - 解决方案与改进路线图

3. **[压缩库重新封装设计](./COMPRESSION_LIBRARY_REFACTOR.md)** 🔴 NEW
   - 第三方压缩库使用问题分析
   - 统一的ICompressor接口定义（Java + HarmonyOS）
   - ZSTD压缩器实现方案（消除磁盘IO）
   - 迁移计划与性能预期（延迟降低75%）

4. **[PixelMap渲染高GC优化](./PIXELMAP_GC_OPTIMIZATION.md)** 🔴 NEW
   - PixelMap+Image渲染性能瓶颈分析
   - 4种优化方案对比（PixelMap复用/Canvas/Native/Tile增量）
   - 内存分配与拷贝路径深度剖析
   - 实施方案A详细步骤（1周完成，性能提升60%）

5. **[统一性能监控架构](./UNIFIED_PERFORMANCE_MONITORING.md)** 🔴 NEW
   - 三端监控现状分析与问题诊断
   - 统一监控SDK设计（MetricCollector + 4种指标类型）
   - 预定义指标体系（被控端/控制端/服务端）
   - 告警机制与可视化方案

6. **[数据库设计与背压控制流](./DATABASE_AND_BACKPRESSURE_ISSUES.md)** 🔴 NEW
   - 数据库设计不足分析（4张表 → 13张表）
   - 智能背压控制架构（规则引擎+自适应学习）
   - 性能监控与背压联动方案
   - 实施计划与预期收益

7. **[多端调试困难问题](./MULTI_PLATFORM_DEBUGGING_ISSUES.md)** 🔴 NEW
   - 四端日志系统现状分析（Java/HarmonyOS/Log4j2/Dart）
   - 统一日志规范与分布式追踪设计
   - 日志聚合中心架构（WebSocket + Elasticsearch）
   - 统一调试面板功能设计与实施计划

8. **[测试代价大与快速反馈](./TESTING_CHALLENGES.md)** 🔴 NEW
   - 分层测试架构设计（单元/集成/E2E）
   - 零散时间开发支持（TDD工作流+微测试）
   - 测试环境优化（Node.js纯逻辑测试+模拟器UI测试）
   - 自动化E2E测试框架（Python+hdc控制）

7. **[公共模块 (common)](./modules/common.md)** ⭐
   - 数据模型（Capture, Position, FileInfo等）
   - 命令对象（26种Cmd类型详解）
   - 协议编解码器（NettyEncoder/Decoder）
   - 工具类与接口定义
   - **每个API的详细签名、参数、返回值、使用场景**

8. **[服务端模块 (server)](./modules/server.md)** ⭐
   - Netty服务端启动与配置
   - 会话管理与命令路由
   - 数据库设计与SQL schema
   - 安全机制（TLS/RBAC）
   - 性能优化与监控

---

### 🚧 待完成文档

#### 核心模块

4. **[Java被控端模块 (client)](./modules/client.md)** 
   - 屏幕捕获引擎（AWT Robot + Tile-based）
   - 压缩算法实现（ZSTD + RLE）
   - 网络状态监测
   - 键鼠机器人（RemoteScreenRobot）
   - 并发控制与任务队列

5. **[HarmonyOS控制端模块 (harmonyos-client.md)](./modules/harmonyos-client.md)**
   - RemoteControlService核心服务
   - ConnectionManager连接管理
   - ProtocolHandler协议处理
   - CaptureCache帧缓存
   - ImageAssembler图像组装
   - MVVM架构与依赖注入

#### 协议规范

6. **[二进制协议规范](./protocols/binary-protocol.md)**
   - 帧格式详细说明
   - 字节序与对齐规则
   - 粘包/拆包处理
   - 版本兼容性策略

7. **[命令类型体系](./protocols/command-types.md)**
   - 26种命令的编码格式
   - 字段定义与取值范围
   - 请求-响应配对关系
   - 错误码定义

#### 数据流详解

8. **[控制流详解](./dataflow/control-flow.md)**
   - 鼠标事件完整链路
   - 键盘事件完整链路
   - 延迟分析与优化

9. **[屏幕流详解](./dataflow/screen-flow.md)**
   - 分块增量捕获算法
   - 三级压缩策略
   - 帧缓存合并逻辑
   - PixelMap渲染流程

10. **[文件流详解](./dataflow/file-flow.md)**
    - 文件分片传输
    - 断点续传机制
    - 完整性校验

#### API参考

11. **[服务端API参考](./api/server-api.md)**
    - REST API端点
    - WebSocket事件
    - 错误响应格式

12. **[客户端API参考](./api/client-api.md)**
    - HarmonyOS ArkTS API
    - Java Client API
    - Flutter Client API

---

## 📂 目录结构

```
docs/architecture/
├── README.md                          # 总体架构设计 ⭐
├── INDEX.md                           # 本文档
│
├── modules/                           # 模块详解
│   ├── common.md                      # 公共模块 ⭐
│   ├── server.md                      # 服务端模块 ⭐
│   ├── client.md                      # Java被控端模块 (TODO)
│   └── harmonyos-client.md            # HarmonyOS控制端模块 (TODO)
│
├── protocols/                         # 协议规范
│   ├── binary-protocol.md             # 二进制协议 (TODO)
│   └── command-types.md               # 命令类型体系 (TODO)
│
├── dataflow/                          # 数据流详解
│   ├── control-flow.md                # 控制流 (TODO)
│   ├── screen-flow.md                 # 屏幕流 (TODO)
│   └── file-flow.md                   # 文件流 (TODO)
│
└── api/                               # API参考
    ├── server-api.md                  # 服务端API (TODO)
    └── client-api.md                  # 客户端API (TODO)
```

---

## 🎯 下一步行动

### 优先级 P0（核心模块）

1. **创建 `modules/client.md`** - Java被控端详细API文档
   - 重点：CaptureEngine, Compressor, RemoteScreenRobot
   - 预计篇幅：800-1000行

2. **创建 `modules/harmonyos-client.md`** - HarmonyOS控制端详细API文档
   - 重点：RemoteControlService, ConnectionManager, ImageAssembler
   - 预计篇幅：1000-1200行

### 优先级 P1（协议与数据流）

3. **创建 `protocols/binary-protocol.md`** - 二进制协议规范
4. **创建 `dataflow/screen-flow.md`** - 屏幕流详细分析

### 优先级 P2（补充文档）

5. 创建其余文档...

---

## 💡 使用建议

### 对于开发者

1. **新手入门**：先阅读 [README.md](./README.md) 了解整体架构
2. **模块开发**：查阅对应模块文档（如 `modules/common.md`）
3. **协议扩展**：参考 `protocols/` 目录下的协议规范
4. **性能调优**：查看 `dataflow/` 目录下的数据流分析

### 对于架构师

1. **系统设计**：参考总体架构中的扩展性设计原则
2. **技术选型**：查看技术栈总览与性能指标
3. **安全审计**：查阅安全架构章节

### 对于测试工程师

1. **接口测试**：参考API参考文档
2. **协议测试**：参考协议规范文档
3. **性能测试**：参考性能指标章节

---

## 📊 文档统计

| 类别 | 已完成 | 待完成 | 总计 |
|------|--------|--------|------|
| 总体架构 | 1/1 | 0 | 100% ✅ |
| 架构分析 | 7/7 | 0 | 100% ✅ |
| 模块文档 | 2/4 | 2 | 50% 🚧 |
| 协议文档 | 0/2 | 2 | 0% ⏳ |
| 数据流文档 | 0/3 | 3 | 0% ⏳ |
| API文档 | 0/2 | 2 | 0% ⏳ |
| **总计** | **10/19** | **9** | **53%** |

**完成度**：53%

---

## 🔗 相关资源

- **项目源码**：[GitHub Repository](https://github.com/springstudent/HamonyOS-remote-desktop-control)
- **商业计划书**：`latex_pdf/TripartitePdf/方寸控项目商业计划书.txt`
- **运行指南**：`RUN_GUIDE.md`
- **网络配置**：`NETWORK_CONFIGURATION.md`

---

## 📝 贡献指南

如需补充或修改文档，请遵循以下规范：

1. **文件格式**：Markdown (.md)
2. **编码**：UTF-8
3. **标题层级**：最多6级（# 到 ######）
4. **代码块**：指定语言（```java, ```typescript等）
5. **API描述**：必须包含方法签名、参数说明、返回值、异常、使用示例
6. **图表**：使用Mermaid语法绘制流程图/架构图

---

**文档版本**：v1.0  
**最后更新**：2026-05-10  
**维护团队**：方寸控技术团队  
**联系方式**：team@fangcunkong.com
